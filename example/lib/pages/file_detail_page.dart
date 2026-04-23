import 'dart:async';
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:jl_ota/ble_event_stream.dart';
import 'package:jl_ota/ble_method.dart';
import 'package:jl_ota/constant/constants.dart';
import 'package:jl_ota_example/extensions/hex_color.dart';

import 'package:jl_ota/constant/ble_event_constants.dart';

/// A page that displays the detailed content of a log file.
class FileDetailPage extends StatefulWidget {
  final Map<String, String> logFile;
  final int index;

  const FileDetailPage({super.key, required this.logFile, required this.index});

  @override
  State<FileDetailPage> createState() => _FileDetailPageState();
}

class _FileDetailPageState extends State<FileDetailPage> {
  StreamSubscription? logDetailSubscription;
  String logDetailTxt = '';
  final String appKeyword = 'app_';

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: FittedBox(
          fit: BoxFit.scaleDown,
          child: Container(
            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.8),
            child: Text(
              _getDisplayName(widget.logFile[BleEventConstants.KEY_NAME] ?? ''),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
              style: TextStyle(color: Color(0xFF242424), fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
        ),
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
        backgroundColor: Colors.white,
        centerTitle: true,
        actions: [
          IconButton(
            icon: Image.asset('assets/images/icon_share.png', width: 28, height: 28),
            onPressed: () async {
              await BleMethod.shareLogFile(widget.index);
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.only(top: 16, left: 20, right: 20),
        child: Text(
          logDetailTxt,
          style: TextStyle(color: HexColor.hexColor("#606060"), fontSize: 14, fontFamily: 'PingFangSC-Medium'),
        ),
      ),
    );
  }

  @override
  void dispose() {
    logDetailSubscription?.cancel();
    super.dispose();
  }

  void _initialize() async {
    BleMethod.clickLogFileIndex(widget.index);

    logDetailSubscription = BleEventStream.logDetailFilesStream.listen(
      (logDetail) {
        setState(() {
          logDetailTxt = logDetail;
        });
      },
      onError: (error) {
        log("Error listening to logDetailFilesStream: $error");
        logDetailSubscription?.cancel();
      },
    );
  }

  String _getDisplayName(String fullName) {
    if (fullName.isEmpty) return '';

    final appIndex = fullName.indexOf(appKeyword);
    if (appIndex != -1) {
      // appIndex不为-1
      return '...${fullName.substring(appIndex)}';
    }
    return fullName;
  }
}
