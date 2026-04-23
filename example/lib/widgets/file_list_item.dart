import 'package:flutter/material.dart';

import 'package:jl_ota/constant/ble_event_constants.dart';
import '../extensions/hex_color.dart';
import 'marquee_widget.dart';

/// A list item widget for displaying file information.
class FileListItem extends StatelessWidget {
  final Map<String, String> file;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const FileListItem({super.key, required this.file, required this.isSelected, required this.onTap, required this.onLongPress});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      child: ListTile(
        tileColor: Colors.transparent,
        selectedTileColor: Colors.transparent,
        hoverColor: Colors.transparent,
        focusColor: Colors.transparent,
        splashColor: Colors.transparent,
        mouseCursor: SystemMouseCursors.click,
        visualDensity: VisualDensity.compact,
        leading: Image.asset('assets/images/ic_file.png', width: 28, height: 28),
        contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 0),
        title: SizedBox(
          height: 21,
          child: MarqueeWidget(
            direction: Axis.horizontal,
            child: Text(
              file[BleEventConstants.KEY_NAME]?.trim() ?? 'Unknown',
              style: TextStyle(color: HexColor.hexColor("#242424"), fontSize: 15, fontWeight: FontWeight.bold),
            ),
          ),
        ),
        subtitle: SizedBox(
          height: 17,
          child: MarqueeWidget(
            direction: Axis.horizontal,
            child: Text(file[BleEventConstants.KEY_PATH]?.trim() ?? 'Unknown', style: TextStyle(color: HexColor.hexColor("#B0B0B0"), fontSize: 12)),
          ),
        ),
        trailing: Image.asset(isSelected ? 'assets/images/ic_file_choose_sel.png' : 'assets/images/ic_file_choose_nol.png', width: 20, height: 20),
      ),
    );
  }
}
