import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:jl_ota/constant/constants.dart';
import '../dialog/privacy_policy_dialog.dart';
import '../l10n/app_localizations.dart';
import '../utils/app_util.dart';
import '../utils/share_preference.dart';
import 'main_page.dart';

/// WelcomePage is a StatelessWidget used to display the application's welcome page.
class WelcomePage extends StatefulWidget {
  const WelcomePage({super.key});

  @override
  State<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends State<WelcomePage> {
  // Define color constants
  static const Color companyNameColor = Color(0xFFBFD9FF);
  static const Color copyrightColor = Color(0xFFD6E8FF);
  static const Color whiteColor = Colors.white;
  static const Color transparentColor = Colors.transparent;

  // Define spacing constants
  static const double logoTopOffset = 180.0;
  static const double logoImageSize = 90.0;
  static const double logoHeight = 107.0;
  static const double logoTextSpacing = 10.0;
  static const double bottomSpacing = 16.0;
  static const double appNameFontSize = 20.0;
  static const double companyNameFontSize = 12.0;
  static const double copyrightFontSize = 10.0;

  // Other constants
  static const int delayMilliseconds = 1000;
  static const String logoImagePath = 'assets/images/ic_launcher_logo.png';
  static const String backgroundImagePath = 'assets/images/icons/bg_launcher.png';
  static const String pingFangFontFamily = 'PingFangSC-Medium';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _checkPrivacyPolicyAccepted(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    _setSystemUIOverlayStyle();
    return Scaffold(extendBodyBehindAppBar: true, body: _buildWelcomePageBody(context));
  }

  void _setSystemUIOverlayStyle() {
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(statusBarColor: transparentColor, statusBarIconBrightness: Brightness.dark, statusBarBrightness: Brightness.light),
    );
  }

  Widget _buildWelcomePageBody(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        image: DecorationImage(image: AssetImage(backgroundImagePath), fit: BoxFit.cover),
      ),
      child: Stack(children: [_buildLogoAndAppName(context), _buildBottomText(context)]),
    );
  }

  Widget _buildLogoAndAppName(BuildContext context) {
    return Positioned(
      top: MediaQuery.of(context).size.height / 2 - logoTopOffset,
      left: 0,
      right: 0,
      child: Center(
        child: Column(
          children: [
            Image.asset(logoImagePath, width: logoImageSize, height: logoHeight, fit: BoxFit.contain),
            const SizedBox(height: logoTextSpacing),
            Text(
              AppLocalizations.of(context)!.appName,
              style: TextStyle(fontSize: appNameFontSize, color: whiteColor, fontFamily: pingFangFontFamily),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomText(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text(
            AppLocalizations.of(context)!.companyName,
            style: TextStyle(fontSize: companyNameFontSize, fontFamily: pingFangFontFamily, color: companyNameColor),
          ),
          Text(
            AppLocalizations.of(context)!.copyRight,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: copyrightFontSize, color: copyrightColor, fontFamily: pingFangFontFamily),
          ),
          const SizedBox(height: bottomSpacing),
        ],
      ),
    );
  }
}

Future<void> _checkPrivacyPolicyAccepted(BuildContext context) async {
  final agreePolicyState = await FilePreferenceManager.loadAgreePolicy();
  if (!agreePolicyState && context.mounted) {
    _showPrivacyPolicyDialog(context);
  } else if (context.mounted) {
    // 延迟 1s 进入主页
    _navigateToMainPageAfterDelay(context, _WelcomePageState.delayMilliseconds);
  }
}

void _navigateToMainPageAfterDelay(BuildContext context, int delayMilliseconds) {
  Future.delayed(Duration(milliseconds: delayMilliseconds), () {
    if (context.mounted) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const MainPage()));
    }
  });
}

void _showPrivacyPolicyDialog(BuildContext context) {
  final isAndroid = AppUtil.isAndroid;

  showDialog(
    context: context,
    barrierDismissible: false, // Prevent closing by tapping outside
    builder: (context) => PrivacyPolicyDialog(
      onAgree: () async {
        await FilePreferenceManager.saveAgreePolicy(true);
        if (context.mounted) {
          Navigator.pop(context); // Close the dialog
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const MainPage()));
        }
      },
      onDisagree: () {
        if (isAndroid) {
          SystemNavigator.pop();
        } else {
          exit(0);
        }
      },
      userAgreementUrl: AppConstants.userAgreementUrl,
      privacyPolicyUrl: AppConstants.privacyPolicyUrl,
    ),
  );
}
