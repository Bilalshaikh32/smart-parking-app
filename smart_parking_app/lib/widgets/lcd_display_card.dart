import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

/// Visually resembles a real 16x2 character LCD (green-on-black look),
/// mirroring the L1:/L2: lines sent by the Arduino.
class LcdDisplayCard extends StatelessWidget {
  final String line1;
  final String line2;
  final bool isStale;

  const LcdDisplayCard({
    super.key,
    required this.line1,
    required this.line2,
    required this.isStale,
  });

  String _pad16(String s) => s.length >= 16 ? s.substring(0, 16) : s.padRight(16);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('LCD PREVIEW', style: AppTheme.mono(size: 11, letterSpacing: 2)),
            if (isStale)
              Text('DATA MAY BE STALE', style: AppTheme.mono(size: 9, color: AppColors.checking)),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          decoration: BoxDecoration(
            color: const Color(0xFF071A0E),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF1B3D22)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_pad16(line1),
                  style: const TextStyle(
                      fontFamily: 'monospace', fontSize: 16, letterSpacing: 2, color: Color(0xFF6CFF8E), height: 1.6)),
              Text(_pad16(line2),
                  style: const TextStyle(
                      fontFamily: 'monospace', fontSize: 16, letterSpacing: 2, color: Color(0xFF6CFF8E), height: 1.6)),
            ],
          ),
        ),
      ],
    ).animate().fadeIn(duration: 350.ms, delay: 180.ms);
  }
}
