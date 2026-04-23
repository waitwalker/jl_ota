import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:jl_ota_example/extensions/hex_color.dart';

/// Settings Row Component with Switch
///
/// Used to display a setting item with a title and switch control, typically for boolean-type configuration options.
/// Provides a unified visual style and interactive experience.
class SettingSwitchRow extends StatelessWidget {
  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;

  const SettingSwitchRow({super.key, required this.title, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      decoration: const BoxDecoration(color: Colors.white),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(color: Color(0xFF242424), fontSize: 15, fontWeight: FontWeight.bold),
          ),
          CupertinoSwitch(value: value, onChanged: onChanged, activeTrackColor: Color(0xFF628DFF)),
        ],
      ),
    );
  }
}

/// 通信方式选择项
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
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: const TextStyle(color: Color(0xFF242424), fontSize: 15, fontWeight: FontWeight.bold),
            ),
            if (isSelected) Image.asset('assets/images/ic_device_choose.png', width: 24, height: 24),
          ],
        ),
      ),
    );
  }
}

/// 设置分组容器
class SettingSection extends StatelessWidget {
  final String? title;
  final List<Widget> children;
  final EdgeInsetsGeometry margin;

  const SettingSection({super.key, this.title, required this.children, this.margin = const EdgeInsets.only(top: 8)});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null)
          Padding(
            padding: const EdgeInsets.only(left: 12, top: 12),
            child: Text(title!, style: TextStyle(color: HexColor.hexColor("#6F6F6F"), fontSize: 13)),
          ),
        Container(
          margin: margin,
          decoration: title != null
              ? BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8))
              : const BoxDecoration(color: Colors.white),
          child: Column(children: children),
        ),
      ],
    );
  }
}
