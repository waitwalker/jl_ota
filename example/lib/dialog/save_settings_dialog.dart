import 'package:flutter/material.dart';
import 'package:jl_ota_example/l10n/app_localizations.dart';

import 'package:jl_ota/constant/constants.dart';

/// A dialog that confirms saving settings and restarting the application
class SaveSettingsDialog extends StatelessWidget {
  final VoidCallback onCancel;
  final VoidCallback onConfirm;

  static const Color darkTextColor = Color(0xFF242424);
  static const Color restartTextColor = Color(0xFF398BFF);
  static const Color cancelTextColor = Color(0xFFB0B0B0);
  static const Color dialogDividerColor = Color(0xFFF5F5F5);

  const SaveSettingsDialog({super.key, required this.onCancel, required this.onConfirm});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Material(
        borderRadius: BorderRadius.circular(12),
        color: Colors.white,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildMessage(loc.saveAndRestartMessage),
            const Divider(height: 1, color: dialogDividerColor),
            _buildButtons(context, loc.cancel, loc.restart, cancelTextColor, restartTextColor),
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
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: darkTextColor),
      ),
    );
  }

  Widget _buildButtons(BuildContext context, String cancelText, String restartText, Color cancelColor, Color restartColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        // Cancel button
        Expanded(
          child: InkWell(
            // 移除水波纹效果
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
              child: Text(cancelText, style: TextStyle(fontSize: 15, color: cancelColor)),
            ),
          ),
        ),

        // Divider
        Container(width: 1, height: AppConstants.dialogButtonHeight, color: dialogDividerColor),

        // Restart button
        Expanded(
          child: InkWell(
            // 移除水波纹效果
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
                restartText,
                style: TextStyle(color: restartColor, fontSize: 15, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
