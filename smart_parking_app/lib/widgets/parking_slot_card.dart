import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../models/parking_slot.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

class ParkingSlotCard extends StatelessWidget {
  final ParkingSlot slot;

  const ParkingSlotCard({super.key, required this.slot});

  (Color, IconData, String, BoxDecoration) get _visual {
    switch (slot.state) {
      case SlotState.available:
        return (AppColors.available, Icons.local_parking_rounded, 'AVAILABLE', AppTheme.slot3dFree());
      case SlotState.occupied:
        return (AppColors.occupied, Icons.directions_car_rounded, 'OCCUPIED', AppTheme.slot3dOccupied());
      case SlotState.checking:
        return (AppColors.checking, Icons.hourglass_top_rounded, 'CHECKING', AppTheme.slot3dChecking());
      case SlotState.unknown:
        return (AppColors.unknown, Icons.help_outline_rounded, 'UNKNOWN', AppTheme.card3d());
    }
  }

  @override
  Widget build(BuildContext context) {
    final (color, icon, label, decoration) = _visual;

    final card = Container(
      padding: const EdgeInsets.all(14),
      decoration: decoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('SLOT ${slot.id}', style: AppTheme.mono(size: 10, letterSpacing: 1.5)),
              Icon(icon, color: color, size: 18),
            ],
          ),
          const Spacer(),
          Text(label, style: AppTheme.display(size: 15, color: color)),
        ],
      ),
    );

    if (slot.state != SlotState.checking) return card;

    return card
        .animate(onPlay: (controller) => controller.repeat(reverse: true))
        .fadeIn(duration: 700.ms, begin: 0.55);
  }
}
