import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// A premium, high-tech background widget that renders a geometric texture.
/// Features a dot grid matrix, isometric wireframe lines, glowing node intersections,
/// and a soft radial color glow to create depth.
class GeometricTextureBackground extends StatelessWidget {
  final Widget? child;

  const GeometricTextureBackground({super.key, this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Base dark background color
        Positioned.fill(
          child: Container(
            color: AppColors.background,
          ),
        ),
        // Subtle radial glow to add depth
        Positioned.fill(
          child: IgnorePointer(
            child: Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0, -0.4),
                  radius: 1.2,
                  colors: [
                    AppColors.primary.withValues(alpha: 0.08),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ),
        // Custom painted geometric texture
        Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(
              painter: _GeometricPainter(),
            ),
          ),
        ),
        // Foreground contents
        if (child != null) Positioned.fill(child: child!),
      ],
    );
  }
}

class _GeometricPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Paints for different geometric layers
    final paintDot = Paint()
      ..color = AppColors.border.withValues(alpha: 0.15)
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;

    final paintLine = Paint()
      ..color = AppColors.border.withValues(alpha: 0.09)
      ..strokeWidth = 0.8
      ..style = PaintingStyle.stroke;

    final paintAccentLine = Paint()
      ..color = AppColors.primary.withValues(alpha: 0.035)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    final paintNode = Paint()
      ..color = AppColors.primary.withValues(alpha: 0.18)
      ..style = PaintingStyle.fill;

    // 1. Draw Dot Grid (24px spacing)
    const dotSpacing = 24.0;
    for (double x = 0; x < size.width; x += dotSpacing) {
      for (double y = 0; y < size.height; y += dotSpacing) {
        canvas.drawCircle(Offset(x, y), 0.7, paintDot);
      }
    }

    // 2. Draw Isometric Blueprint Lines
    // Slope = tan(30) = 0.57735
    const double slope = 0.57735;
    const double lineSpacing = 160.0;

    // Downward diagonals (y = slope * x + c)
    double cMin = -slope * size.width;
    double cMax = size.height;

    for (double c = (cMin - (cMin % lineSpacing)); c <= cMax + lineSpacing; c += lineSpacing) {
      final p1 = Offset(0, c);
      final p2 = Offset(size.width, slope * size.width + c);
      
      final isAccent = (c.toInt() ~/ lineSpacing.toInt()) % 4 == 0;
      canvas.drawLine(p1, p2, isAccent ? paintAccentLine : paintLine);
    }

    // Upward diagonals (y = -slope * x + c)
    double cMax2 = size.height + slope * size.width;
    for (double c = 0; c <= cMax2 + lineSpacing; c += lineSpacing) {
      final p1 = Offset(0, c);
      final p2 = Offset(size.width, -slope * size.width + c);

      final isAccent = (c.toInt() ~/ lineSpacing.toInt()) % 4 == 0;
      canvas.drawLine(p1, p2, isAccent ? paintAccentLine : paintLine);
    }

    // 3. Glowing Node Intersections
    // Find where the downward and upward diagonals cross and draw highlights.
    // Line 1: y = slope * x + cA
    // Line 2: y = -slope * x + cB
    // x = (cB - cA) / (2 * slope)
    // y = slope * x + cA
    int index = 0;
    for (double cA = (cMin - (cMin % lineSpacing)); cA <= cMax; cA += lineSpacing) {
      for (double cB = 0; cB <= cMax2; cB += lineSpacing) {
        final double x = (cB - cA) / (2 * slope);
        final double y = slope * x + cA;

        // Check bounds
        if (x >= 0 && x <= size.width && y >= 0 && y <= size.height) {
          index++;
          // Draw a node at subset of intersections for high-tech scattering
          if (index % 5 == 0) {
            canvas.drawCircle(Offset(x, y), 2.2, paintNode);
            
            // Outer glowing ring
            canvas.drawCircle(
              Offset(x, y),
              5.5,
              Paint()
                ..color = AppColors.primary.withValues(alpha: 0.05)
                ..style = PaintingStyle.stroke
                ..strokeWidth = 1.0,
            );
          }
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _GeometricPainter oldDelegate) => false;
}
