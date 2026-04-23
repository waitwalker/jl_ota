import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';

/// A widget that displays a loading indicator with a text message.
class LoadingWidget extends StatelessWidget {
  const LoadingWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context)!.btConnecting;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CupertinoActivityIndicator(color: Colors.white, radius: 20),
          const SizedBox(height: 12.0),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              text,
              style: const TextStyle(fontSize: 14, fontFamily: 'PingFangSC-Medium', fontWeight: FontWeight.bold, color: Colors.white),
              maxLines: 1, // 确保文本只显示一行
              overflow: TextOverflow.ellipsis, // 如果文本过长，显示省略号
            ),
          ),
        ],
      ),
    );
  }
}
