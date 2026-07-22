import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../models/parking_state.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import 'status_indicator.dart';

class ConnectionCard extends StatelessWidget {
  final BtConnectionState state;
  final String? deviceName;
  final String? deviceAddress;
  final String? errorMessage;
  final bool isAutoReconnecting;
  final VoidCallback onConnectTap;
  final VoidCallback onDisconnectTap;
  final VoidCallback onRefreshTap;

  const ConnectionCard({
    super.key,
    required this.state,
    required this.deviceName,
    required this.deviceAddress,
    required this.errorMessage,
    required this.isAutoReconnecting,
    required this.onConnectTap,
    required this.onDisconnectTap,
    required this.onRefreshTap,
  });

  (Color, IconData, String) get _visual {
    if (isAutoReconnecting) {
      return (AppColors.checking, Icons.sync_rounded, 'RECONNECTING...');
    }
    switch (state) {
      case BtConnectionState.connected:
        return (AppColors.available, Icons.bluetooth_connected_rounded, 'CONNECTED');
      case BtConnectionState.connecting:
        return (AppColors.checking, Icons.bluetooth_searching_rounded, 'CONNECTING...');
      case BtConnectionState.error:
        return (AppColors.occupied, Icons.bluetooth_disabled_rounded, 'CONNECTION ERROR');
      case BtConnectionState.disconnected:
        return (AppColors.mutedForeground, Icons.bluetooth_rounded, 'DISCONNECTED');
    }
  }

  @override
  Widget build(BuildContext context) {
    final (color, icon, label) = _visual;
    final connected = state == BtConnectionState.connected;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: AppTheme.card3d(radius: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              StatusIndicator(color: color, icon: icon, label: label),
              IconButton(
                onPressed: onRefreshTap,
                icon: const Icon(Icons.refresh_rounded, color: AppColors.mutedForeground, size: 20),
                tooltip: 'Refresh paired devices',
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (connected) ...[
            Text(deviceName ?? 'Unknown device', style: AppTheme.display(size: 18)),
            const SizedBox(height: 2),
            Text(deviceAddress ?? '', style: AppTheme.mono(size: 11)),
          ] else ...[
            Text(
              errorMessage ?? 'Not connected to any device.',
              style: AppTheme.mono(size: 11, color: errorMessage != null ? AppColors.occupied : AppColors.mutedForeground),
            ),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: connected ? onDisconnectTap : onConnectTap,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: connected ? AppColors.occupiedAlpha(0.15) : AppColors.bluetoothAlpha(0.18),
                    foregroundColor: connected ? AppColors.occupied : AppColors.bluetooth,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  icon: Icon(connected ? Icons.bluetooth_disabled_rounded : Icons.bluetooth_rounded, size: 18),
                  label: Text(connected ? 'DISCONNECT' : 'CONNECT HC-05',
                      style: AppTheme.mono(size: 11, weight: FontWeight.w700, color: connected ? AppColors.occupied : AppColors.bluetooth)),
                ),
              ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(duration: 350.ms);
  }
}
