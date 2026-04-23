import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:jl_ota/constant/constants.dart';
import 'package:jl_ota_example/pages/webview_page.dart';
import 'package:jl_ota/ble_method.dart';
import '../extensions/hex_color.dart';
import '../l10n/app_localizations.dart';

/// AboutPage displays application information including:
/// - App logo and version
/// - User agreement and privacy policy links
/// - Copyright and ICP information
class AboutPage extends StatefulWidget {
  const AboutPage({super.key});

  @override
  State<AboutPage> createState() => _AboutPageState();
}

class _AboutPageState extends State<AboutPage> {
  String _appVersion = "";

  // 颜色常量
  static final Color _primaryTextColor = HexColor.hexColor("#242424");
  static final Color _secondaryTextColor = HexColor.hexColor("#838383");
  static final Color _lightTextColor = const Color.fromRGBO(0, 0, 0, 0.6);
  static final Color _lighterTextColor = const Color.fromRGBO(0, 0, 0, 0.3);
  static final Color _dividerColor = const Color(0x0D000000);
  static final Color _backgroundColor = Colors.white;

  // 文本样式常量
  static const TextStyle _appBarTextStyle = TextStyle(color: Color(0xFF242424), fontSize: 18, fontWeight: FontWeight.bold);

  static const TextStyle _appNameTextStyle = TextStyle(fontSize: 16, fontWeight: FontWeight.bold);

  static const TextStyle _versionTextStyle = TextStyle(fontSize: 13, fontFamily: 'PingFangSC-Medium');

  static const TextStyle _linkTextStyle = TextStyle(fontSize: 15, fontWeight: FontWeight.bold);

  static const TextStyle _footerTextStyle = TextStyle(fontSize: 11, fontFamily: 'PingFangSC-Medium');

  // 尺寸常量
  static const double _logoSize = 80.0;
  static const double _listItemHeight = 48.0;
  static const double _horizontalPadding = 18.0;
  static const double _arrowIconSize = 16.0;
  static const double _topSpacingFactor = 0.07;
  static const double _smallSpacing = 2.0;
  static const double _mediumSpacing = 16.0;
  static const double _largeSpacing = 24.0;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;

    return Scaffold(appBar: _buildAppBar(context), body: _buildBody(context, loc));
  }

  AppBar _buildAppBar(BuildContext context) {
    return AppBar(
      title: Text(AppLocalizations.of(context)!.aboutApp, style: _appBarTextStyle),
      leading: IconButton(icon: Image.asset('assets/images/ic_return.png', width: 28, height: 28), onPressed: () => Navigator.of(context).pop()),
      backgroundColor: _backgroundColor,
      centerTitle: true,
    );
  }

  Widget _buildBody(BuildContext context, AppLocalizations loc) {
    return Column(
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * _topSpacingFactor),
        _buildAppInfo(loc),
        SizedBox(height: _largeSpacing),
        _buildLinksSection(context, loc),
        const Spacer(),
        _buildFooterSection(context, loc),
      ],
    );
  }

  Widget _buildAppInfo(AppLocalizations loc) {
    return Column(
      children: [
        Image.asset('assets/images/ic_app_logo_small.png', height: _logoSize, width: _logoSize),
        SizedBox(height: _mediumSpacing),
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(loc.appName, style: _appNameTextStyle.copyWith(color: Color.fromRGBO(0, 0, 0, 0.9))),
            SizedBox(height: _smallSpacing),
            Text("${loc.currentAppVersion}:\u2000$_appVersion", style: _versionTextStyle.copyWith(color: _lightTextColor)),
          ],
        ),
      ],
    );
  }

  Widget _buildLinksSection(BuildContext context, AppLocalizations loc) {
    return Column(
      children: [
        _buildLinkItem(
          context: context,
          title: loc.userAgreement.replaceAll('《', '').replaceAll('》', ''),
          url: AppConstants.userAgreementUrl,
          pageTitle: loc.userAgreement,
        ),
        _buildDivider(),
        _buildLinkItem(
          context: context,
          title: loc.privacyPolicy.replaceAll('《', '').replaceAll('》', ''),
          url: AppConstants.privacyPolicyUrl,
          pageTitle: loc.privacyPolicy,
        ),
      ],
    );
  }

  Widget _buildLinkItem({required BuildContext context, required String title, required String url, required String pageTitle}) {
    return Material(
      color: _backgroundColor,
      child: InkWell(
        onTap: () => _openWebView(context, url, pageTitle),
        highlightColor: Colors.transparent, // 移除点击时的高亮效果
        splashColor: Colors.transparent, // 移除点击时的水波纹效果
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: _horizontalPadding),
          height: _listItemHeight,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: _linkTextStyle.copyWith(color: _primaryTextColor)),
              Image.asset('assets/images/ic_arrow_right_gray.png', width: _arrowIconSize, height: _arrowIconSize, color: _secondaryTextColor),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Divider(height: 1, thickness: 1, indent: 20, color: _dividerColor);
  }

  Widget _buildFooterSection(BuildContext context, AppLocalizations loc) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [_buildIcpInfo(context, loc), const SizedBox(height: 3), _buildCopyrightInfo(loc), const SizedBox(height: 30)],
      ),
    );
  }

  Widget _buildIcpInfo(BuildContext context, AppLocalizations loc) {
    return GestureDetector(
      onTap: () => _showIcpDetails(context),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: SizedBox(
          width: double.infinity,
          child: Text(
            '${loc.icpInfo}:${AppConstants.icpNumber}',
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: _footerTextStyle.copyWith(color: _lighterTextColor),
          ),
        ),
      ),
    );
  }

  Widget _buildCopyrightInfo(AppLocalizations loc) {
    return SizedBox(
      width: double.infinity,
      child: Text(
        loc.copyRight,
        textAlign: TextAlign.center,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: _footerTextStyle.copyWith(color: _lighterTextColor),
      ),
    );
  }

  void _initialize() async {
    _getAppVersion();
  }

  void _getAppVersion() async {
    try {
      String appVersion = await BleMethod.getAppVersion();
      setState(() {
        _appVersion = appVersion.replaceFirst(RegExp(r'\(.*\)'), '');
      });
    } catch (e) {
      log("Failed to get app version: $e");
    }
  }

  void _showIcpDetails(BuildContext context) {
    _openWebView(context, AppConstants.icpUrl, AppConstants.icpNumber);
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
