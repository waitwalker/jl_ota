import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../widgets/file_select_popup_menu.dart';

/// Manages the display and behavior of custom popup menus in the application.
class PopupMenuManager {
  static const double _popupMenuWidth = 120;
  static const double _popupMenuItemHeight = 48;
  static const double _popupMenuElevation = 8;
  static const double _popupMenuBorderRadius = 8;
  static const double _horizontalSpacing = 8;
  static const double _iconSize = 28;

  OverlayEntry? _longClickOverlayEntry;
  OverlayEntry? _addFileOverlayEntry;

  void removeAddFilePopupMenu() {
    _addFileOverlayEntry?.remove();
    _addFileOverlayEntry = null;
  }

  void removeLongClickPopupMenu() {
    _longClickOverlayEntry?.remove();
    _longClickOverlayEntry = null;
  }

  void showLongClickPopupMenu({
    required BuildContext context,
    required Map<String, String> file,
    required GlobalKey itemKey,
    required int index,
    required Function onDelete,
  }) {
    removeLongClickPopupMenu();

    final renderBox = itemKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final offset = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;

    final screenSize = MediaQuery.of(context).size;
    double popupLeft = offset.dx + size.width;
    double popupTop = offset.dy + size.height / 2;

    // Adjust vertical position if needed
    if (popupTop + _popupMenuItemHeight > screenSize.height) {
      popupTop = offset.dy - _popupMenuItemHeight;
    }

    // Adjust horizontal position if needed
    if (popupLeft + _popupMenuWidth > screenSize.width) {
      popupLeft = screenSize.width - _popupMenuWidth - 16;
    }

    _longClickOverlayEntry = OverlayEntry(builder: (context) => _buildLongClickOverlay(context, popupLeft, popupTop, file, index, onDelete));

    Overlay.of(context).insert(_longClickOverlayEntry!);
  }

  Widget _buildLongClickOverlay(BuildContext context, double left, double top, Map<String, String> file, int index, Function onDelete) {
    return Stack(
      children: [
        // Background dismiss layer
        GestureDetector(
          onTap: removeLongClickPopupMenu,
          behavior: HitTestBehavior.opaque,
          child: Container(color: Colors.transparent),
        ),
        // Popup menu
        Positioned(
          left: left,
          top: top,
          child: Material(
            elevation: _popupMenuElevation,
            borderRadius: BorderRadius.circular(_popupMenuBorderRadius),
            child: Container(
              width: _popupMenuWidth,
              decoration: BoxDecoration(color: const Color(0xFF4E4E4E), borderRadius: BorderRadius.circular(_popupMenuBorderRadius)),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  InkWell(
                    onTap: () {
                      removeLongClickPopupMenu();
                      onDelete(file, index);
                    },
                    child: Container(
                      height: _popupMenuItemHeight,
                      padding: const EdgeInsets.symmetric(horizontal: _horizontalSpacing),
                      child: Row(
                        children: [
                          Image.asset('assets/images/ic_delete_white.png', width: _iconSize, height: _iconSize),
                          const SizedBox(width: _horizontalSpacing),
                          Text(AppLocalizations.of(context)!.delete, style: const TextStyle(color: Colors.white)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  void showAddFilePopupMenu({
    required BuildContext context,
    required GlobalKey buttonKey,
    required Function onLocalAdd,
    required Function onComputerTransfer,
    required Function onScanDownload,
  }) {
    removeAddFilePopupMenu();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final renderBox = buttonKey.currentContext?.findRenderObject() as RenderBox?;
      if (renderBox == null) return;

      final offset = renderBox.localToGlobal(Offset.zero);
      final size = renderBox.size;

      _addFileOverlayEntry = OverlayEntry(
        builder: (context) => _buildAddFileOverlay(
          context,
          offset.dx + size.width - 110,
          offset.dy + size.height - 7,
          onLocalAdd: onLocalAdd,
          onComputerTransfer: onComputerTransfer,
          onScanDownload: onScanDownload,
        ),
      );

      Overlay.of(context).insert(_addFileOverlayEntry!);
    });
  }

  Widget _buildAddFileOverlay(
    BuildContext context,
    double left,
    double top, {
    required Function onLocalAdd,
    required Function onComputerTransfer,
    required Function onScanDownload,
  }) {
    return Stack(
      children: [
        // Background dismiss layer
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: removeAddFilePopupMenu,
          child: Container(color: Colors.transparent),
        ),
        // Popup menu
        Positioned(
          left: left,
          top: top,
          child: Material(
            color: Colors.transparent,
            child: FileSelectPopupMenu(
              onLocalAdd: () => _handleMenuAction(onLocalAdd),
              onComputerTransfer: () => _handleMenuAction(onComputerTransfer),
              onScanDownload: () => _handleMenuAction(onScanDownload),
            ),
          ),
        ),
      ],
    );
  }

  /// Handles menu actions by first removing the file popup menu and then executing the provided action.
  void _handleMenuAction(Function action) {
    removeAddFilePopupMenu();
    action();
  }
}
