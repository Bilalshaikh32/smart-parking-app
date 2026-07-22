import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

class ParkingSummaryCard extends StatelessWidget {
  final int total;
  final int available;
  final int occupied;
  final bool isFull;
  final bool hasLiveData;

  const ParkingSummaryCard({
    super.key,
    required this.total,
    required this.available,
    required this.occupied,
    required this.isFull,
    required this.hasLiveData,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AppTheme.card3d(radius: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('PARKING SUMMARY', style: AppTheme.mono(size: 11, letterSpacing: 2)),
              if (isFull)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.occupiedAlpha(0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text('FULL', style: AppTheme.mono(size: 10, weight: FontWeight.w700, color: AppColors.occupied)),
                ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              _Stat(label: 'TOTAL', value: hasLiveData ? '$total' : '--', color: AppColors.foreground),
              _Stat(label: 'AVAILABLE', value: hasLiveData ? '$available' : '--', color: AppColors.available),
              _Stat(label: 'OCCUPIED', value: hasLiveData ? '$occupied' : '--', color: AppColors.occupied),
            ],
          ),
          if (!hasLiveData) ...[
            const SizedBox(height: 12),
            Text('No valid parking data has been received yet.',
                style: AppTheme.mono(size: 10, color: AppColors.mutedForeground)),
          ],
        ],
      ),
    ).animate().fadeIn(duration: 350.ms, delay: 60.ms);
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _Stat({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(value, style: AppTheme.display(size: 30, color: color)),
          const SizedBox(height: 4),
          Text(label, style: AppTheme.mono(size: 9, letterSpacing: 1.4)),
        ],
      ),
    );
  }
}
