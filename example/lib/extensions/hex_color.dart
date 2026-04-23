import 'package:flutter/material.dart';
export 'hex_color.dart';

extension HexColor on Color {
  /// Creates a color from a hex string.
  ///
  /// The hex string can be in the format 'RRGGBB', 'AARRGGBB', or '0xRRGGBB'.
  static Color hexColor(String hexString) {
    final buffer = StringBuffer();
    if (hexString.length == 6 || hexString.length == 7) {
      buffer.write('FF'); // Default alpha value
    }
    buffer.write(hexString.replaceFirst('#', '').replaceFirst('0x', ''));
    return Color(int.parse(buffer.toString(), radix: 16));
  }

  /// 颜色转字符串
  String toHex({bool leadingHashSign = true}) =>
      '${leadingHashSign ? '#' : ''}'
      '${alpha.toRadixString(16).padLeft(2, '0')}'
      '${red.toRadixString(16).padLeft(2, '0')}'
      '${green.toRadixString(16).padLeft(2, '0')}'
      '${blue.toRadixString(16).padLeft(2, '0')}';
}
