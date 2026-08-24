import 'package:flutter/material.dart';
import 'package:jl_ota_example/dialog/generic_confirm_dialog.dart';
import '../l10n/app_localizations.dart';

/// Service UUID input page
class ServiceUUIDInputPage extends StatefulWidget {
  final void Function(List<String> uuids)? onSave;
  final List<String> initialUUIDs;

  const ServiceUUIDInputPage({super.key, this.onSave, this.initialUUIDs = const []});

  @override
  State<ServiceUUIDInputPage> createState() => _ServiceUUIDInputPageState();
}

class _ServiceUUIDInputPageState extends State<ServiceUUIDInputPage> {
  late final TextEditingController _textController;
  late final FocusNode _focusNode;
  late final bool _hasInitialData;

  // UI Constants
  static const Color confirmTextColor = Color(0xFF398BFF);
  static const double textFieldHeight = 180;
  static const double buttonHeight = 44;
  static const double padding = 16.0;
  static const double borderRadius = 8.0;
  static const double placeholderLeft = 12.0;
  static const double placeholderTop = 12.0;
  static const double contentPadding = 12.0;

  // UUID validation patterns
  static final RegExp _hyphenPattern = RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$');
  static final RegExp _shortPattern = RegExp(r'^(?:[0-9a-fA-F]{4}|[0-9a-fA-F]{8}|[0-9a-fA-F]{32})$');
  static final RegExp _delimiterPattern = RegExp(r'[,\n]');

  bool get _showPlaceholder => _textController.text.isEmpty && !_hasInitialData;

  @override
  void initState() {
    super.initState();
    _initializeControllers();
    _prefillInitialData();
  }

  @override
  void dispose() {
    _disposeControllers();
    super.dispose();
  }

  void _initializeControllers() {
    _textController = TextEditingController();
    _focusNode = FocusNode();
    _hasInitialData = widget.initialUUIDs.isNotEmpty;
  }

  void _disposeControllers() {
    _textController.dispose();
    _focusNode.dispose();
  }

  void _prefillInitialData() {
    if (_hasInitialData) {
      _textController.text = widget.initialUUIDs.join('\n');
    }
  }

  /// Parse and validate UUID input
  _ParseResult _parseAndValidate(String input) {
    final parts = _parseInputToParts(input);

    if (parts.isEmpty) {
      return _ParseResult.empty();
    }

    final (valid, invalid) = _validateAndNormalizeUUIDs(parts);

    if (invalid.isNotEmpty) {
      return _ParseResult.invalidUUIDs(invalid);
    }

    final uniqueList = _duplicateKeepOrder(valid);
    return _ParseResult.success(uniqueList);
  }

  /// Parse input string to list of trimmed non-empty parts
  List<String> _parseInputToParts(String input) {
    return input.split(_delimiterPattern).map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
  }

  /// Validate UUIDs and separate valid from invalid
  (List<String> valid, List<String> invalid) _validateAndNormalizeUUIDs(List<String> parts) {
    final List<String> valid = [];
    final List<String> invalid = [];

    for (final part in parts) {
      if (_isValidUUID(part)) {
        valid.add(part.toUpperCase());
      } else {
        invalid.add(part);
      }
    }

    return (valid, invalid);
  }

  /// Check if a string matches UUID format
  bool _isValidUUID(String input) {
    return _hyphenPattern.hasMatch(input) || _shortPattern.hasMatch(input);
  }

  /// Remove duplicates while preserving order
  List<String> _duplicateKeepOrder(List<String> list) {
    return list.toSet().toList();
  }

  Future<void> _onSaveTapped(AppLocalizations loc) async {
    final result = _parseAndValidate(_textController.text);

    if (result.isSuccess) {
      await _saveAndClose(result.uuids);
    } else if (result.hasInvalidUUIDs) {
      await _showInvalidUUIDsDialog(result.invalidUUIDs, loc);
    } else if (result.isEmpty) {
      await _showErrorDialog(loc.gattUuidErrorEmpty, loc);
    }
  }

  Future<void> _saveAndClose(List<String> uuids) async {
    widget.onSave?.call(uuids);
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _showInvalidUUIDsDialog(List<String> invalids, AppLocalizations loc) async {
    final joined = invalids.join('\n');
    final message = loc.gattUuidErrorInvalidFmt.replaceFirst('%s', joined);
    await _showErrorDialog(message, loc);
  }

  Future<void> _showErrorDialog(String message, AppLocalizations loc) async {
    if (!mounted) return;

    await context.showConfirmDialog(message: message, confirmText: loc.confirm, onConfirm: () {}, showCancelButton: false);
  }

  void _unFocusTextField() {
    _focusNode.unfocus();
  }

  void _onTextFieldChanged(String _) {
    setState(() {});
  }

  Future<void> _onTextFieldSubmitted(AppLocalizations loc) async {
    await _onSaveTapped(loc);
  }

  bool get _isLightMode => Theme.of(context).brightness == Brightness.light;

  Color get _placeholderColor => _isLightMode ? Colors.grey.shade600 : Colors.grey.shade500;

  Color get _textFieldBackgroundColor => _isLightMode ? Colors.grey.shade100 : Colors.grey.shade800;

  Color get _tipsColor => _isLightMode ? Colors.grey.shade600 : Colors.grey.shade500;

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;

    return PopScope(
      canPop: false,
      child: GestureDetector(
        onTap: _unFocusTextField,
        child: Scaffold(backgroundColor: Theme.of(context).scaffoldBackgroundColor, appBar: _buildAppBar(loc), body: _buildBody(loc)),
      ),
    );
  }

  AppBar _buildAppBar(AppLocalizations loc) {
    return AppBar(title: Text(loc.gattServiceUuid), automaticallyImplyLeading: false);
  }

  Widget _buildBody(AppLocalizations loc) {
    return Padding(
      padding: const EdgeInsets.all(padding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [_buildTextField(loc), const SizedBox(height: 12), _buildTips(loc), const Spacer(), _buildConfirmButton(loc)],
      ),
    );
  }

  Widget _buildTextField(AppLocalizations loc) {
    return Container(
      height: textFieldHeight,
      decoration: BoxDecoration(color: _textFieldBackgroundColor, borderRadius: BorderRadius.circular(borderRadius)),
      child: Stack(children: [_buildTextInputField(loc), if (_showPlaceholder) _buildPlaceholder(loc)]),
    );
  }

  Widget _buildTextInputField(AppLocalizations loc) {
    return TextField(
      controller: _textController,
      focusNode: _focusNode,
      maxLines: null,
      expands: true,
      textAlignVertical: TextAlignVertical.top,
      decoration: const InputDecoration(border: InputBorder.none, contentPadding: EdgeInsets.all(contentPadding)),
      style: Theme.of(context).textTheme.bodyLarge,
      keyboardType: TextInputType.multiline,
      textInputAction: TextInputAction.done,
      onChanged: _onTextFieldChanged,
      onSubmitted: (_) => _onTextFieldSubmitted(loc),
    );
  }

  Widget _buildPlaceholder(AppLocalizations loc) {
    return Positioned(
      left: placeholderLeft,
      top: placeholderTop,
      child: Text(loc.gattUuidPlaceholder, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: _placeholderColor)),
    );
  }

  Widget _buildTips(AppLocalizations loc) {
    return Text(loc.gattUuidTips, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: _tipsColor));
  }

  Widget _buildConfirmButton(AppLocalizations loc) {
    return SizedBox(
      width: double.infinity,
      height: buttonHeight,
      child: ElevatedButton(
        onPressed: () => _onSaveTapped(loc),
        style: ElevatedButton.styleFrom(foregroundColor: confirmTextColor),
        child: Text(loc.confirm),
      ),
    );
  }
}

/// Parse result for UUID validation
class _ParseResult {
  final List<String>? _uuids;
  final List<String>? _invalidUUIDs;
  final bool _isEmpty;

  _ParseResult._({List<String>? uuids, List<String>? invalidUUIDs, bool isEmpty = false})
    : _uuids = uuids,
      _invalidUUIDs = invalidUUIDs,
      _isEmpty = isEmpty;

  /// Create success result with valid UUIDs
  factory _ParseResult.success(List<String> uuids) {
    return _ParseResult._(uuids: uuids);
  }

  /// Create result with invalid UUIDs
  factory _ParseResult.invalidUUIDs(List<String> invalids) {
    return _ParseResult._(invalidUUIDs: invalids);
  }

  /// Create empty result
  factory _ParseResult.empty() {
    return _ParseResult._(isEmpty: true);
  }

  /// Get valid UUIDs (only when isSuccess is true)
  List<String> get uuids {
    if (_uuids == null) {
      throw StateError('Cannot get uuids when result is not successful');
    }
    return _uuids;
  }

  /// Get invalid UUIDs (only when hasInvalidUUIDs is true)
  List<String> get invalidUUIDs {
    if (_invalidUUIDs == null) {
      throw StateError('Cannot get invalidUUIDs when result has no invalid UUIDs');
    }
    return _invalidUUIDs;
  }

  /// Check if parsing was successful
  bool get isSuccess => _uuids != null && _uuids.isNotEmpty;

  /// Check if there are invalid UUIDs
  bool get hasInvalidUUIDs => _invalidUUIDs != null && _invalidUUIDs.isNotEmpty;

  /// Check if input is empty
  bool get isEmpty => _isEmpty;
}
