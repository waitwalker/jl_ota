import 'package:flutter/material.dart';

/// A utility class for displaying centered Toast messages in Flutter applications.
class ToastUtils {
  /// Shows a standard Toast message with default duration (1 second)
  static void show(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 1),
    Color backgroundColor = Colors.white,
    TextStyle textStyle = const TextStyle(color: Colors.black, fontSize: 13),
    double elevation = 6.0,
  }) {
    _showToast(context, message, duration: duration, backgroundColor: backgroundColor, textStyle: textStyle, elevation: elevation);
  }

  /// Shows a long-duration Toast message (3 seconds by default)
  static void showLong(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 3),
    Color backgroundColor = Colors.white,
    TextStyle textStyle = const TextStyle(color: Colors.black, fontSize: 13),
    double elevation = 6.0,
  }) {
    _showToast(context, message, duration: duration, backgroundColor: backgroundColor, textStyle: textStyle, elevation: elevation);
  }

  /// Internal method to display Toast
  static void _showToast(
    BuildContext context,
    String message, {
    required Duration duration,
    required Color backgroundColor,
    required TextStyle textStyle,
    required double elevation,
  }) {
    try {
      final overlay = Overlay.of(context);

      final overlayEntry = OverlayEntry(
        builder: (context) => Center(
          child: Material(
            color: Colors.transparent,
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.8, // 最大宽度限制
              ),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                color: backgroundColor,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(color: const Color(0x19000000), blurRadius: 12, spreadRadius: 2)],
              ),
              child: Text(message, style: textStyle, textAlign: TextAlign.center),
            ),
          ),
        ),
      );

      // 插入到 Overlay
      overlay.insert(overlayEntry);

      // 定时移除
      Future.delayed(duration, () {
        overlayEntry.remove();
      });
    } catch (e) {
      //print("Error showing toast: $e");
    }
  }
}
