import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'package:jl_ota/constant/constants.dart';

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
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (int progress) {
            // Update loading bar.
            log("Loading $progress%");
          },
          onPageStarted: (String url) {
            log("Page started loading: $url");
          },
          onPageFinished: (String url) {
            log("Page finished loading: $url");
          },
          onWebResourceError: (WebResourceError error) {
            log("Web resource error: ${error.description}");
          },
          onNavigationRequest: (NavigationRequest request) {
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.url));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        leading: IconButton(
          icon: Image.asset(
            'assets/images/ic_return.png',
            width: AppConstants.returnIconSizeValue, // 设置图片宽度为28
            height: AppConstants.returnIconSizeValue, // 设置图片高度为28
          ),
          onPressed: () {
            Navigator.of(context).pop(); // 返回上一页
          },
        ),
        title: Text(
          widget.title.replaceAll('《', '').replaceAll('》', ''),
          style: TextStyle(fontSize: 18, color: Color(0xFF242424), fontFamily: 'PingFangSC-Medium', fontWeight: FontWeight.bold),
        ),
        centerTitle: true, // 标题居中
      ),
      body: WebViewWidget(controller: _controller),
    );
  }
}
