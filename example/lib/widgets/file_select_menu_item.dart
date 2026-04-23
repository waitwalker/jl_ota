import 'package:flutter/material.dart';

/// A single menu item in the file selection popup
class FileSelectMenuItem extends StatelessWidget {
  final String iconPath;
  final String text;
  final VoidCallback onTap;
  final bool showDivider;

  // Layout constants
  static const double itemHeight = 44.0;
  static const double horizontalPadding = 8.0;
  static const double iconSize = 20.0;
  static const double iconTextSpacing = 8.0;
  static const double dividerHeight = 1.0;
  static const double dividerThickness = 1.0;
  static const double dividerIndent = 8.0;
  static const Color textColor = Colors.white;
  static const Color dividerColor = Color(0x38FFFFFF);
  static const String fontFamily = 'PingFangSC-Medium';
  static const double fontSize = 14.0;

  const FileSelectMenuItem({super.key, required this.iconPath, required this.text, required this.onTap, required this.showDivider});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: itemHeight),
            padding: const EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 8.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Image.asset(iconPath, width: iconSize, height: iconSize),
                const SizedBox(width: iconTextSpacing),
                Expanded(
                  child: Text(
                    text,
                    style: const TextStyle(color: textColor, fontSize: fontSize, fontFamily: fontFamily),
                    maxLines: 2, // Allow up to two lines
                    overflow: TextOverflow.ellipsis, // Add ellipsis if text is too long
                  ),
                ),
              ],
            ),
          ),
        ),
        if (showDivider) Divider(height: dividerHeight, thickness: dividerThickness, color: dividerColor, indent: dividerIndent, endIndent: 0),
      ],
    );
  }
}
