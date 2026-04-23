import 'dart:async';

import 'package:flutter/material.dart';

import '../widgets/loading_widget.dart';
import 'loading_content_dialog.dart';

/// Loading Dialog Utility Class
///
/// Provides static methods to display and hide a loading dialog.
class LoadingDialog {
  static BuildContext? _currentDialogContext;
  static Completer<void>? _dialogCompleter;
  static Timer? _timeoutTimer;

  /// Shows a loading dialog with optional timeout
  ///
  /// [context]: The build context
  /// [timeoutSeconds]: Optional timeout in seconds. If provided, the dialog will
  /// automatically close after this duration. Default is null (no timeout).
  static Future<void> showLoadingDialog(BuildContext context, {int? timeoutSeconds}) async {
    // 如果已经有Dialog正在显示，等待它关闭
    if (_dialogCompleter != null && !_dialogCompleter!.isCompleted) {
      await _dialogCompleter!.future;
    }

    _dialogCompleter = Completer<void>();

    // 设置超时定时器
    if (timeoutSeconds != null && timeoutSeconds > 0) {
      _timeoutTimer = Timer(Duration(seconds: timeoutSeconds), () {
        if (_currentDialogContext != null && _currentDialogContext!.mounted) {
          hideLoadingDialog();
          debugPrint("Loading dialog closed due to timeout");
        }
      });
    }

    if (context.mounted) {
      unawaited(
        showDialog(
          context: context,
          barrierDismissible: false,
          barrierColor: const Color(0x4C000000),
          builder: (dialogContext) {
            _currentDialogContext = dialogContext;
            return LoadingContentDialog(width: 106, height: 106, child: const LoadingWidget());
          },
        ).then((_) {
          _dialogCompleter?.complete();
          _dialogCompleter = null;
          _currentDialogContext = null;
          // 取消超时定时器
          _timeoutTimer?.cancel();
          _timeoutTimer = null;
        }),
      );
    }
  }

  static Future<void> hideLoadingDialog() async {
    // 取消超时定时器
    _timeoutTimer?.cancel();
    _timeoutTimer = null;

    if (_currentDialogContext != null && _currentDialogContext!.mounted) {
      try {
        await Navigator.of(_currentDialogContext!, rootNavigator: true).maybePop();
      } catch (e) {
        debugPrint("Error hiding dialog: $e");
      }
    }
    _currentDialogContext = null;
    _dialogCompleter?.complete();
    _dialogCompleter = null;
  }
}
