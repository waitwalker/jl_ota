import 'package:flutter/cupertino.dart';

/// A custom painter that draws an isosceles triangle shape
class TrianglePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF4E4E4E)
      ..style = PaintingStyle.fill;

    // Create an isosceles triangle with base at bottom
    final path = Path()
      ..moveTo(size.width / 2, 0) // Top point
      ..lineTo(size.width, size.height) // Bottom right
      ..lineTo(0, size.height) // Bottom left
      ..close();

    // Apply the same positioning as original
    canvas.save();
    final pivotX = -0.4 * size.width;
    final pivotY = 0.87 * size.height;
    canvas.translate(pivotX, pivotY);
    canvas.drawPath(path, paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
