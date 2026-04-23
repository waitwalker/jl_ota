import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../pages/webview_page.dart';

/// A dialog widget that displays privacy policy and user agreement information.
class PrivacyPolicyDialog extends StatelessWidget {
  final VoidCallback onAgree;
  final VoidCallback onDisagree;
  final String userAgreementUrl;
  final String privacyPolicyUrl;

  const PrivacyPolicyDialog({
    super.key,
    required this.onAgree,
    required this.onDisagree,
    required this.userAgreementUrl,
    required this.privacyPolicyUrl,
  });

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;

    return AlertDialog(
      titlePadding: const EdgeInsets.only(top: 28),
      title: Center(
        child: Text(
          loc.privacyPolicyDialogTitle,
          style: TextStyle(fontSize: 17, fontFamily: 'PingFangSC-Medium', fontWeight: FontWeight.bold, color: const Color(0xFF242424)),
        ),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            RichText(
              text: TextSpan(
                style: TextStyle(
                  height: 1.5,
                  fontSize: 14,
                  fontFamily: 'PingFangSC-Medium',
                  fontWeight: FontWeight.bold,
                  color: const Color(0xCC000000),
                ),
                children: [
                  TextSpan(text: loc.welcomeMessage),
                  TextSpan(
                    text: loc.userAgreement,
                    style: TextStyle(height: 1.5, decoration: TextDecoration.underline, color: Colors.blue),
                    recognizer: TapGestureRecognizer()..onTap = () => _openWebView(context, userAgreementUrl, loc.userAgreement),
                  ),
                  TextSpan(text: loc.and),
                  TextSpan(
                    text: loc.privacyPolicy,
                    style: TextStyle(height: 1.5, decoration: TextDecoration.underline, color: Colors.blue),
                    recognizer: TapGestureRecognizer()..onTap = () => _openWebView(context, privacyPolicyUrl, loc.privacyPolicy),
                  ),
                  TextSpan(
                    text: loc.agreementText,
                    style: TextStyle(
                      height: 1.5,
                      fontSize: 14,
                      fontFamily: 'PingFangSC-Medium',
                      fontWeight: FontWeight.bold,
                      color: const Color(0xCC000000),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: onAgree,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF398BFF),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: Text(
                      loc.agreeButton,
                      style: TextStyle(fontSize: 15, fontFamily: 'PingFangSC-Medium', color: Colors.white),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: onDisagree,
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0x80000000),
                      overlayColor: Colors.transparent, // 移除点击时的覆盖色
                      splashFactory: NoSplash.splashFactory, // 移除水波纹效果
                    ),
                    child: Text(
                      loc.disagreeButton,
                      style: TextStyle(fontSize: 15, fontFamily: 'PingFangSC-Medium', color: const Color(0x80000000)),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: Colors.white,
    );
  }

  void _openWebView(BuildContext context, String url, String title) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => WebViewPage(
          title: title, // 标题
          url: url, // 链接地址
        ),
      ),
    );
  }
}
