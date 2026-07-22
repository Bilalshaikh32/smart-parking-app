import 'dart:async';
import 'dart:convert';
import 'package:flutter_bluetooth_serial_plus/flutter_bluetooth_serial_plus.dart';
import '../models/bluetooth_device_model.dart';

/// Thin I/O wrapper around flutter_bluetooth_serial_plus (Bluetooth Classic
/// SPP). Contains NO app state and NO parsing logic — only raw adapter and
/// socket operations, so it can be swapped or mocked independently of
/// [ParkingController] / [BluetoothController].
class BluetoothIoService {
  BluetoothConnection? _connection;
  StreamSubscription<dynamic>? _rawSubscription;

  Future<bool> isSupported() async {
    try {
      // If the plugin can be queried at all, Bluetooth hardware exists.
      await FlutterBluetoothSerial.instance.isAvailable;
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> isEnabled() async {
    final enabled = await FlutterBluetoothSerial.instance.isEnabled;
    return enabled ?? false;
  }

  Future<bool> requestEnable() async {
    final enabled = await FlutterBluetoothSerial.instance.requestEnable();
    return enabled ?? false;
  }

  Future<List<BluetoothDeviceInfo>> getPairedDevices() async {
    final bonded = await FlutterBluetoothSerial.instance.getBondedDevices();
    return bonded
        .map((d) => BluetoothDeviceInfo(
              name: d.name ?? 'Unknown device',
              address: d.address,
            ))
        .toList();
  }

  bool get isConnected => _connection?.isConnected ?? false;

  /// Opens an SPP socket to [address]. Throws on failure — caller decides
  /// how to surface the error (timeout, socket refused, device off, etc).
  Future<void> connect(
    String address, {
    Duration timeout = const Duration(seconds: 12),
  }) async {
    _connection = await BluetoothConnection.toAddress(address).timeout(
      timeout,
      onTimeout: () => throw TimeoutException('Connection timed out'),
    );
  }

  /// Subscribes to incoming bytes, decoded as UTF-8 text chunks (malformed
  /// bytes are replaced rather than crashing the stream).
  void listen({
    required void Function(String textChunk) onData,
    required void Function() onDisconnected,
    required void Function(Object error) onError,
  }) {
    _rawSubscription?.cancel();
    _rawSubscription = _connection?.input?.listen(
      (data) => onData(utf8.decode(data, allowMalformed: true)),
      onDone: onDisconnected,
      onError: onError,
      cancelOnError: true,
    );
  }

  /// Writes a command line, always newline-terminated per the protocol.
  void sendLine(String command) {
    final conn = _connection;
    if (conn == null || !conn.isConnected) return;
    conn.output.add(utf8.encode('$command\n'));
  }

  Future<void> disconnect() async {
    await _rawSubscription?.cancel();
    _rawSubscription = null;
    await _connection?.finish();
    await _connection?.close();
    _connection = null;
  }

  void dispose() {
    _rawSubscription?.cancel();
    _connection?.dispose();
  }
}
