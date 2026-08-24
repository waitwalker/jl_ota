import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:jl_ota/constant/constants.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// Constants for the web view page.
class WebViewConstants {
  /// Background color of the app bar.
  static const Color appBarBackgroundColor = Colors.white;

  /// Whether the title should be centered.
  static const bool centerTitle = true;

  /// Font size of the title.
  static const double titleFontSize = 18.0;

  /// Color of the title text.
  static const Color titleColor = Color(0xFF242424);

  /// Font family of the title.
  static const String titleFontFamily = 'PingFangSC-Medium';

  /// Asset path for the back icon.
  static const String backIconAsset = 'assets/images/ic_return.png';
}

/// A stateful widget that displays a web view with a custom title and URL.
class WebViewPage extends StatefulWidget {
  final String title;
  final String url;

  const WebViewPage({super.key, required this.title, required this.url});

  @override
  State<WebViewPage> createState() => _WebViewPageState();
}

class _WebViewPageState extends State<WebViewPage> {
  late final WebViewController _controller;

  @override
  void initState() {
    super.initState();
    _initializeWebViewController();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
      body: WebViewWidget(controller: _controller),
    );
  }

  /// Initializes the WebViewController with JavaScript and navigation settings.
  void _initializeWebViewController() {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(_buildNavigationDelegate())
      ..loadRequest(Uri.parse(widget.url));
  }

  /// Builds the navigation delegate for handling web view events.
  NavigationDelegate _buildNavigationDelegate() {
    return NavigationDelegate(
      onProgress: _handleProgress,
      onPageStarted: _handlePageStarted,
      onPageFinished: _handlePageFinished,
      onWebResourceError: _handleWebResourceError,
      onNavigationRequest: _handleNavigationRequest,
    );
  }

  /// Handles page loading progress.
  void _handleProgress(int progress) {
    log('Loading $progress%');
  }

  /// Handles page start loading event.
  void _handlePageStarted(String url) {
    log('Page started loading: $url');
  }

  /// Handles page finished loading event.
  void _handlePageFinished(String url) {
    log('Page finished loading: $url');
  }

  /// Handles web resource errors.
  void _handleWebResourceError(WebResourceError error) {
    log('Web resource error: ${error.description}');
  }

  /// Handles navigation requests.
  NavigationDecision _handleNavigationRequest(NavigationRequest request) {
    return NavigationDecision.navigate;
  }

  /// Builds the app bar with custom back button and title.
  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: WebViewConstants.appBarBackgroundColor,
      leading: _buildBackButton(),
      title: _buildTitle(),
      centerTitle: WebViewConstants.centerTitle,
    );
  }

  /// Builds the back button with custom icon.
  Widget _buildBackButton() {
    return IconButton(
      icon: Image.asset(WebViewConstants.backIconAsset, width: AppConstants.returnIconSizeValue, height: AppConstants.returnIconSizeValue),
      onPressed: _handleBackPress,
    );
  }

  /// Builds the title text with custom style.
  Widget _buildTitle() {
    final cleanTitle = _cleanTitle(widget.title);
    return Text(
      cleanTitle,
      style: const TextStyle(
        fontSize: WebViewConstants.titleFontSize,
        color: WebViewConstants.titleColor,
        fontFamily: WebViewConstants.titleFontFamily,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  /// Cleans the title by removing special characters.
  String _cleanTitle(String title) {
    return title.replaceAll('《', '').replaceAll('》', '');
  }

  /// Handles the back button press.
  void _handleBackPress() {
    Navigator.of(context).pop();
  }
}
