import 'dart:async';
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:jl_ota/constant/constants.dart';
import 'package:jl_ota_example/utils/app_util.dart';

import 'package:jl_ota/ble_event_stream.dart';
import 'package:jl_ota/ble_method.dart';
import 'package:jl_ota/constant/ble_event_constants.dart';
import '../pages/download_file_content.dart';

/// A dialog widget for displaying download progress.
class DownloadFileDialog extends StatefulWidget {
  final String result;

  const DownloadFileDialog({super.key, required this.result});

  @override
  State<DownloadFileDialog> createState() => _DownloadFileDialogState();
}

class _DownloadFileDialogState extends State<DownloadFileDialog> {
  int _progress = 0;
  String fileName = '';
  StreamSubscription? _downloadStatusSubscription;

  static const double dialogOpacity = 1.0;
  static const Duration dialogDuration = Duration(milliseconds: 100);
  static const EdgeInsets dialogInsetPadding = EdgeInsets.only(left: 12, right: 12, bottom: 34);
  static const Alignment dialogAlignment = Alignment.bottomCenter;
  static const double dialogHeight = 148;
  static const double dialogPadding = 24;

  static final BorderRadius dialogBorderRadius = BorderRadius.circular(15.0);

  @override
  void initState() {
    super.initState();
    fileName = AppConstants.updateFileName;

    List<String> fileNames = widget.result.split("/").where((part) => part.isNotEmpty).toList();
    if (fileNames.isNotEmpty) {
      fileName = fileNames.last;
    }

    _downloadFile(widget.result);
    _startListeningToDownloadStatus();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) async {
        if (didPop) return;
      },
      child: AnimatedOpacity(
        opacity: dialogOpacity,
        duration: dialogDuration,
        child: Dialog(
          insetPadding: dialogInsetPadding,
          alignment: dialogAlignment,
          shape: RoundedRectangleBorder(borderRadius: dialogBorderRadius),
          elevation: 0,
          backgroundColor: Colors.transparent,
          child: SizedBox(
            width: screenWidth - dialogPadding,
            height: dialogHeight,
            child: Material(
              borderRadius: dialogBorderRadius,
              color: Colors.white,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [DownloadFileContent(progress: _progress, fileName: fileName)],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    super.dispose();
    _downloadStatusSubscription?.cancel();
  }

  Future<void> _downloadFile(String httpUrl) async {
    try {
      await BleMethod.downloadFile(httpUrl);
      log("File downloaded successfully from $httpUrl");
    } catch (e) {
      log("Failed to download file: $e");
    }
  }

  void _startListeningToDownloadStatus() {
    _downloadStatusSubscription = BleEventStream.downloadStatusStream.listen((data) {
      setState(() {
        var state = data[BleEventConstants.KEY_STATUS];
        if (state == BleEventConstants.STATUS_ON_STOP || state == BleEventConstants.STATUS_ON_ERROR) {
          if (mounted) {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
              AppUtil.readFileList();
            }
          }
        }
        final progressValue = data[BleEventConstants.KEY_PROGRESS];
        if (state == BleEventConstants.STATUS_ON_PROGRESS && progressValue != null) {
          _progress = progressValue;
        }
      });
    });
  }
}
