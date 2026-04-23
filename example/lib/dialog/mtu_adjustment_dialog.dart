import 'package:flutter/material.dart';
import 'package:jl_ota/constant/constants.dart';
import '../extensions/hex_color.dart';
import '../l10n/app_localizations.dart';
import '../widgets/indicator_seek_bar.dart';

/// Constants for styling and layout
class MtuDialogConstants {
  static const double borderRadius = 12.0;
  static const double topPadding = 36.0;
  static const double bottomPadding = 19.0;
  static const double trackMarginTop = 28.0;
  static const double horizontalPadding = 24.0;
  static const double minMaxLabelTopMargin = 13.0;
  static const double thumbWidth = 12.0;
  static const double thumbHeight = 32.0;
  static const double bubbleWidth = 40.0;
  static const double bubbleHeight = 30.0;
  static const double minMaxLabelFontSize = 12.0;
  static const double buttonFontSize = 15.0;
  static const double titleFontSize = 16.0;

  static const String fontFamily = 'PingFangSC';

  static final Color titleColor = HexColor.hexColor('#242424');
  static final Color minMaxLabelColor = HexColor.hexColor('#4B4B4B');
  static final Color cancelButtonColor = HexColor.hexColor('#B0B0B0');
  static final Color confirmButtonColor = HexColor.hexColor('#398BFF');
  static final Color dividerColor = HexColor.hexColor('#F5F5F5');
  static final Color activeTrackColor = Color(0xFF398BFF);
  static final Color inactiveTrackColor = Color(0xFFD8D8D8);
}

/// A reusable dialog component for MTU adjustment with min/max range
class MtuAdjustmentDialog extends StatefulWidget {
  final Function(int)? onMtuSelected;
  final int currentMtu;
  final int minMtu;
  final int maxMtu;

  const MtuAdjustmentDialog({super.key, this.onMtuSelected, required this.currentMtu, required this.minMtu, required this.maxMtu});

  @override
  State<MtuAdjustmentDialog> createState() => _MtuAdjustmentDialogState();
}

class _MtuAdjustmentDialogState extends State<MtuAdjustmentDialog> {
  late double _value;

  @override
  void initState() {
    super.initState();
    _value = widget.currentMtu.clamp(widget.minMtu, widget.maxMtu).toDouble();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(MtuDialogConstants.borderRadius)),
      child: Material(
        borderRadius: BorderRadius.circular(MtuDialogConstants.borderRadius),
        color: Colors.white,
        child: Container(
          padding: const EdgeInsets.only(top: MtuDialogConstants.topPadding),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Title
              _buildTitle(context),
              // Slider
              _buildSlider(),
              // Min/Max labels
              _buildMinMaxLabels(),
              // Divider
              _buildDivider(),
              // Buttons
              _buildButtons(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTitle(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: MtuDialogConstants.bottomPadding),
      child: Text(
        AppLocalizations.of(context)!.adjustMtu,
        style: TextStyle(
          fontSize: MtuDialogConstants.titleFontSize,
          fontWeight: FontWeight.bold,
          color: MtuDialogConstants.titleColor,
          fontFamily: MtuDialogConstants.fontFamily,
        ),
      ),
    );
  }

  Widget _buildSlider() {
    return Container(
      margin: const EdgeInsets.only(top: MtuDialogConstants.trackMarginTop),
      padding: const EdgeInsets.symmetric(horizontal: 0.0),
      child: IndicatorSeekBar(
        value: _value,
        min: widget.minMtu.toDouble(),
        max: widget.maxMtu.toDouble(),
        bubbleAsset: 'assets/images/custom_bubble.png',
        bubbleWidth: MtuDialogConstants.bubbleWidth,
        bubbleHeight: MtuDialogConstants.bubbleHeight,
        activeTrackColor: MtuDialogConstants.activeTrackColor,
        inactiveTrackColor: MtuDialogConstants.inactiveTrackColor,
        thumbAsset: 'assets/images/custom_slider.png',
        thumbWidth: MtuDialogConstants.thumbWidth,
        thumbHeight: MtuDialogConstants.thumbHeight,
        onChanged: (value) {
          setState(() {
            _value = value;
          });
        },
      ),
    );
  }

  Widget _buildMinMaxLabels() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: MtuDialogConstants.horizontalPadding),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '${widget.minMtu}',
            style: TextStyle(
              fontSize: MtuDialogConstants.minMaxLabelFontSize,
              color: MtuDialogConstants.minMaxLabelColor,
              fontFamily: MtuDialogConstants.fontFamily,
            ),
          ),
          Text(
            '${widget.maxMtu}',
            style: TextStyle(
              fontSize: MtuDialogConstants.minMaxLabelFontSize,
              color: MtuDialogConstants.minMaxLabelColor,
              fontFamily: MtuDialogConstants.fontFamily,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Container(
      color: MtuDialogConstants.dividerColor,
      height: 1,
      margin: const EdgeInsets.only(top: MtuDialogConstants.minMaxLabelTopMargin),
    );
  }

  Widget _buildButtons(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        // Cancel button
        Expanded(
          child: InkWell(
            // 移除水波纹效果
            splashColor: Colors.transparent,
            highlightColor: Colors.transparent,
            onTap: () => Navigator.pop(context),
            child: Container(
              height: AppConstants.dialogButtonHeight,
              alignment: Alignment.center,
              child: Text(
                AppLocalizations.of(context)!.cancel,
                style: TextStyle(
                  fontSize: MtuDialogConstants.buttonFontSize,
                  fontWeight: FontWeight.bold,
                  color: MtuDialogConstants.cancelButtonColor,
                  fontFamily: MtuDialogConstants.fontFamily,
                ),
              ),
            ),
          ),
        ),

        // Divider
        Container(width: 1, height: AppConstants.dialogButtonHeight, color: MtuDialogConstants.dividerColor),

        // Confirm button
        Expanded(
          child: InkWell(
            // 移除水波纹效果
            splashColor: Colors.transparent,
            highlightColor: Colors.transparent,
            onTap: () {
              Navigator.pop(context);
              widget.onMtuSelected?.call(_value.round());
            },
            child: Container(
              height: AppConstants.dialogButtonHeight,
              alignment: Alignment.center,
              child: Text(
                AppLocalizations.of(context)!.confirm,
                style: TextStyle(
                  color: MtuDialogConstants.confirmButtonColor,
                  fontSize: MtuDialogConstants.buttonFontSize,
                  fontWeight: FontWeight.bold,
                  fontFamily: MtuDialogConstants.fontFamily,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
