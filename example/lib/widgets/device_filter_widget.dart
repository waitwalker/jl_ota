import 'package:flutter/material.dart';
import 'package:jl_ota_example/extensions/hex_color.dart';
import 'package:jl_ota_example/l10n/app_localizations.dart';

import '../dialog/device_filter_dialog.dart';

/// Constants for styling and layout
class FilterConstants {
  static const double borderRadius = 12.0;
  static const double topPadding = 36.0;
  static const double horizontalPadding = 24.0;
  static const double verticalPadding = 26.0;
  static const double bottomPadding = 24.0;
  static const double dividerHeight = 1.0;
  static const double buttonDividerHeight = 45.0;
  static const double iconSize = 18.0;
  static const double arrowIconSize = 16.0;
  static const double filterHeight = 50.0;
  static const double textFieldPadding = 16.0;
  static const double textFieldVerticalPadding = 15.0;
  static const double spacing = 8.0;

  static const String fontFamily = 'PingFangSC';
  static const String mediumFontFamily = 'PingFangSC-Medium';

  static final Color backgroundColor = Colors.white;
  static final Color textColor = HexColor.hexColor('#242424');
  static final Color secondaryTextColor = HexColor.hexColor('#838383');
  static final Color dividerColor = HexColor.hexColor('#F5F5F5');
  static final Color textFieldColor = HexColor.hexColor('#EFEFEF');
  static final Color confirmButtonColor = HexColor.hexColor('#398BFF');
  static final Color cursorColor = Color.fromARGB(255, 10, 115, 202);
}

/// A widget that provides a filter input dialog for device filtering.
class DeviceFilterWidget extends StatelessWidget {
  final String filterContent;
  final Function(String) onFilterChanged;

  const DeviceFilterWidget({super.key, required this.filterContent, required this.onFilterChanged});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(onTap: () => _showFilterDialog(context), child: _buildFilterRow(context));
  }

  void _showFilterDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => DeviceFilterDialog(filterContent: filterContent, onFilterChanged: onFilterChanged),
    );
  }

  Widget _buildFilterRow(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(left: 20, right: 20),
      height: FilterConstants.filterHeight,
      color: FilterConstants.backgroundColor,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            AppLocalizations.of(context)!.filter,
            style: TextStyle(fontSize: 15, color: FilterConstants.textColor, fontWeight: FontWeight.bold),
          ),
          Row(
            children: [
              Text(
                filterContent,
                style: TextStyle(fontSize: 15, color: FilterConstants.secondaryTextColor, fontFamily: FilterConstants.mediumFontFamily),
              ),
              const SizedBox(width: FilterConstants.spacing),
              Image.asset(
                'assets/images/ic_arrow_right_gray.png',
                width: FilterConstants.arrowIconSize,
                height: FilterConstants.arrowIconSize,
                color: FilterConstants.secondaryTextColor,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
