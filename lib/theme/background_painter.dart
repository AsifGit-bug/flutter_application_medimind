import 'package:flutter/material.dart';
import 'dart:math' as math;

class BackgroundPainter extends CustomPainter {
  final Animation<double> animation;
  final Color primaryColor;
  final Color backgroundColor;

  BackgroundPainter({
    required this.animation,
    required this.primaryColor,
    required this.backgroundColor,
  }) : super(repaint: animation);

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final paint = Paint();

    // Base background with subtle gradient
    paint.shader = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        backgroundColor,
        Color.alphaBlend(primaryColor.withValues(alpha: 0.05), backgroundColor),
        backgroundColor,
      ],
      stops: const [0.0, 0.5, 1.0],
    ).createShader(rect);
    canvas.drawRect(rect, paint);

    // Draw animated waves
    _drawWave(canvas, size, 1.0);
    _drawWave(canvas, size, 1.5);
    _drawWave(canvas, size, 2.0);
  }

  void _drawWave(Canvas canvas, Size size, double speed) {
    final paint = Paint()
      ..style = PaintingStyle.fill
      ..shader = LinearGradient(
        colors: [
          primaryColor.withValues(alpha: 0.03),
          primaryColor.withValues(alpha: 0.08),
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(Offset.zero & size);

    final path = Path();
    final value = animation.value * 2 * math.pi * speed;

    // Start from bottom left
    path.moveTo(0, size.height);

    // Create flowing curve
    for (double x = 0; x <= size.width; x += 5) {
      final double sine = math.sin((x / size.width * 2 * math.pi) + value);
      final double yOffset = sine * 20.0; // Wave amplitude

      // Calculate base height (lower part of screen)
      final double baseHeight = size.height * (0.85 - (speed - 1.0) * 0.1);

      path.lineTo(x, baseHeight + yOffset);
    }

    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant BackgroundPainter oldDelegate) {
    return true;
  }
}
