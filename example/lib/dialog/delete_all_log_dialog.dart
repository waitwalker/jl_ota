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
              // 标题部分
              Text(
                loc.isDeleteAllLogFiles,
                textAlign: TextAlign.center, // 文本居中
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: HexColor.hexColor('#242424'), fontFamily: 'PingFangSC'),
              ),
              const SizedBox(height: 19),

              // 分隔线
              Container(
                color: HexColor.hexColor("#F5F5F5"),
                height: 1,
                width: double.infinity, // 确保分隔线充满宽度
              ),

              // 按钮部分
              Row(
                children: [
                  // 取消按钮
                  Expanded(
                    child: InkWell(
                      onTap: onCancel,
                      splashColor: Colors.transparent, // 去除水波纹效果
                      highlightColor: Colors.transparent, // 去除高亮效果
                      child: Container(
                        height: AppConstants.dialogButtonHeight,
                        alignment: Alignment.center,
                        child: Text(
                          loc.cancel,
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: HexColor.hexColor('#B0B0B0'), fontFamily: 'PingFangSC'),
                        ),
                      ),
                    ),
                  ),

                  // 分隔线
                  Container(width: 1, height: AppConstants.dialogButtonHeight, color: HexColor.hexColor("#F5F5F5")),

                  // 确认按钮
                  Expanded(
                    child: InkWell(
                      onTap: onConfirm,
                      splashColor: Colors.transparent, // 去除水波纹效果
                      highlightColor: Colors.transparent, // 去除高亮效果
                      child: Container(
                        height: AppConstants.dialogButtonHeight,
                        alignment: Alignment.center,
                        child: Text(
                          loc.confirm,
                          style: TextStyle(color: HexColor.hexColor("#398BFF"), fontSize: 15, fontWeight: FontWeight.bold, fontFamily: 'PingFang SC'),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
