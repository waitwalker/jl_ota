import 'package:flutter/material.dart';
import 'package:jl_ota/constant/ble_event_constants.dart';

import '../data/popup_menu_manager.dart';
import 'file_list_item.dart';

/// A scrollable list view widget for displaying OTA files.
class OtaFileListView extends StatelessWidget {
  final List<Map<String, String>> otaFileList;
  final String? selectedFilePath;
  final Function(String?) onFileSelected;
  final Function(BuildContext, Map<String, String>, GlobalKey, int) onFileLongPressed;
  final PopupMenuManager popupMenuManager;
  final Function(Map<String, String>, int) onDeleteFile;

  const OtaFileListView({
    super.key,
    required this.otaFileList,
    required this.selectedFilePath,
    required this.onFileSelected,
    required this.onFileLongPressed,
    required this.popupMenuManager,
    required this.onDeleteFile,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(height: 270, child: ListView(children: _buildFileListTiles(context)));
  }

  List<Widget> _buildFileListTiles(BuildContext context) {
    final List<Widget> widgets = [];

    for (int i = 0; i < otaFileList.length; i++) {
      final file = otaFileList[i];
      final GlobalKey itemKey = GlobalKey();
      final isSelected = selectedFilePath == file[BleEventConstants.KEY_PATH];

      widgets.add(
        Material(
          color: Colors.transparent,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: FileListItem(
              key: itemKey,
              file: file,
              isSelected: isSelected,
              onTap: () {
                if (isSelected) {
                  onFileSelected(null);
                } else {
                  onFileSelected(file[BleEventConstants.KEY_PATH]);
                }
              },
              onLongPress: () => onFileLongPressed(context, file, itemKey, i),
            ),
          ),
        ),
      );

      //if (i < otaFileList.length - 1) {
      widgets.add(const Divider(height: 1, thickness: 1, indent: 21, color: Color(0x0D000000)));
      //}
    }

    return widgets;
  }
}
