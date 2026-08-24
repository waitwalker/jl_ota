import 'package:flutter/material.dart';

import '../extensions/hex_color.dart';

/// A reusable settings row widget with navigation capabilities
class SettingNavigationRow extends StatelessWidget {
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final bool showArrow;
  final Color? titleColor;

  const SettingNavigationRow({super.key, required this.title, this.subtitle, required this.onTap, this.showArrow = true, this.titleColor});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 18.0),
        color: Colors.white,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: TextStyle(fontSize: 15, color: titleColor ?? const Color(0xFF242424), fontWeight: FontWeight.bold),
            ),
            if (subtitle != null || showArrow)
              Row(
                children: [
                  if (subtitle != null)
                    Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: Text(
                        subtitle!,
                        style: TextStyle(fontSize: 15, color: HexColor.hexColor("#838383"), fontFamily: 'PingFangSC-Medium'),
                      ),
                    ),
                  if (showArrow) Image.asset('assets/images/ic_arrow_right_gray.png', width: 16, height: 16, color: HexColor.hexColor("#838383")),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
