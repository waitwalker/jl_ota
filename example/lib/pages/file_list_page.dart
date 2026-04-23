import 'dart:async';
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:jl_ota/ble_event_stream.dart';
import 'package:jl_ota/ble_method.dart';
import 'package:jl_ota_example/pages/file_detail_page.dart';

import 'package:jl_ota/constant/ble_event_constants.dart';
import '../dialog/delete_all_log_dialog.dart';
import '../l10n/app_localizations.dart';

/// Log file list page
class FileListPage extends StatefulWidget {
  const FileListPage({super.key});

  @override
  State<FileListPage> createState() => _FileListPageState();
}

class _FileListPageState extends State<FileListPage> {
  List<Map<String, String>> _logFileList = [];
  StreamSubscription? _logFileListSubscription;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  void _initialize() async {
    _getLogFileList();
    _subscribeToLogFileListStream();
  }

  void _getLogFileList() async {
    try {
      await BleMethod.getLogFiles();
    } catch (e, stackTrace) {
      log("Failed to get log files: $e", error: e, stackTrace: stackTrace);
    }
  }

  void _subscribeToLogFileListStream() {
    _logFileListSubscription = BleEventStream.logFilesStream.listen(
      (logFileList) {
        setState(() {
          _logFileList = logFileList;
        });
      },
      onError: (error) {
        log("Error listening to logFilesStream: $error", error: error);
      },
    );
  }

  void _onLogFileTap(Map<String, String> logFile, int index) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FileDetailPage(logFile: logFile, index: index),
      ),
    );
  }

  void _showDeleteAllDialog(BuildContext context) async {
    await showDialog(
      context: context,
      builder: (context) => DeleteAllLogDialog(onCancel: _dismissDialog, onConfirm: _deleteAllLogFiles),
    );
  }

  void _dismissDialog() {
    if (mounted) {
      Navigator.pop(context);
    }
  }

  Future<void> _deleteAllLogFiles() async {
    if (mounted) {
      Navigator.pop(context);
      try {
        await BleMethod.deleteAllLogFiles();
        setState(() {
          _logFileList = [];
        });
      } catch (e, stackTrace) {
        log("Failed to delete all log files: $e", error: e, stackTrace: stackTrace);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(appBar: _buildAppBar(), body: _buildBody());
  }

  AppBar _buildAppBar() {
    return AppBar(
      title: Text(
        AppLocalizations.of(context)!.logFile,
        style: const TextStyle(color: Color(0xFF242424), fontSize: 18, fontWeight: FontWeight.bold),
      ),
      leading: IconButton(icon: Image.asset('assets/images/ic_return.png', width: 28, height: 28), onPressed: _dismissDialog),
      backgroundColor: Colors.white,
      centerTitle: true,
      actions: [IconButton(icon: Image.asset('assets/images/ic_delete.png', width: 28, height: 28), onPressed: () => _showDeleteAllDialog(context))],
    );
  }

  Widget _buildBody() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (_logFileList.isNotEmpty)
            Expanded(
              child: ListView.builder(
                itemCount: _logFileList.length,
                itemBuilder: (context, index) {
                  final logFile = _logFileList[index];
                  return _buildLogFileItem(logFile, index);
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLogFileItem(Map<String, String> logFile, int index) {
    return Column(
      children: [
        InkWell(
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
          hoverColor: Colors.transparent,
          onTap: () {
            _onLogFileTap(logFile, index);
          },
          child: ListTile(
            contentPadding: const EdgeInsets.only(left: 20, right: 15),
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(logFile[BleEventConstants.KEY_NAME] ?? ''),
                Image.asset('assets/images/ic_arrow_right_gray.png', width: 16, height: 16),
              ],
            ),
          ),
        ),
        if (index < _logFileList.length - 1) const Divider(height: 1, thickness: 1, indent: 20, color: Color(0x0D000000)),
      ],
    );
  }

  @override
  void dispose() {
    _logFileListSubscription?.cancel();
    super.dispose();
  }
}
