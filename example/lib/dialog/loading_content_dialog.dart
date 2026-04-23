import 'package:flutter/material.dart';

/// A loading content dialog widget that allows for flexible styling and content.
class LoadingContentDialog extends StatelessWidget {
  final double width;
  final double height;
  final Widget child;

  const LoadingContentDialog({super.key, required this.width, required this.height, required this.child});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      // 去除默认样式限制
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: EdgeInsets.zero,
      child: Center(
        // 居中显示对话框
        child: Container(
          // 设置自定义宽高
          width: width,
          height: height,
          // 对话框样式
          decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(8.0)),
          // 加载内容（传入LoadingWidget）
          child: child,
        ),
      ),
    );
  }
}
