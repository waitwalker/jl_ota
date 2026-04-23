import 'package:flutter/material.dart';

import 'custom_thumb_shape.dart';
import 'custom_track_shape.dart';

/// Custom SeekBar with an always-visible indicator bubble that follows the thumb
class IndicatorSeekBar extends StatefulWidget {
  final double value;
  final double min;
  final double max;
  final ValueChanged<double>? onChanged;
  final ValueChanged<double>? onChangeEnd;
  final String bubbleAsset;
  final String thumbAsset;
  final double bubbleWidth;
  final double bubbleHeight;
  final double thumbWidth;
  final double thumbHeight;
  final Color activeTrackColor;
  final Color inactiveTrackColor;
  final double sidePadding;

  const IndicatorSeekBar({
    super.key,
    required this.value,
    this.min = 0,
    this.max = 100,
    this.onChanged,
    this.onChangeEnd,
    this.bubbleAsset = 'assets/images/custom_bubble.png',
    this.thumbAsset = 'assets/images/custom_thumb.png',
    this.bubbleWidth = 40,
    this.bubbleHeight = 40,
    this.thumbWidth = 20,
    this.thumbHeight = 20,
    this.activeTrackColor = Colors.blue,
    this.inactiveTrackColor = Colors.grey,
    this.sidePadding = 24,
  });

  @override
  IndicatorSeekBarState createState() => IndicatorSeekBarState();
}

class IndicatorSeekBarState extends State<IndicatorSeekBar> {
  final GlobalKey _sliderKey = GlobalKey();
  late final CustomThumbShape _thumbShape;
  OverlayEntry? _overlayEntry;
  double _currentValue = 0;
  bool _isDragging = false;

  @override
  void initState() {
    super.initState();
    _thumbShape = CustomThumbShape(thumbAsset: widget.thumbAsset, thumbWidth: widget.thumbWidth, thumbHeight: widget.thumbHeight);
    _currentValue = widget.value;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showOverlay();
    });
  }

  @override
  void dispose() {
    _thumbShape.dispose();
    _hideOverlay();
    super.dispose();
  }

  @override
  void didUpdateWidget(IndicatorSeekBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_isDragging && widget.value != _currentValue) {
      _currentValue = widget.value;
      _updateOverlay(_currentValue);
    }
  }

  void _updateOverlay(double value) {
    _currentValue = value;
    if (_overlayEntry == null) {
      _showOverlay();
    } else {
      _overlayEntry!.markNeedsBuild();
    }
  }

  void _showOverlay() {
    final renderBox = _sliderKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    _hideOverlay();

    _overlayEntry = OverlayEntry(
      builder: (context) {
        final renderBox = _sliderKey.currentContext?.findRenderObject() as RenderBox?;
        if (renderBox == null) return Container();

        final position = renderBox.localToGlobal(Offset.zero);
        final width = renderBox.size.width - widget.sidePadding * 2;
        final thumbOffset = widget.sidePadding + ((_currentValue - widget.min) / (widget.max - widget.min) * width);

        return Positioned(
          left: position.dx + thumbOffset - (widget.bubbleWidth / 2),
          top: position.dy - widget.bubbleHeight - 2,
          child: Material(
            color: Colors.transparent,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Image.asset(widget.bubbleAsset, width: widget.bubbleWidth, height: widget.bubbleHeight, fit: BoxFit.contain),
                Positioned(
                  top: 1,
                  child: Text(
                    _currentValue.toStringAsFixed(0),
                    style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  void _hideOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 0),
      child: SliderTheme(
        data: SliderTheme.of(context).copyWith(
          trackHeight: 2,
          thumbShape: _thumbShape,
          overlayShape: const RoundSliderOverlayShape(overlayRadius: 0),
          activeTrackColor: widget.activeTrackColor,
          inactiveTrackColor: widget.inactiveTrackColor,
          trackShape: CustomTrackShape(sidePadding: widget.sidePadding),
        ),
        child: Slider(
          key: _sliderKey,
          value: _currentValue,
          min: widget.min,
          max: widget.max,
          onChanged: (value) {
            setState(() {
              _isDragging = true;
              _currentValue = value;
            });
            _updateOverlay(value);
            widget.onChanged?.call(value);
          },
          onChangeStart: (value) {
            _isDragging = true;
          },
          onChangeEnd: (value) {
            _isDragging = false;
            widget.onChangeEnd?.call(value);
          },
        ),
      ),
    );
  }
}
