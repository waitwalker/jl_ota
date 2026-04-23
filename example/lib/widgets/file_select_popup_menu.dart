import 'package:flutter/material.dart';
import 'package:jl_ota_example/utils/app_util.dart';
import 'package:jl_ota_example/widgets/triangle_painter_widget.dart';

import '../l10n/app_localizations.dart';
import 'file_select_menu_item.dart';

/// A popup menu widget for file selection options
class FileSelectPopupMenu extends StatelessWidget {
  final VoidCallback onLocalAdd;
  final VoidCallback onComputerTransfer;
  final VoidCallback onScanDownload;

  // Layout constants
  static const double triangleRightPosition = 16.0;
  static const double triangleWidth = 15.0;
  static const double triangleHeight = 8.0;
  static const double menuTopPadding = 10.0;
  static const double menuMinWidth = 120.0;
  static const double menuMaxWidth = 120.0;
  static const double menuBorderRadius = 8.0;
  static const Color menuBackgroundColor = Color(0xFF4E4E4E);

  const FileSelectPopupMenu({super.key, required this.onLocalAdd, required this.onComputerTransfer, required this.onScanDownload});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final isAndroid = AppUtil.isAndroid;

    return Stack(
      children: [
        // Triangle indicator
        Positioned(
          right: triangleRightPosition,
          top: 0,
          child: CustomPaint(
            painter: TrianglePainter(),
            child: const SizedBox(width: triangleWidth, height: triangleHeight),
          ),
        ),
        // Card menu
        Padding(
          padding: const EdgeInsets.only(top: menuTopPadding),
          child: Card(
            elevation: 4,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(menuBorderRadius)),
            color: menuBackgroundColor,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: menuMinWidth, maxWidth: menuMaxWidth),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FileSelectMenuItem(
                    iconPath: 'assets/images/icon_phone.png',
                    text: isAndroid ? loc.localAdd : loc.fileShare,
                    onTap: onLocalAdd,
                    showDivider: true,
                  ),
                  FileSelectMenuItem(
                    iconPath: 'assets/images/icon_computer.png',
                    text: loc.computerTransfer,
                    onTap: onComputerTransfer,
                    showDivider: true,
                  ),
                  FileSelectMenuItem(
                    iconPath: 'assets/images/ic_scan_download.png',
                    text: loc.scanDownload,
                    onTap: onScanDownload,
                    showDivider: false,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
