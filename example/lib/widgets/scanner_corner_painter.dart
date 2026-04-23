import 'package:flutter/material.dart';
import 'package:jl_ota_example/extensions/hex_color.dart';

/// Custom painter that draws corner indicators for a scanning frame
/// Creates four corner marks to visually define the scanning area
class ScannerCornerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cornerLength = 20.0;
    final cornerWidth = 3.0;

    // 创建角标画笔
    final cornerPaint = Paint()
      ..color = HexColor.hexColor("#398BFF")
      ..strokeWidth = cornerWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.square;

    // 调整角标位置，确保完全覆盖边框角落
    final halfWidth = cornerWidth / 2 - 1.25;

    // 左上角
    canvas.drawLine(Offset(halfWidth, halfWidth), Offset(cornerLength + halfWidth, halfWidth), cornerPaint);
    canvas.drawLine(Offset(halfWidth, halfWidth), Offset(halfWidth, cornerLength + halfWidth), cornerPaint);

    // 右上角
    canvas.drawLine(Offset(size.width - halfWidth, halfWidth), Offset(size.width - cornerLength - halfWidth, halfWidth), cornerPaint);
    canvas.drawLine(Offset(size.width - halfWidth, halfWidth), Offset(size.width - halfWidth, cornerLength + halfWidth), cornerPaint);

    // 左下角
    canvas.drawLine(Offset(halfWidth, size.height - halfWidth), Offset(halfWidth, size.height - cornerLength - halfWidth), cornerPaint);
    canvas.drawLine(Offset(halfWidth, size.height - halfWidth), Offset(cornerLength + halfWidth, size.height - halfWidth), cornerPaint);

    // 右下角
    canvas.drawLine(
      Offset(size.width - halfWidth, size.height - halfWidth),
      Offset(size.width - halfWidth, size.height - cornerLength - halfWidth),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(size.width - halfWidth, size.height - halfWidth),
      Offset(size.width - cornerLength - halfWidth, size.height - halfWidth),
      cornerPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
