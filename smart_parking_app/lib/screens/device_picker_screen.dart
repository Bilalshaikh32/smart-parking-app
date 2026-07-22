import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controllers/bluetooth_controller.dart';
import '../models/bluetooth_device_model.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

/// Lists PAIRED Bluetooth Classic devices only (never BLE scan results).
/// HC-05 / HC-06 devices are sorted to the top with a badge.
class DevicePickerScreen extends StatefulWidget {
  const DevicePickerScreen({super.key});

  @override
  State<DevicePickerScreen> createState() => _DevicePickerScreenState();
}

class _DevicePickerScreenState extends State<DevicePickerScreen> {
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    await context.read<BluetoothController>().refreshPairedDevices();
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _connect(BluetoothDeviceInfo device) async {
    final bt = context.read<BluetoothController>();
    final ok = await bt.connect(device);
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(bt.errorMessage ?? 'Could not connect.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bt = context.watch<BluetoothController>();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: Text('Select Device', style: AppTheme.display(size: 17)),
        actions: [
          IconButton(
            onPressed: _load,
            icon: const Icon(Icons.refresh_rounded, color: AppColors.bluetooth),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.bluetooth))
          : bt.pairedDevices.isEmpty
              ? _EmptyState(onRefresh: _load)
              : ListView.separated(
                  padding: const EdgeInsets.all(18),
                  itemCount: bt.pairedDevices.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    final device = bt.pairedDevices[i];
                    return Container(
                      decoration: AppTheme.card3d(radius: 18),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        leading: Icon(Icons.bluetooth_rounded,
                            color: device.isLikelyHc05 ? AppColors.bluetooth : AppColors.mutedForeground),
                        title: Row(
                          children: [
                            Flexible(child: Text(device.name, style: AppTheme.display(size: 14))),
                            if (device.isLikelyHc05) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.bluetoothAlpha(0.18),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text('HC-05/06',
                                    style: AppTheme.mono(size: 9, weight: FontWeight.w700, color: AppColors.bluetooth)),
                              ),
                            ],
                          ],
                        ),
                        subtitle: Text(device.address, style: AppTheme.mono(size: 11)),
                        trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.mutedForeground),
                        onTap: () => _connect(device),
                      ),
                    );
                  },
                ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onRefresh;
  const _EmptyState({required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.bluetooth_disabled_rounded, size: 42, color: AppColors.mutedForeground),
            const SizedBox(height: 16),
            Text('No paired devices found', style: AppTheme.display(size: 15), textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(
              'Pair your HC-05 in Android Bluetooth Settings first (PIN is usually 1234 or 0000), then refresh.',
              textAlign: TextAlign.center,
              style: AppTheme.mono(size: 11),
            ),
            const SizedBox(height: 18),
            OutlinedButton.icon(
              onPressed: onRefresh,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('REFRESH'),
            ),
          ],
        ),
      ),
    );
  }
}
