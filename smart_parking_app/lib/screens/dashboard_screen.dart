import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controllers/bluetooth_controller.dart';
import '../controllers/parking_controller.dart';
import '../models/parking_state.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/connection_card.dart';
import '../widgets/gate_control_card.dart';
import '../widgets/geometric_texture_background.dart';
import '../widgets/lcd_display_card.dart';
import '../widgets/parking_slot_card.dart';
import '../widgets/parking_summary_card.dart';
import 'device_picker_screen.dart';
import 'diagnostics_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Bluetooth Classic sockets survive backgrounding on Android, so we
    // deliberately do NOT disconnect here — just refresh status once the
    // app is foregrounded again in case anything was missed.
    if (state == AppLifecycleState.resumed) {
      final bt = context.read<BluetoothController>();
      if (bt.canSendCommands) bt.sendCommand('STATUS');
    }
  }

  Future<void> _handleConnectTap() async {
    final bt = context.read<BluetoothController>();

    if (!bt.isBluetoothEnabled) {
      final enabled = await bt.ensureBluetoothEnabled();
      if (!enabled) return;
    }

    final granted = await bt.ensurePermissions();
    if (!mounted) return;

    if (!granted) {
      if (bt.permissionsPermanentlyDenied) {
        _showPermissionDialog(bt);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(bt.errorMessage ?? 'Nearby Devices permission is required to connect.')),
        );
      }
      return;
    }

    if (!mounted) return;
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const DevicePickerScreen()));
  }

  void _showPermissionDialog(BluetoothController bt) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceRaised,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text('Permission required', style: AppTheme.display(size: 16)),
        content: Text(
          'Nearby Devices permission was permanently denied. Please enable it from app settings to connect to your HC-05.',
          style: AppTheme.sans(size: 13, color: AppColors.mutedForeground),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('RETRY LATER', style: AppTheme.mono(size: 11)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              bt.ensurePermissions(); // will reopen settings prompt path
            },
            child: Text('OPEN SETTINGS', style: AppTheme.mono(size: 11, weight: FontWeight.w700, color: AppColors.bluetooth)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bt = context.watch<BluetoothController>();
    final parking = context.watch<ParkingController>();

    final connected = bt.connectionState == BtConnectionState.connected;
    final controlsEnabled = connected && parking.gateState != GateState.commandSent;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          const Positioned.fill(child: GeometricTextureBackground()),
          SafeArea(
            child: RefreshIndicator(
              color: AppColors.bluetooth,
              backgroundColor: AppColors.surface,
              onRefresh: () async {
                if (bt.canSendCommands) bt.sendCommand('STATUS');
              },
              child: ListView(
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('SMART PARKING', style: AppTheme.display(size: 22, letterSpacing: -0.5)),
                      IconButton(
                        onPressed: () => Navigator.of(context)
                            .push(MaterialPageRoute(builder: (_) => const DiagnosticsScreen())),
                        icon: const Icon(Icons.bug_report_outlined, color: AppColors.mutedForeground),
                        tooltip: 'Diagnostics',
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    parking.lastValidUpdate == null
                        ? 'No valid parking data has been received yet.'
                        : parking.isDataStale
                            ? 'Data may be stale — last update ${_ago(parking.lastValidUpdate!)}'
                            : 'Last update ${_ago(parking.lastValidUpdate!)}',
                    style: AppTheme.mono(size: 10, color: parking.isDataStale ? AppColors.checking : AppColors.mutedForeground),
                  ),
                  const SizedBox(height: 18),
                  ConnectionCard(
                    state: bt.connectionState,
                    deviceName: bt.connectedDeviceName,
                    deviceAddress: bt.connectedDeviceAddress,
                    errorMessage: bt.errorMessage,
                    isAutoReconnecting: bt.isAutoReconnecting,
                    onConnectTap: _handleConnectTap,
                    onDisconnectTap: () => bt.disconnect(),
                    onRefreshTap: () => bt.refreshPairedDevices(),
                  ),
                  const SizedBox(height: 18),
                  ParkingSummaryCard(
                    total: parking.slots.length,
                    available: parking.availableCount,
                    occupied: parking.occupiedCount,
                    reportedAvailable: parking.reportedAvailableCount,
                    reportedOccupied: parking.reportedOccupiedCount,
                    isFull: parking.isParkingFull,
                    hasLiveData: parking.lastValidUpdate != null,
                    lightState: parking.effectiveLightState,
                  ),
                  const SizedBox(height: 18),
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 1.5,
                    children: [for (final slot in parking.slots) ParkingSlotCard(slot: slot)],
                  ),
                  const SizedBox(height: 18),
                  GateControlCard(
                    gateState: parking.gateState,
                    controlsEnabled: controlsEnabled,
                    pingResultText: parking.lastPingRoundTrip,
                    onOpen: () {
                      parking.markGateCommandSent();
                      bt.sendCommand('OPEN');
                    },
                    onClose: () {
                      parking.markGateCommandSent();
                      bt.sendCommand('CLOSE');
                    },
                    onStatus: () => bt.sendCommand('STATUS'),
                    onPing: () => bt.sendCommand('PING'),
                  ),
                  const SizedBox(height: 18),
                  LcdDisplayCard(
                    line1: parking.lcdLine1,
                    line2: parking.lcdLine2,
                    isStale: parking.isDataStale,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _ago(DateTime t) {
    final d = DateTime.now().difference(t);
    if (d.inSeconds < 60) return '${d.inSeconds}s ago';
    if (d.inMinutes < 60) return '${d.inMinutes}m ago';
    return '${d.inHours}h ago';
  }
}
