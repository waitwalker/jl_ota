import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class SettingStyles {
  static const double itemHeight = 48.0;
  static const double horizontalPadding = 20.0;
  static const double iconSize = 24.0;
  static const double sectionTitleLeftPadding = 12.0;
  static const double sectionTitleTopPadding = 12.0;
  static const double sectionTitleFontSize = 13.0;
  static const double contentFontSize = 15.0;
  static const double sectionBorderRadius = 8.0;
  static const double sectionTopMargin = 8.0;

  static const Color textColor = Color(0xFF242424);
  static const Color sectionTitleColor = Color(0xFF6F6F6F);
  static const Color switchActiveColor = Color(0xFF628DFF);
  static const Color backgroundColor = Colors.white;

  static const FontWeight fontWeight = FontWeight.bold;

  static const String selectedIconPath = 'assets/images/ic_device_choose.png';
}

/// Settings Row Component with Switch
///
/// Used to display a setting item with a title and switch control,
/// typically for boolean-type configuration options.
/// Provides a unified visual style and interactive experience.
class SettingSwitchRow extends StatelessWidget {
  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;

  const SettingSwitchRow({super.key, required this.title, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: SettingStyles.itemHeight,
      padding: const EdgeInsets.symmetric(horizontal: SettingStyles.horizontalPadding),
      decoration: const BoxDecoration(color: SettingStyles.backgroundColor),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(color: SettingStyles.textColor, fontSize: SettingStyles.contentFontSize, fontWeight: SettingStyles.fontWeight),
          ),
          CupertinoSwitch(value: value, onChanged: onChanged, activeTrackColor: SettingStyles.switchActiveColor),
        ],
      ),
    );
  }
}

/// Communication option selection item
class CommunicationOption extends StatelessWidget {
  final String title;
  final bool isSelected;
  final VoidCallback onTap;

  const CommunicationOption({super.key, required this.title, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        height: SettingStyles.itemHeight,
        padding: const EdgeInsets.symmetric(horizontal: SettingStyles.horizontalPadding),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: const TextStyle(color: SettingStyles.textColor, fontSize: SettingStyles.contentFontSize, fontWeight: SettingStyles.fontWeight),
            ),
            if (isSelected) Image.asset(SettingStyles.selectedIconPath, width: SettingStyles.iconSize, height: SettingStyles.iconSize),
          ],
        ),
      ),
    );
  }
}

/// Settings section container
class SettingSection extends StatelessWidget {
  final String? title;
  final List<Widget> children;
  final EdgeInsetsGeometry margin;

  const SettingSection({super.key, this.title, required this.children, this.margin = const EdgeInsets.only(top: SettingStyles.sectionTopMargin)});

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [if (title != null) _buildSectionTitle(), _buildSectionContent()]);
  }

  Widget _buildSectionTitle() {
    return Padding(
      padding: const EdgeInsets.only(left: SettingStyles.sectionTitleLeftPadding, top: SettingStyles.sectionTitleTopPadding),
      child: Text(
        title!,
        style: TextStyle(color: SettingStyles.sectionTitleColor, fontSize: SettingStyles.sectionTitleFontSize),
      ),
    );
  }

  Widget _buildSectionContent() {
    return Container(
      margin: margin,
      decoration: title != null
          ? BoxDecoration(color: SettingStyles.backgroundColor, borderRadius: BorderRadius.circular(SettingStyles.sectionBorderRadius))
          : const BoxDecoration(color: SettingStyles.backgroundColor),
      child: Column(children: children),
    );
  }
}
