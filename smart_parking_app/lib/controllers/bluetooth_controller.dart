import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/bluetooth_device_model.dart';
import '../models/parking_state.dart';
import '../services/bluetooth_service.dart';
import '../services/local_storage_service.dart';
import '../services/parking_protocol_parser.dart';
import '../services/permission_service.dart';

/// A single line in the diagnostics log.
class DiagnosticEntry {
  final String text;
  final DateTime time;
  final String tag; // RX / TX / SYS / ERR
  const DiagnosticEntry(this.text, this.time, this.tag);
}

/// Owns the Bluetooth Classic connection lifecycle: permissions, adapter
/// state, paired-device discovery, connect/disconnect, and turning raw
/// bytes into buffered lines -> [ParsedMessage]s. Does NOT own parking
/// domain state (slots/gate/lcd) — that lives in [ParkingController],
/// which this class feeds via [onMessage].
class BluetoothController extends ChangeNotifier {
  BluetoothController({required this.onMessage, this.onDisconnected});

  final void Function(ParsedMessage message) onMessage;
  final VoidCallback? onDisconnected;

  final BluetoothIoService _io = BluetoothIoService();
  final LineBuffer _lineBuffer = LineBuffer();

  BtConnectionState connectionState = BtConnectionState.disconnected;
  String? connectedDeviceName;
  String? connectedDeviceAddress;
  String? errorMessage;
  bool isBluetoothSupported = true;
  bool isBluetoothEnabled = true;
  bool permissionsGranted = false;
  bool permissionsPermanentlyDenied = false;
  bool isAutoReconnecting = false;

  List<BluetoothDeviceInfo> pairedDevices = [];

  final List<DiagnosticEntry> diagnosticLog = [];

  bool _connectGuard = false; // prevents two simultaneous connect attempts

  void _log(String text, String tag) {
    diagnosticLog.insert(0, DiagnosticEntry(text, DateTime.now(), tag));
    if (diagnosticLog.length > kMaxDiagnosticLogEntries) {
      diagnosticLog.removeLast();
    }
  }

  void clearDiagnosticLog() {
    diagnosticLog.clear();
    notifyListeners();
  }

  // ---------------------------------------------------------------------
  // Startup / permissions
  // ---------------------------------------------------------------------

  Future<void> initialize() async {
    isBluetoothSupported = await _io.isSupported();
    if (!isBluetoothSupported) {
      errorMessage = 'This device does not support Bluetooth.';
      _log('Bluetooth not supported on this device', 'ERR');
      notifyListeners();
      return;
    }

    isBluetoothEnabled = await _io.isEnabled();
    permissionsGranted = await PermissionService.hasBluetoothPermissions();
    notifyListeners();
  }

  Future<bool> ensurePermissions() async {
    final outcome = await PermissionService.requestBluetoothPermissions();
    permissionsGranted = outcome == PermissionOutcome.granted;
    permissionsPermanentlyDenied = outcome == PermissionOutcome.permanentlyDenied;
    if (!permissionsGranted) {
      errorMessage = permissionsPermanentlyDenied
          ? 'Nearby Devices permission is permanently denied. Open app settings to enable it.'
          : 'Nearby Devices permission is required to connect.';
      _log(errorMessage!, 'ERR');
    }
    notifyListeners();
    return permissionsGranted;
  }

  Future<bool> ensureBluetoothEnabled() async {
    isBluetoothEnabled = await _io.isEnabled();
    if (isBluetoothEnabled) return true;
    isBluetoothEnabled = await _io.requestEnable();
    notifyListeners();
    return isBluetoothEnabled;
  }

  // ---------------------------------------------------------------------
  // Device discovery
  // ---------------------------------------------------------------------

  Future<void> refreshPairedDevices() async {
    if (!permissionsGranted) return;
    final devices = await _io.getPairedDevices();
    // HC-05 / HC-06 devices are surfaced first.
    devices.sort((a, b) {
      if (a.isLikelyHc05 == b.isLikelyHc05) return a.name.compareTo(b.name);
      return a.isLikelyHc05 ? -1 : 1;
    });
    pairedDevices = devices;
    _log('Found ${devices.length} paired device(s)', 'SYS');
    notifyListeners();
  }

  // ---------------------------------------------------------------------
  // Connect / disconnect
  // ---------------------------------------------------------------------

  Future<void> tryAutoReconnect() async {
    final saved = await LocalStorageService.getLastDevice();
    if (saved == null) return;
    if (!permissionsGranted) return;

    await refreshPairedDevices();
    final match = pairedDevices.where((d) => d.address == saved.address);
    if (match.isEmpty) return;

    isAutoReconnecting = true;
    notifyListeners();
    await connect(match.first);
    isAutoReconnecting = false;
    notifyListeners();
  }

  Future<bool> connect(BluetoothDeviceInfo device) async {
    if (_connectGuard) return false; // prevent duplicate simultaneous attempts
    _connectGuard = true;

    connectionState = BtConnectionState.connecting;
    errorMessage = null;
    _log('Connecting to ${device.name} (${device.address})...', 'SYS');
    notifyListeners();

    try {
      await _io.connect(device.address);

      connectedDeviceName = device.name;
      connectedDeviceAddress = device.address;
      connectionState = BtConnectionState.connected;
      _lineBuffer.clear();

      _io.listen(
        onData: _handleIncomingText,
        onDisconnected: _handleDisconnected,
        onError: _handleError,
      );

      await LocalStorageService.saveLastDevice(device.name, device.address);
      _log('Connected to ${device.name}', 'SYS');
      notifyListeners();

      // Always request a fresh snapshot right after connecting.
      sendCommand('STATUS');
      return true;
    } on TimeoutException {
      connectionState = BtConnectionState.error;
      errorMessage = 'Connection timed out. Check that the Arduino is powered on.';
      _log(errorMessage!, 'ERR');
      notifyListeners();
      return false;
    } catch (e) {
      connectionState = BtConnectionState.error;
      errorMessage =
          'Could not connect. Another app may already be connected to HC-05, or it is out of range.';
      _log('Connect failed: $e', 'ERR');
      notifyListeners();
      return false;
    } finally {
      _connectGuard = false;
    }
  }

  Future<void> disconnect() async {
    await _io.disconnect();
    connectionState = BtConnectionState.disconnected;
    connectedDeviceName = null;
    connectedDeviceAddress = null;
    _log('Disconnected', 'SYS');
    onDisconnected?.call();
    notifyListeners();
  }

  Future<void> forgetSavedDevice() => LocalStorageService.clearLastDevice();

  // ---------------------------------------------------------------------
  // Sending commands
  // ---------------------------------------------------------------------

  bool get canSendCommands => connectionState == BtConnectionState.connected;

  void sendCommand(String command) {
    if (!canSendCommands) return;
    _io.sendLine(command);
    _log('TX: $command', 'TX');
  }

  // ---------------------------------------------------------------------
  // Receiving
  // ---------------------------------------------------------------------

  void _handleIncomingText(String chunk) {
    final lines = _lineBuffer.add(chunk);
    for (final line in lines) {
      _log('RX: $line', 'RX');
      final message = ParkingProtocolParser.parseLine(line);
      onMessage(message);
    }
    if (lines.isNotEmpty) notifyListeners();
  }

  void _handleDisconnected() {
    connectionState = BtConnectionState.disconnected;
    connectedDeviceName = null;
    connectedDeviceAddress = null;
    errorMessage = 'Bluetooth connection was lost.';
    _log(errorMessage!, 'ERR');
    onDisconnected?.call();
    notifyListeners();
  }

  void _handleError(Object error) {
    connectionState = BtConnectionState.error;
    errorMessage = 'Bluetooth connection was lost.';
    _log('Socket error: $error', 'ERR');
    onDisconnected?.call();
    notifyListeners();
  }

  @override
  void dispose() {
    _io.dispose();
    super.dispose();
  }
}
