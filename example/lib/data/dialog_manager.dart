import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:jl_ota_example/dialog/download_file_dialog.dart';

import '../dialog/computer_transfer_dialog.dart';
import '../dialog/ota_dialog.dart';
import '../dialog/select_file_save_dialog.dart';

/// Manages the display of various dialogs related to OTA operations.
class DialogManager {
  final BuildContext context;
  final MethodChannel methodChannel;

  DialogManager({required this.context, required this.methodChannel});

  Widget buildSaveFileDialog(String fileName) {
    return SelectFileSaveDialog(fileName: fileName, methodChannel: methodChannel);
  }

  Widget buildComputerTransferDialog() {
    return ComputerTransferDialog();
  }

  Widget buildOtaDialog() {
    return OtaDialog();
  }

  Widget buildDownloadFileDialog(String result) {
    return DownloadFileDialog(result: result);
  }

  Future<void> showSaveFileDialog(String fileName) async {
    final dialog = buildSaveFileDialog(fileName);
    await showDialog(context: context, builder: (context) => dialog);
  }

  Future<void> showComputerTransferDialog() async {
    final dialog = buildComputerTransferDialog();
    await showDialog(context: context, builder: (context) => dialog);
  }

  Future<void> showOtaDialog() async {
    final dialog = buildOtaDialog();
    await showDialog(context: context, builder: (context) => dialog);
  }

  Future<void> showDownloadFileDialog(String result) async {
    final dialog = buildDownloadFileDialog(result);
    await showDialog(context: context, builder: (context) => dialog);
  }
}
