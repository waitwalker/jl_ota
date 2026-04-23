import 'package:flutter/material.dart';

import 'package:jl_ota/constant/constants.dart';
import '../l10n/app_localizations.dart';
import '../utils/share_preference.dart';
import '../widgets/device_filter_widget.dart';

/// A dialog for setting device filter criteria
class DeviceFilterDialog extends StatefulWidget {
  final String filterContent;
  final Function(String) onFilterChanged;

  const DeviceFilterDialog({super.key, required this.filterContent, required this.onFilterChanged});

  @override
  State<DeviceFilterDialog> createState() => _DeviceFilterDialogState();
}

class _DeviceFilterDialogState extends State<DeviceFilterDialog> {
  late TextEditingController _controller;
  late FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.filterContent);
    _focusNode = FocusNode();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(FilterConstants.borderRadius)),
      child: Material(
        borderRadius: BorderRadius.circular(FilterConstants.borderRadius),
        color: FilterConstants.backgroundColor,
        child: Container(
          padding: const EdgeInsets.only(top: FilterConstants.topPadding),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [_buildTitle(context), _buildTextField(context), _buildDivider(), _buildButtons(context)],
          ),
        ),
      ),
    );
  }

  Widget _buildTitle(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(left: 24.0),
      child: Align(alignment: Alignment.centerLeft, child: FilterTitle()),
    );
  }

  Widget _buildTextField(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(top: FilterConstants.verticalPadding, bottom: FilterConstants.bottomPadding),
      child: Center(
        child: SizedBox(
          width: double.infinity,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: FilterConstants.horizontalPadding),
            child: FilterTextField(controller: _controller, focusNode: _focusNode),
          ),
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Container(color: FilterConstants.dividerColor, height: FilterConstants.dividerHeight);
  }

  Widget _buildButtons(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        FilterCancelButton(onPressed: () => {if (context.mounted) Navigator.pop(context)}),
        Container(width: FilterConstants.dividerHeight, height: FilterConstants.buttonDividerHeight, color: FilterConstants.dividerColor),
        FilterConfirmButton(
          onPressed: () {
            if (mounted) {
              widget.onFilterChanged(_controller.text);
              FilePreferenceManager.saveFilterContent(_controller.text);
              Navigator.pop(context);
            }
          },
        ),
      ],
    );
  }
}

/// Title widget for the filter dialog
class FilterTitle extends StatelessWidget {
  const FilterTitle({super.key});

  @override
  Widget build(BuildContext context) {
    return Text(
      AppLocalizations.of(context)!.filter,
      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: FilterConstants.textColor, fontFamily: FilterConstants.fontFamily),
    );
  }
}

/// Text field for filter input
class FilterTextField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;

  const FilterTextField({super.key, required this.controller, required this.focusNode});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      cursorColor: FilterConstants.cursorColor,
      focusNode: focusNode,
      autofocus: true,
      style: const TextStyle(fontSize: 15, color: Colors.black, fontStyle: FontStyle.normal, fontFamily: 'PingFang SC'),
      decoration: InputDecoration(
        contentPadding: const EdgeInsets.symmetric(horizontal: FilterConstants.textFieldPadding, vertical: FilterConstants.textFieldVerticalPadding),
        suffixIcon: IconButton(
          icon: Image.asset('assets/images/icon_delete.png', width: FilterConstants.iconSize, height: FilterConstants.iconSize),
          onPressed: () {
            controller.clear();
          },
        ),
        filled: true,
        fillColor: FilterConstants.textFieldColor,
        hintText: AppLocalizations.of(context)!.pleaseSetFilter,
        border: InputBorder.none,
      ),
    );
  }
}

/// Cancel button for filter dialog
class FilterCancelButton extends StatelessWidget {
  final VoidCallback onPressed;

  const FilterCancelButton({super.key, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onPressed,
        splashColor: Colors.transparent, // 去除水波纹效果
        highlightColor: Colors.transparent, // 去除高亮效果
        child: Container(
          height: AppConstants.dialogButtonHeight,
          alignment: Alignment.center,
          child: Text(
            AppLocalizations.of(context)!.cancel,
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: FilterConstants.textColor, fontFamily: FilterConstants.fontFamily),
          ),
        ),
      ),
    );
  }
}

/// Confirm button for filter dialog
class FilterConfirmButton extends StatelessWidget {
  final VoidCallback onPressed;

  const FilterConfirmButton({super.key, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onPressed,
        splashColor: Colors.transparent, // 去除水波纹效果
        highlightColor: Colors.transparent, // 去除高亮效果
        child: Container(
          height: AppConstants.dialogButtonHeight,
          alignment: Alignment.center,
          child: Text(
            AppLocalizations.of(context)!.confirm,
            style: TextStyle(color: FilterConstants.confirmButtonColor, fontSize: 15, fontWeight: FontWeight.bold, fontFamily: 'PingFang SC'),
          ),
        ),
      ),
    );
  }
}
