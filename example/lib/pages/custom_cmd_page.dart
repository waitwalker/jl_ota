import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:jl_ota/ble_event_stream.dart';
import 'package:jl_ota/ble_method.dart';
import 'package:jl_ota/constant/constants.dart';
import 'package:provider/provider.dart';
import '../l10n/app_localizations.dart';
import 'dart:typed_data';

import '../utils/connection_state_manager.dart';

/// Custom command page for sending and receiving data
class CustomCmdPage extends StatefulWidget {
  const CustomCmdPage({super.key});

  @override
  State<CustomCmdPage> createState() => _CustomCmdPageState();
}

class _CustomCmdPageState extends State<CustomCmdPage> {
  Uint8List? _receivedData;
  StreamSubscription<Uint8List>? _dataSubscription;
  final TextEditingController _textController = TextEditingController();
  final FocusNode _textFocusNode = FocusNode();
  bool _isSending = false;

  int _connectState = AppConstants.connectionFailed;

  // Color constants
  static const Color _backgroundColor = Colors.white;
  static const double _paddingTop = 10.0;

  // Text style constants
  static const TextStyle _appBarTextStyle = TextStyle(color: Color(0xFF242424), fontSize: 18, fontWeight: FontWeight.bold);

  // UI String constants
  static const String _hintText = 'Enter text here...';
  static const String _inputDataHint = 'Enter text to send (will be converted to UTF-8 bytes)';
  static const String _noDataReceivedText = 'No data received yet';
  static const String _clearIconTooltip = 'Clear';
  static const String _previewText = 'Preview';
  static const String _charactersLabel = 'Characters: ';
  static const String _bytesLabel = 'Bytes: ';
  static const String _lengthLabel = 'Length: ';
  static const String _hexLabel = 'Hex: ';
  static const String _asciiLabel = 'ASCII: ';
  static const String _utf8Label = 'UTF-8: ';
  static const String _nonAsciiMessage = '[Non-ASCII characters]';
  static const String _conversionErrorMessage = '[Conversion error]';
  static const String _utf8DecodeErrorMessage = '[UTF-8 decode error]';
  static const String _sentSuccessMessage = 'Sent ';
  static const String _bytesSentMessage = ' bytes successfully';
  static const String _pleaseEnterTextMessage = 'Please enter some text';
  static const String _failedToConvertMessage = 'Failed to convert text to bytes';
  static const String _previewDialogTitle = 'Data Preview';
  static const String _bytesLabelShort = 'Bytes: ';
  static const String _okButtonText = 'OK';

  // Numeric constants
  static const double _sendButtonVerticalPadding = 16.0;
  static const double _circularProgressSize = 20.0;
  static const double _circularProgressStrokeWidth = 2.0;
  static const double _dataDisplayHeightFactor = 0.5;

  static const int _snackBarDurationSeconds = 2;
  static const int _textFieldMaxLines = 3;
  static const int _textFieldMinLines = 1;
  static const int _asciiMinChar = 32;
  static const int _asciiMaxChar = 126;
  static const int _hexPadLeftLength = 2;
  static const String _hexPadLeftChar = '0';

  // Spacing constants
  static const double _spacingSmall = 8.0;
  static const double _spacingMedium = 10.0;
  static const double _spacingLarge = 20.0;
  static const double _spacingExtraLarge = 16.0;

  @override
  void initState() {
    super.initState();
    _dataSubscription = BleEventStream.customCommandData.listen((data) {
      if (mounted && data.isNotEmpty) {
        setState(() {
          _receivedData = data;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;

    _connectState = context.watch<ConnectionStateManager>().connectState;

    // Handle device disconnection
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_connectState == AppConstants.connectionDisconnect && mounted) {
        if (Navigator.of(context, rootNavigator: true).canPop()) {
          Navigator.of(context).pop();
        } else {
          Navigator.of(context).maybePop();
        }
      }
    });

    return Scaffold(
      appBar: _buildAppBar(context, loc),
      body: Builder(
        builder: (context) {
          return GestureDetector(
            onTap: () {
              FocusScope.of(context).unfocus();
            },
            behavior: HitTestBehavior.opaque,
            child: _buildBody(loc),
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _dataSubscription?.cancel();
    _textController.dispose();
    _textFocusNode.dispose();
    super.dispose();
  }

  /// Builds the app bar for the page
  AppBar _buildAppBar(BuildContext context, AppLocalizations loc) {
    return AppBar(
      title: Text(loc.customCommand, style: _appBarTextStyle),
      leading: IconButton(icon: Image.asset('assets/images/ic_return.png', width: 28, height: 28), onPressed: () => Navigator.of(context).pop()),
      backgroundColor: _backgroundColor,
      centerTitle: true,
    );
  }

  /// Builds the main content of the page
  Widget _buildBody(AppLocalizations loc) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(_paddingTop),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Input section
          _buildInputSection(loc),

          // Send button
          const SizedBox(height: _spacingLarge),
          _buildSendButton(loc),

          // Received data display section
          const SizedBox(height: _spacingLarge),
          Text(
            loc.receivedData,
            style: const TextStyle(fontSize: _spacingExtraLarge, fontWeight: FontWeight.bold, color: Colors.black87),
          ),
          const SizedBox(height: _spacingMedium),
          // Wrap data display area with GestureDetector
          GestureDetector(
            onTap: () {
              FocusScope.of(context).unfocus();
            },
            child: _buildDataDisplay(),
          ),
        ],
      ),
    );
  }

  /// Builds the input section with text field
  Widget _buildInputSection(AppLocalizations loc) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          loc.inputData,
          style: const TextStyle(fontSize: _spacingExtraLarge, fontWeight: FontWeight.bold, color: Colors.black87),
        ),
        const SizedBox(height: _spacingSmall),
        const Text(_inputDataHint, style: TextStyle(fontSize: 14, color: Colors.grey)),
        const SizedBox(height: _spacingSmall),
        // Wrap TextField with GestureDetector to prevent keyboard dismissal
        GestureDetector(
          onTap: () {
            // Request focus when tapping on TextField area
            _textFocusNode.requestFocus();
          },
          child: TextField(
            controller: _textController,
            focusNode: _textFocusNode,
            decoration: InputDecoration(
              hintText: _hintText,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(_spacingSmall),
                borderSide: const BorderSide(color: Colors.grey),
              ),
              filled: true,
              fillColor: Colors.grey[50],
              contentPadding: const EdgeInsets.symmetric(horizontal: _spacingExtraLarge, vertical: 12),
              suffixIcon: IconButton(
                icon: const Icon(Icons.clear),
                tooltip: _clearIconTooltip,
                onPressed: () {
                  _textController.clear();
                  setState(() {});
                },
              ),
            ),
            maxLines: _textFieldMaxLines,
            minLines: _textFieldMinLines,
            style: const TextStyle(fontSize: _spacingExtraLarge),
            onChanged: (value) {
              setState(() {});
            },
          ),
        ),
        const SizedBox(height: _spacingSmall),
        // Display text statistics
        _buildTextStats(),
      ],
    );
  }

  /// Builds text statistics row
  Widget _buildTextStats() {
    final text = _textController.text;
    final bytes = utf8.encode(text);

    return Row(
      children: [
        Text('$_charactersLabel${text.length}', style: TextStyle(fontSize: 14, color: Colors.grey[700])),
        const SizedBox(width: _spacingLarge),
        Text('$_bytesLabel${bytes.length}', style: TextStyle(fontSize: 14, color: bytes.isEmpty ? Colors.red : Colors.green)),
        const SizedBox(width: _spacingLarge),
        if (bytes.isNotEmpty)
          GestureDetector(
            onTap: () {
              _showPreviewDialog(Uint8List.fromList(bytes));
            },
            child: Text(
              _previewText,
              style: const TextStyle(fontSize: 14, color: Colors.blue, decoration: TextDecoration.underline),
            ),
          ),
      ],
    );
  }

  /// Builds the send button
  Widget _buildSendButton(AppLocalizations loc) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _textController.text.trim().isNotEmpty && !_isSending
            ? () {
                // Dismiss keyboard before sending
                FocusScope.of(context).unfocus();
                _sendCustomCmdToDevice();
              }
            : null,
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: _sendButtonVerticalPadding),
          backgroundColor: _textController.text.trim().isNotEmpty ? Colors.blue : Colors.grey,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_spacingSmall)),
        ),
        child: _isSending
            ? const SizedBox(
                width: _circularProgressSize,
                height: _circularProgressSize,
                child: CircularProgressIndicator(strokeWidth: _circularProgressStrokeWidth, valueColor: AlwaysStoppedAnimation(Colors.white)),
              )
            : Text(
                loc.sendCustomCmd,
                style: const TextStyle(fontSize: _spacingExtraLarge, fontWeight: FontWeight.bold, color: Colors.white),
              ),
      ),
    );
  }

  /// Builds the data display area
  Widget _buildDataDisplay() {
    return Container(
      width: double.infinity,
      height: MediaQuery.of(context).size.height * _dataDisplayHeightFactor,
      padding: const EdgeInsets.all(_spacingExtraLarge),
      decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(_spacingSmall)),
      child: _receivedData == null
          ? Text(_noDataReceivedText, style: const TextStyle(fontSize: 14, color: Colors.grey))
          : SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$_lengthLabel${_receivedData!.length} bytes',
                    style: const TextStyle(fontSize: _spacingExtraLarge, color: Colors.black87),
                  ),
                  const SizedBox(height: _spacingSmall),
                  Text(
                    '$_hexLabel${_bytesToHex(_receivedData!)}',
                    style: const TextStyle(fontSize: _spacingExtraLarge, fontFamily: 'Monospace', color: Colors.blueGrey),
                  ),
                  const SizedBox(height: _spacingSmall),
                  Text(
                    '$_asciiLabel${_bytesToAscii(_receivedData!)}',
                    style: const TextStyle(fontSize: _spacingExtraLarge, fontFamily: 'Monospace', color: Colors.green),
                  ),
                  const SizedBox(height: _spacingSmall),
                  Text(
                    '$_utf8Label${_bytesToUtf8(_receivedData!)}',
                    style: const TextStyle(fontSize: _spacingExtraLarge, fontFamily: 'Monospace', color: Colors.orange),
                  ),
                ],
              ),
            ),
    );
  }

  /// Sends custom command to device
  Future<void> _sendCustomCmdToDevice() async {
    final text = _textController.text.trim();
    if (text.isEmpty) {
      _showError(_pleaseEnterTextMessage);
      return;
    }

    final bytes = utf8.encode(text);
    if (bytes.isEmpty) {
      _showError(_failedToConvertMessage);
      return;
    }

    BleMethod.sendCustomCommand(Uint8List.fromList(bytes));

    setState(() {
      _isSending = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$_sentSuccessMessage${bytes.length}$_bytesSentMessage'),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: _snackBarDurationSeconds),
      ),
    );
  }

  /// Shows error message
  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: _snackBarDurationSeconds),
      ),
    );
  }

  /// Shows data preview dialog
  void _showPreviewDialog(Uint8List bytes) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(_previewDialogTitle),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('$_bytesLabelShort${bytes.length}'),
              const SizedBox(height: _spacingSmall),
              Text('$_hexLabel${_bytesToHex(bytes)}'),
              const SizedBox(height: _spacingSmall),
              Text('$_asciiLabel${_bytesToAscii(bytes)}'),
              const SizedBox(height: _spacingSmall),
              Text('$_utf8Label${_bytesToUtf8(bytes)}'),
            ],
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text(_okButtonText))],
      ),
    );
  }

  /// Converts bytes to hex string
  String _bytesToHex(Uint8List bytes) {
    return bytes.map((b) => b.toRadixString(16).padLeft(_hexPadLeftLength, _hexPadLeftChar).toUpperCase()).join(' ');
  }

  /// Converts bytes to ASCII string
  String _bytesToAscii(Uint8List bytes) {
    try {
      final ascii = String.fromCharCodes(bytes.where((b) => b >= _asciiMinChar && b <= _asciiMaxChar));
      return ascii.isNotEmpty ? ascii : _nonAsciiMessage;
    } catch (e) {
      return _conversionErrorMessage;
    }
  }

  /// Converts bytes to UTF-8 string
  String _bytesToUtf8(Uint8List bytes) {
    try {
      return utf8.decode(bytes, allowMalformed: true);
    } catch (e) {
      return _utf8DecodeErrorMessage;
    }
  }
}
