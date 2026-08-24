import 'package:flutter/material.dart';
import 'package:jl_ota_example/l10n/app_localizations.dart';
import 'package:jl_ota/constant/constants.dart';
import '../extensions/hex_color.dart';

/// A confirmation dialog for deleting all log files
class DeleteAllLogDialog extends StatelessWidget {
  final VoidCallback onCancel;
  final VoidCallback onConfirm;

  const DeleteAllLogDialog({super.key, required this.onCancel, required this.onConfirm});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
      child: Material(
        borderRadius: BorderRadius.circular(12.0),
        color: Colors.white,
        child: Container(
          padding: const EdgeInsets.only(top: 32, left: 16, right: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Title section
              Text(
                loc.isDeleteAllLogFiles,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: HexColor.hexColor('#242424'), fontFamily: 'PingFangSC'),
              ),
              const SizedBox(height: 19),

              // Divider
              Container(color: HexColor.hexColor("#F5F5F5"), height: 1, width: double.infinity),

              // Button section
              Row(
                children: [
                  _buildButton(text: loc.cancel, textColor: '#B0B0B0', fontFamily: 'PingFangSC', onTap: onCancel),
                  _buildDivider(),
                  _buildButton(text: loc.confirm, textColor: '#398BFF', fontFamily: 'PingFang SC', onTap: onConfirm),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Build a common button widget
  Widget _buildButton({required String text, required String textColor, required String fontFamily, required VoidCallback onTap}) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        child: Container(
          height: AppConstants.dialogButtonHeight,
          alignment: Alignment.center,
          child: Text(
            text,
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: HexColor.hexColor(textColor), fontFamily: fontFamily),
          ),
        ),
      ),
    );
  }

  /// Build the divider between buttons
  Widget _buildDivider() {
    return Container(width: 1, height: AppConstants.dialogButtonHeight, color: HexColor.hexColor("#F5F5F5"));
  }
}
