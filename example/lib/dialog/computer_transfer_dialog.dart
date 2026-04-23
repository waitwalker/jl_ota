import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:jl_ota/constant/constants.dart';
import 'package:jl_ota_example/extensions/hex_color.dart';
import 'package:jl_ota_example/l10n/app_localizations.dart';
import 'package:jl_ota_example/utils/app_util.dart';
import 'package:jl_ota_example/widgets/toast_utils.dart';

import 'package:jl_ota/ble_method.dart';

/// Computer File Transfer Dialog
///
/// A bottom-aligned dialog that displays when the computer file transfer service starts.
/// Provides options to collapse the dialog or copy the server address.
///
/// Features:
/// - Appears at the bottom of the screen with specific insets
/// - Shows service status information
/// - Offers collapse and copy address actions
/// - Uses consistent styling with the application theme
class ComputerTransferDialog extends StatefulWidget {
  const ComputerTransferDialog({super.key});

  @override
  State<ComputerTransferDialog> createState() => _ComputerTransferDialogState();
}

class _ComputerTransferDialogState extends State<ComputerTransferDialog> {
  String _ipAddress = "";

  @override
  void initState() {
    super.initState();
    _getWifiIpAddress();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;

    return AnimatedOpacity(
      opacity: 1.0,
      duration: const Duration(milliseconds: 100),
      child: Dialog(
        insetPadding: const EdgeInsets.all(16),
        alignment: Alignment.bottomCenter,
        // 底部对齐
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
        elevation: 0,
        backgroundColor: Colors.transparent,
        child: Material(
          borderRadius: BorderRadius.circular(12.0),
          color: Colors.white,
          child: Container(
            padding: const EdgeInsets.only(top: 26),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 标题行
                _buildTitle(loc),
                // 内容
                _buildContent(loc),
                // 分隔线
                _buildDivider(),
                // 按钮区域
                _buildButtonBar(loc),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _getWifiIpAddress() async {
    try {
      final ipAddress = await BleMethod.getWifiIpAddress();
      setState(() => _ipAddress = ipAddress);
      log("getWifiIpAddress successfully");
    } catch (e) {
      log("Failed to getWifiIpAddress: $e");
    }
  }

  /// 构建标题行
  Widget _buildTitle(AppLocalizations loc) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Center(
        child: Text(
          loc.serviceStarted,
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: HexColor.hexColor('#398BFF'), fontFamily: 'PingFangSC'),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  /// 构造内容
  Widget _buildContent(AppLocalizations loc) {
    return Padding(
      padding: const EdgeInsets.only(left: 32, top: 20, right: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: Text(
              loc.ensureConnection,
              style: TextStyle(fontSize: 14, color: HexColor.hexColor('#A4A4A4'), fontWeight: FontWeight.bold, fontFamily: 'PingFangSC'),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 18),
          Image.asset('assets/images/img_file_transfer_bg.png', width: 182, height: 90, fit: BoxFit.contain),
          const SizedBox(height: 20),
          Center(
            child: Text(
              _ipAddress,
              style: TextStyle(fontSize: 15, color: HexColor.hexColor('#398BFF'), fontWeight: FontWeight.bold, fontFamily: 'PingFangSC'),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 19),
        ],
      ),
    );
  }

  /// 构建分隔线
  Widget _buildDivider() {
    return Container(color: HexColor.hexColor("#F5F5F5"), height: 1);
  }

  /// 构建按钮栏
  Widget _buildButtonBar(AppLocalizations loc) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        // 收起按钮
        _buildCollapseButton(loc),
        // 按钮分隔线
        _buildButtonDivider(),
        // 复制地址按钮
        _buildCopyAddressButton(loc),
      ],
    );
  }

  /// 构建收起按钮
  Widget _buildCollapseButton(AppLocalizations loc) {
    return Expanded(
      child: InkWell(
        onTap: () async {
          if (mounted) {
            Navigator.pop(context);
            AppUtil.readFileList();
          }
        },
        splashColor: Colors.transparent, // 去除水波纹效果
        highlightColor: Colors.transparent, // 去除高亮效果
        child: Container(
          height: AppConstants.dialogButtonHeight,
          alignment: Alignment.center,
          child: Text(
            loc.collapse,
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: HexColor.hexColor('#242424'), fontFamily: 'PingFangSC'),
          ),
        ),
      ),
    );
  }

  /// 构建按钮分隔线
  Widget _buildButtonDivider() {
    return Container(width: 1, height: AppConstants.dialogButtonHeight, color: HexColor.hexColor("#F5F5F5"));
  }

  /// 构建复制地址按钮
  Widget _buildCopyAddressButton(AppLocalizations loc) {
    return Expanded(
      child: InkWell(
        onTap: () async {
          try {
            await Clipboard.setData(ClipboardData(text: _ipAddress));
            if (mounted) {
              ToastUtils.show(context, loc.copySuccess);
            }
          } catch (e) {
            log("Copy fail");
          }
        },
        splashColor: Colors.transparent, // 去除水波纹效果
        highlightColor: Colors.transparent, // 去除高亮效果
        child: Container(
          height: AppConstants.dialogButtonHeight,
          alignment: Alignment.center,
          child: Text(
            loc.copyAddress,
            style: TextStyle(color: HexColor.hexColor("#398BFF"), fontSize: 15, fontWeight: FontWeight.bold, fontFamily: 'PingFang SC'),
          ),
        ),
      ),
    );
  }
}
