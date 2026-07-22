import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// A small colored dot + icon + label. Status is NEVER shown by color
/// alone — always paired with an icon and text for accessibility.
class StatusIndicator extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String label;
  final bool pulsing;

  const StatusIndicator({
    super.key,
    required this.color,
    required this.icon,
    required this.label,
    this.pulsing = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          margin: const EdgeInsets.only(right: 8),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
            boxShadow: [BoxShadow(color: color.withValues(alpha: 0.6), blurRadius: 8)],
          ),
        ),
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 6),
        Text(label, style: AppTheme.mono(size: 11, weight: FontWeight.w700, color: color)),
      ],
    );
  }
}
