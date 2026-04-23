import 'package:flutter/material.dart';
import 'package:jl_ota_example/extensions/hex_color.dart';
import 'package:jl_ota_example/widgets/scanner_corner_painter.dart';

/// A custom widget that displays a scanning frame with animated scan line
/// Used for barcode/QR code scanning interface
class ScanFrame extends StatelessWidget {
  final Animation<Offset> scanLineAnimation;
  final String hintText;

  const ScanFrame({super.key, required this.scanLineAnimation, required this.hintText});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 166,
      left: 0,
      right: 0,
      child: Center(
        child: Column(
          children: [
            // 扫描框
            Stack(
              children: [
                // 白色边框
                Container(
                  width: 240,
                  height: 240,
                  decoration: BoxDecoration(
                    color: Colors.transparent,
                    border: Border.all(color: HexColor.hexColor("#72706F"), width: 0.5),
                  ),
                ),
                // 扫描框四角
                CustomPaint(painter: ScannerCornerPainter(), child: const SizedBox(width: 240, height: 240)),
                // 扫描线动画
                AnimatedBuilder(
                  animation: scanLineAnimation,
                  builder: (context, child) {
                    return Positioned(
                      left: 0,
                      right: 0,
                      top: scanLineAnimation.value.dy * 240,
                      child: Container(
                        height: 2,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              HexColor.hexColor("#2A017CB4"),
                              HexColor.hexColor("#B20493D5"),
                              HexColor.hexColor("#00AFFF"),
                              HexColor.hexColor("#B20493D5"),
                              HexColor.hexColor("#2A017CB4"),
                            ],
                            stops: const [0.0, 0.25, 0.5, 0.75, 1.0],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 9),
            // 提示文字
            Text(
              hintText,
              style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}
