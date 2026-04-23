import 'package:flutter/material.dart';
import 'package:jl_ota_example/extensions/hex_color.dart';

/// Overlay widget for scanning interface with a cut-out scanning area
/// Creates a semi-transparent overlay with a clear rectangular area for scanning
class ScanOverlay extends StatelessWidget {
  const ScanOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Stack(
        children: [
          Container(decoration: BoxDecoration(color: Colors.transparent)),
          ClipPath(
            clipper: _ScanBoxClipper(),
            child: Container(color: HexColor.hexColor("#9C272626")),
          ),
        ],
      ),
    );
  }
}

class _ScanBoxClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final scanBoxSize = 240.0;
    final scanBoxTop = 166.0;
    final scanBoxLeft = (size.width - scanBoxSize) / 2;

    final path = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRect(Rect.fromLTWH(scanBoxLeft, scanBoxTop, scanBoxSize, scanBoxSize));

    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}
