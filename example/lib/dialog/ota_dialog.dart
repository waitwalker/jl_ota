import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:jl_ota/constant/ble_event_constants.dart';
import 'package:jl_ota_example/l10n/app_localizations.dart';

import 'package:jl_ota/ble_event_stream.dart';
import 'loading_dialog.dart';

// 常量提取
class _OtaDialogConstants {
  static const double dialogHorizontalMargin = 12.0;
  static const double dialogBottomMargin = 34.0;
  static const double borderRadius = 15.0;
  static const double progressBarHeight = 3.0;
  static const double progressBarBorderRadius = 1.5;
  static const double activityIndicatorRadius = 16.0;

  static const double sectionTopPadding = 32.0;
  static const double sectionBottomPadding = 32.0;
  static const double elementSpacing = 16.0;
  static const double titleSpacing = 12.0;
  static const double horizontalContentPadding = 20.0;
  static const double reducedHorizontalContentPadding = 28.0;

  static const double iconSize = 64.0;
  static const double titleFontSize = 16.0;
  static const double messageFontSize = 14.0;
  static const double buttonFontSize = 16.0;

  static const String fontFamily = 'PingFangSC';

  static const Color textPrimaryColor = Color(0xFF242424);
  static const Color textSecondaryColor = Color(0xFF919191);
  static const Color progressBackgroundColor = Color(0xFFD8D8D8);
  static const Color progressValueColor = Color(0xFF398BFF);
  static const Color dividerColor = Color(0xFFF7F7F7);
  static const Color buttonTextColor = Color(0xFF398BFF);

  static const String successImagePath = 'assets/images/ic_success_big.png';
  static const String failImagePath = 'assets/images/ic_fail_big.png';
}

/// Custom OTA Dialog
class OtaDialog extends StatefulWidget {
  const OtaDialog({super.key});

  @override
  State<OtaDialog> createState() => _OtaDialogState();
}

class _OtaDialogState extends State<OtaDialog> {
  int _progress = 0;
  String _otaState = BleEventConstants.KEY_STATE_START;
  final String _failureReason = '';
  String _otaType = BleEventConstants.KEY_CHECK_FILE;
  String _currentMessage = '';
  bool _isSuccess = false;
  StreamSubscription? _otaStateSubscription;
  bool _isLoadingDialogShowing = false;

  @override
  void initState() {
    super.initState();
    _startListeningToOtaState();
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final screenWidth = MediaQuery.of(context).size.width;

    // 根据状态决定是否允许关闭（成功或失败状态可以关闭）
    final bool canPop = _otaState == BleEventConstants.KEY_STATE_IDLE || _otaState == BleEventConstants.ERROR;

    return PopScope(
      canPop: canPop,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (!canPop) {
          return;
        }
      },
      child: AnimatedOpacity(
        opacity: 1.0,
        duration: const Duration(milliseconds: 100),
        child: Dialog(
          insetPadding: EdgeInsets.only(
            left: _OtaDialogConstants.dialogHorizontalMargin,
            right: _OtaDialogConstants.dialogHorizontalMargin,
            bottom: _OtaDialogConstants.dialogBottomMargin,
          ),
          alignment: Alignment.bottomCenter,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_OtaDialogConstants.borderRadius)),
          elevation: 0,
          backgroundColor: Colors.transparent,
          child: SizedBox(
            width: screenWidth - (_OtaDialogConstants.dialogHorizontalMargin * 2),
            child: Material(
              borderRadius: BorderRadius.circular(_OtaDialogConstants.borderRadius),
              color: Colors.white,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 升级中状态内容
                  _buildUpgradingContent(loc),

                  // 重新连接状态内容
                  _buildReconnectContent(loc),

                  // 完成状态内容（成功或失败）
                  _buildFinishContent(loc),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _otaStateSubscription?.cancel();
    // 确保在dispose时隐藏加载对话框
    if (_isLoadingDialogShowing) {
      LoadingDialog.hideLoadingDialog();
    }
    super.dispose();
  }

  /// 监听OTA升级的状态
  void _startListeningToOtaState() {
    _otaStateSubscription = BleEventStream.otaStateStream.listen((otaData) {
      if (mounted) {
        setState(() {
          updateOtaState(otaData);
        });
      }
    });
  }

  /// 显示加载对话框
  Future<void> _showLoadingDialog() async {
    if (!_isLoadingDialogShowing && mounted) {
      _isLoadingDialogShowing = true;
      await LoadingDialog.showLoadingDialog(context);
    }
  }

  /// 隐藏加载对话框
  Future<void> _hideLoadingDialog() async {
    if (_isLoadingDialogShowing) {
      _isLoadingDialogShowing = false;
      await LoadingDialog.hideLoadingDialog();
    }
  }

  /// 构建升级中状态内容
  Widget _buildUpgradingContent(AppLocalizations loc) {
    if (_otaState != BleEventConstants.KEY_STATE_START && _otaState != BleEventConstants.KEY_STATE_WORKING) {
      return const SizedBox.shrink();
    }

    return Column(
      children: [
        SizedBox(height: _OtaDialogConstants.sectionTopPadding),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _otaType == BleEventConstants.KEY_CHECK_FILE ? loc.otaCheckFile : loc.otaUpgrading,
              style: TextStyle(
                fontSize: _OtaDialogConstants.titleFontSize,
                color: _OtaDialogConstants.textPrimaryColor,
                fontWeight: FontWeight.bold,
                fontFamily: _OtaDialogConstants.fontFamily,
              ),
            ),
            SizedBox(width: _OtaDialogConstants.titleSpacing),
            Text(
              '$_progress%',
              style: TextStyle(
                fontSize: _OtaDialogConstants.titleFontSize,
                color: _OtaDialogConstants.textPrimaryColor,
                fontWeight: FontWeight.bold,
                fontFamily: _OtaDialogConstants.fontFamily,
              ),
            ),
          ],
        ),
        SizedBox(height: _OtaDialogConstants.elementSpacing),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: _OtaDialogConstants.reducedHorizontalContentPadding),
          child: LinearProgressIndicator(
            value: _progress / 100,
            backgroundColor: _OtaDialogConstants.progressBackgroundColor,
            valueColor: AlwaysStoppedAnimation<Color>(_OtaDialogConstants.progressValueColor),
            minHeight: _OtaDialogConstants.progressBarHeight,
            borderRadius: BorderRadius.circular(_OtaDialogConstants.progressBarBorderRadius),
          ),
        ),
        SizedBox(height: _OtaDialogConstants.elementSpacing),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: _OtaDialogConstants.horizontalContentPadding),
          child: Text(
            _currentMessage.isNotEmpty ? _currentMessage : loc.upgradeProcessTip,
            style: TextStyle(
              fontSize: _OtaDialogConstants.messageFontSize,
              color: _OtaDialogConstants.textSecondaryColor,
              fontFamily: _OtaDialogConstants.fontFamily,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        SizedBox(height: _OtaDialogConstants.sectionBottomPadding),
      ],
    );
  }

  /// 构建重新连接状态内容
  Widget _buildReconnectContent(AppLocalizations loc) {
    if (_otaState != BleEventConstants.KEY_STATE_RECONNECT) {
      return const SizedBox.shrink();
    }

    return Column(
      children: [
        SizedBox(height: _OtaDialogConstants.sectionTopPadding + 6), // 38
        const CupertinoActivityIndicator(color: Color(0xFF838383), radius: _OtaDialogConstants.activityIndicatorRadius),
        SizedBox(height: 27),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: _OtaDialogConstants.horizontalContentPadding),
          child: Text(
            loc.fileVerificationComplete,
            style: TextStyle(
              fontSize: _OtaDialogConstants.messageFontSize,
              color: _OtaDialogConstants.textSecondaryColor,
              fontFamily: _OtaDialogConstants.fontFamily,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        SizedBox(height: 36),
      ],
    );
  }

  /// 构建完成状态内容
  Widget _buildFinishContent(AppLocalizations loc) {
    if (_otaState != BleEventConstants.KEY_STATE_IDLE && _otaState != BleEventConstants.ERROR) {
      return const SizedBox.shrink();
    }

    final isSuccess = _otaState == BleEventConstants.KEY_STATE_IDLE && _isSuccess;
    final failureMessage = _getFailureMessage(loc);

    return Column(
      children: [
        SizedBox(height: isSuccess ? 24 : 15),
        // 图标
        Image.asset(
          isSuccess ? _OtaDialogConstants.successImagePath : _OtaDialogConstants.failImagePath,
          width: _OtaDialogConstants.iconSize,
          height: _OtaDialogConstants.iconSize,
        ),
        SizedBox(height: _OtaDialogConstants.elementSpacing - 4), // 12
        // 标题文字
        Text(
          isSuccess ? loc.otaComplete : loc.updateFailed,
          style: TextStyle(
            fontSize: _OtaDialogConstants.titleFontSize,
            color: _OtaDialogConstants.textPrimaryColor,
            fontWeight: FontWeight.bold,
            fontFamily: _OtaDialogConstants.fontFamily,
          ),
        ),
        if (!isSuccess) SizedBox(height: 2),
        if (!isSuccess)
          Padding(
            padding: EdgeInsets.symmetric(horizontal: _OtaDialogConstants.horizontalContentPadding),
            child: Text(
              failureMessage,
              style: TextStyle(
                fontSize: _OtaDialogConstants.messageFontSize + 1, // 15
                color: _OtaDialogConstants.textSecondaryColor,
                fontFamily: _OtaDialogConstants.fontFamily,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        SizedBox(height: isSuccess ? 23 : 9),
        Container(color: _OtaDialogConstants.dividerColor, height: 1),
        // 确定按钮
        Padding(
          padding: EdgeInsets.symmetric(horizontal: _OtaDialogConstants.horizontalContentPadding),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: _OtaDialogConstants.buttonTextColor,
                elevation: 0,
                shadowColor: Colors.transparent,
                surfaceTintColor: Colors.transparent,
                shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero, side: BorderSide.none),
                overlayColor: Colors.transparent,
              ),
              child: Text(
                loc.confirm,
                style: TextStyle(
                  fontSize: _OtaDialogConstants.buttonFontSize,
                  fontWeight: FontWeight.bold,
                  fontFamily: _OtaDialogConstants.fontFamily,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// 获取失败消息
  String _getFailureMessage(AppLocalizations loc) {
    if (_otaState == BleEventConstants.ERROR) {
      return _failureReason.isNotEmpty ? loc.reason.replaceAll("%s", _failureReason) : loc.unknownError;
    }

    return _currentMessage.isNotEmpty ? loc.reason.replaceAll("%s", _currentMessage) : loc.unknownError;
  }

  /// 更新OTA状态
  void updateOtaState(Map<String, dynamic> otaData) {
    if (!mounted) return;

    final newOtaState = otaData[BleEventConstants.KEY_STATE] as String? ?? BleEventConstants.KEY_STATE_UNKNOWN;

    setState(() {
      _otaState = newOtaState;

      // 处理不同状态的数据
      switch (_otaState) {
        case BleEventConstants.KEY_STATE_WORKING:
          _progress = otaData[BleEventConstants.KEY_PROGRESS] as int? ?? 0;
          _currentMessage = otaData[BleEventConstants.KEY_MESSAGE] as String? ?? '';
          _otaType = otaData[BleEventConstants.KEY_TYPE] as String? ?? '';
          break;

        case BleEventConstants.KEY_STATE_IDLE:
          _isSuccess = otaData[BleEventConstants.KEY_SUCCESS] as bool? ?? false;
          _currentMessage = otaData[BleEventConstants.KEY_MESSAGE] as String? ?? '';
          break;
      }
    });

    // 根据状态控制加载对话框的显示/隐藏
    _handleLoadingDialog(newOtaState);
  }

  /// 根据OTA状态处理加载对话框的显示和隐藏
  void _handleLoadingDialog(String otaState) {
    if (otaState == BleEventConstants.KEY_STATE_RECONNECT) {
      // 重新连接状态，显示加载对话框
      _showLoadingDialog();
    } else if (otaState == BleEventConstants.KEY_STATE_WORKING ||
        otaState == BleEventConstants.KEY_STATE_IDLE ||
        otaState == BleEventConstants.ERROR) {
      // 工作状态、完成状态、错误状态，隐藏加载对话框
      _hideLoadingDialog();
    }
  }
}
