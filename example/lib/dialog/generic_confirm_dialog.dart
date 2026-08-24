import 'package:flutter/material.dart';
import 'package:jl_ota/constant/constants.dart';

/// A generic confirmation dialog
class GenericConfirmDialog extends StatelessWidget {
  final String message;
  final String cancelText;
  final String confirmText;
  final VoidCallback onCancel;
  final VoidCallback onConfirm;
  final Color? cancelTextColor;
  final Color? confirmTextColor;
  final bool showCancelButton;

  static const Color defaultDarkTextColor = Color(0xFF242424);
  static const Color defaultCancelTextColor = Color(0xFFB0B0B0);
  static const Color defaultConfirmTextColor = Color(0xFF398BFF);
  static const Color dialogDividerColor = Color(0xFFF5F5F5);

  const GenericConfirmDialog({
    super.key,
    required this.message,
    required this.cancelText,
    required this.confirmText,
    required this.onCancel,
    required this.onConfirm,
    this.cancelTextColor,
    this.confirmTextColor,
    this.showCancelButton = true,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Material(
        borderRadius: BorderRadius.circular(12),
        color: Colors.white,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildMessage(message),
            if (showCancelButton) const Divider(height: 1, color: dialogDividerColor),
            _buildButtons(context),
          ],
        ),
      ),
    );
  }

  Widget _buildMessage(String message) {
    return Padding(
      padding: const EdgeInsets.only(top: 32, bottom: 19),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: defaultDarkTextColor),
      ),
    );
  }

  Widget _buildButtons(BuildContext context) {
    if (!showCancelButton) {
      return Row(
        children: [
          Expanded(
            child: InkWell(
              splashColor: Colors.transparent,
              highlightColor: Colors.transparent,
              onTap: () {
                if (context.mounted) {
                  Navigator.pop(context);
                  onConfirm();
                }
              },
              child: Container(
                height: AppConstants.dialogButtonHeight,
                alignment: Alignment.center,
                child: Text(
                  confirmText,
                  style: TextStyle(color: confirmTextColor ?? defaultConfirmTextColor, fontSize: 15, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
        ],
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        // Cancel button
        Expanded(
          child: InkWell(
            splashColor: Colors.transparent,
            highlightColor: Colors.transparent,
            onTap: () {
              if (context.mounted) {
                Navigator.pop(context);
                onCancel();
              }
            },
            child: Container(
              height: AppConstants.dialogButtonHeight,
              alignment: Alignment.center,
              child: Text(cancelText, style: TextStyle(fontSize: 15, color: cancelTextColor ?? defaultCancelTextColor)),
            ),
          ),
        ),

        // Divider
        Container(width: 1, height: AppConstants.dialogButtonHeight, color: dialogDividerColor),

        // Confirm button
        Expanded(
          child: InkWell(
            splashColor: Colors.transparent,
            highlightColor: Colors.transparent,
            onTap: () {
              if (context.mounted) {
                Navigator.pop(context);
                onConfirm();
              }
            },
            child: Container(
              height: AppConstants.dialogButtonHeight,
              alignment: Alignment.center,
              child: Text(
                confirmText,
                style: TextStyle(color: confirmTextColor ?? defaultConfirmTextColor, fontSize: 15, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

extension DialogExtension on BuildContext {
  Future<void> showConfirmDialog({
    required String message,
    required String confirmText,
    required VoidCallback onConfirm,
    String? cancelText,
    VoidCallback? onCancel,
    Color? cancelTextColor,
    Color? confirmTextColor,
    bool showCancelButton = true,
  }) async {
    return showDialog(
      context: this,
      builder: (context) => GenericConfirmDialog(
        message: message,
        cancelText: cancelText ?? 'Cancel',
        confirmText: confirmText,
        onCancel: onCancel ?? () {},
        onConfirm: onConfirm,
        cancelTextColor: cancelTextColor,
        confirmTextColor: confirmTextColor,
        showCancelButton: showCancelButton,
      ),
    );
  }
}
