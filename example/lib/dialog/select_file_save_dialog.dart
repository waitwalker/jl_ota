import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:jl_ota/constant/ble_event_constants.dart';
import 'package:jl_ota_example/extensions/hex_color.dart';
import 'package:jl_ota_example/l10n/app_localizations.dart';
import 'package:jl_ota_example/widgets/toast_utils.dart';

import 'package:jl_ota/constant/constants.dart';

/// File save dialog component
///
/// This dialog allows users to input or confirm the filename to be saved.
/// Main features:
/// - Displays default filename (editable)
/// - Provides clear input field functionality
/// - Supports cancel and save operations
class SelectFileSaveDialog extends StatefulWidget {
  final String fileName;
  final MethodChannel methodChannel;

  const SelectFileSaveDialog({super.key, required this.fileName, required this.methodChannel});

  @override
  State<SelectFileSaveDialog> createState() => _SelectFileSaveDialogState();
}

class _SelectFileSaveDialogState extends State<SelectFileSaveDialog> {
  late TextEditingController _controller;
  late FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.fileName);
    _focusNode = FocusNode();
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  /// Handle save operation
  Future<void> _handleSave() async {
    try {
      await widget.methodChannel.invokeMethod(BleEventConstants.TYPE_HANDLE_FILE_PICKED, {BleEventConstants.KEY_FILE_NAME: _controller.text});
      if (mounted) {
        Navigator.pop(context);
        ToastUtils.show(context, AppLocalizations.of(context)!.pleaseRefreshWeb);
      }
    } catch (e) {
      log("Save file error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;

    return AnimatedOpacity(
      opacity: 1.0,
      duration: const Duration(milliseconds: 100),
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
        elevation: 0,
        backgroundColor: Colors.transparent,
        child: Material(
          borderRadius: BorderRadius.circular(12.0),
          color: Colors.white,
          child: Container(
            padding: const EdgeInsets.only(top: 36),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Title row
                _buildTitle(loc),
                // Input field area
                _buildInputField(),
                // Divider
                _buildDivider(),
                // Button area
                _buildButtonBar(loc),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Build title row
  Widget _buildTitle(AppLocalizations loc) {
    return Padding(
      padding: const EdgeInsets.only(left: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Text(
            loc.saveFile,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: HexColor.hexColor('#242424'), fontFamily: 'PingFangSC'),
          ),
        ],
      ),
    );
  }

  /// Build input field area
  Widget _buildInputField() {
    return Container(
      padding: const EdgeInsets.only(top: 26, bottom: 24),
      child: Center(
        child: SizedBox(
          width: double.infinity,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: TextField(
              controller: _controller,
              cursorColor: const Color.fromARGB(255, 10, 115, 202),
              focusNode: _focusNode,
              autofocus: true,
              style: const TextStyle(fontSize: 15, color: Colors.black, fontStyle: FontStyle.normal, fontFamily: 'PingFang SC'),
              decoration: InputDecoration(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 15.0),
                suffixIcon: IconButton(
                  icon: Image.asset('assets/images/icon_delete.png', width: 18, height: 18),
                  onPressed: () {
                    _controller.clear();
                  },
                ),
                filled: true,
                fillColor: HexColor.hexColor("#EFEFEF"),
                border: InputBorder.none,
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Build divider
  Widget _buildDivider() {
    return Container(color: HexColor.hexColor("#F5F5F5"), height: 1);
  }

  /// Build button bar
  Widget _buildButtonBar(AppLocalizations loc) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        // Cancel button
        _buildCancelButton(loc),
        // Button divider
        _buildButtonDivider(),
        // Save button
        _buildSaveButton(loc),
      ],
    );
  }

  /// Build cancel button
  Widget _buildCancelButton(AppLocalizations loc) {
    return Expanded(
      child: InkWell(
        // Remove ripple effect
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        onTap: () {
          if (mounted) {
            Navigator.pop(context);
          }
        },
        child: Container(
          height: AppConstants.dialogButtonHeight,
          alignment: Alignment.center,
          child: Text(
            loc.cancel,
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: HexColor.hexColor('#242424'), fontFamily: 'PingFangSC'),
          ),
        ),
      ),
    );
  }

  /// Build button divider
  Widget _buildButtonDivider() {
    return Container(width: 1, height: AppConstants.dialogButtonHeight, color: HexColor.hexColor("#F5F5F5"));
  }

  /// Build save button
  Widget _buildSaveButton(AppLocalizations loc) {
    return Expanded(
      child: InkWell(
        // Remove ripple effect
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        onTap: _handleSave,
        child: Container(
          height: AppConstants.dialogButtonHeight,
          alignment: Alignment.center,
          child: Text(
            loc.save,
            style: TextStyle(color: HexColor.hexColor("#398BFF"), fontSize: 15, fontWeight: FontWeight.bold, fontFamily: 'PingFang SC'),
          ),
        ),
      ),
    );
  }
}
