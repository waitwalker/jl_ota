import 'package:flutter/material.dart';
import 'package:jl_ota/model/scan_device.dart';

import '../extensions/hex_color.dart';

/// A list item widget for displaying and connecting to a scanned device
class ConnectListItem extends StatelessWidget {
  final ScanDevice device;
  final Function(ScanDevice) onTap;
  static const Color doneIconColor = Color(0xFF398BFF); // 可以直接使用 Color ARGB
  const ConnectListItem({required this.device, required this.onTap, super.key});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      child: InkWell(
        onTap: () => onTap(device),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                children: [
                  // 左侧文字
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          device.name,
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: HexColor.hexColor("#242424")),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          device.description,
                          style: TextStyle(fontSize: 12, fontFamily: "PingFang SC", color: HexColor.hexColor("#B0B0B0")),
                        ),
                      ],
                    ),
                  ),
                  // 右侧图标
                  device.isOnline ? Image.asset('assets/images/ic_device_choose.png', width: 24, height: 24) : Container(),
                ],
              ),
            ),
            // 底部分隔线
            Divider(height: 1, thickness: 1, indent: 20, endIndent: 0, color: const Color(0x0D000000)),
          ],
        ),
      ),
    );
  }
}
