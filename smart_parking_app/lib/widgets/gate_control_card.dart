import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../models/parking_state.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

class GateControlCard extends StatelessWidget {
  final GateState gateState;
  final bool controlsEnabled; // false when disconnected / no permission / busy
  final VoidCallback onOpen;
  final VoidCallback onClose;
  final VoidCallback onStatus;
  final VoidCallback onPing;
  final String? pingResultText;

  const GateControlCard({
    super.key,
    required this.gateState,
    required this.controlsEnabled,
    required this.onOpen,
    required this.onClose,
    required this.onStatus,
    required this.onPing,
    this.pingResultText,
  });

  (Color, IconData, String) get _gateVisual {
    switch (gateState) {
      case GateState.open:
        return (AppColors.available, Icons.garage_rounded, 'GATE OPEN');
      case GateState.closed:
        return (AppColors.mutedForeground, Icons.garage_outlined, 'GATE CLOSED');
      case GateState.commandSent:
        return (AppColors.checking, Icons.hourglass_top_rounded, 'COMMAND SENT...');
      case GateState.unknown:
        return (AppColors.unknown, Icons.help_outline_rounded, 'GATE STATUS UNKNOWN');
    }
  }

  Future<void> _confirmOpen(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceRaised,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text('Open gate?', style: AppTheme.display(size: 17)),
        content: Text(
          'This will send the OPEN command to the Arduino and raise the physical barrier.',
          style: AppTheme.sans(size: 13, color: AppColors.mutedForeground),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('CANCEL', style: AppTheme.mono(size: 11)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('OPEN GATE', style: AppTheme.mono(size: 11, weight: FontWeight.w700, color: AppColors.bluetooth)),
          ),
        ],
      ),
    );
    if (confirmed == true) onOpen();
  }

  @override
  Widget build(BuildContext context) {
    final (color, icon, label) = _gateVisual;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: AppTheme.card3d(radius: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(width: 10),
              Text(label, style: AppTheme.display(size: 15, color: color)),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _ActionButton(
                  icon: Icons.arrow_upward_rounded,
                  label: 'OPEN',
                  enabled: controlsEnabled,
                  onTap: () => _confirmOpen(context),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ActionButton(
                  icon: Icons.arrow_downward_rounded,
                  label: 'CLOSE',
                  enabled: controlsEnabled,
                  onTap: onClose,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _ActionButton(
                  icon: Icons.refresh_rounded,
                  label: 'STATUS',
                  enabled: controlsEnabled,
                  onTap: onStatus,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ActionButton(
                  icon: Icons.wifi_tethering_rounded,
                  label: 'PING',
                  enabled: controlsEnabled,
                  onTap: onPing,
                ),
              ),
            ],
          ),
          if (pingResultText != null) ...[
            const SizedBox(height: 10),
            Text(pingResultText!, style: AppTheme.mono(size: 10, color: AppColors.available)),
          ],
        ],
      ),
    ).animate().fadeIn(duration: 350.ms, delay: 120.ms);
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool enabled;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: AnimatedOpacity(
        opacity: enabled ? 1 : 0.35,
        duration: const Duration(milliseconds: 200),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: AppColors.background.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: [
              Icon(icon, color: AppColors.bluetooth, size: 20),
              const SizedBox(height: 6),
              Text(label, style: AppTheme.mono(size: 9, weight: FontWeight.w700, letterSpacing: 1.2)),
            ],
          ),
        ),
      ),
    );
  }
}
