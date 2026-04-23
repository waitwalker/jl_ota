import 'package:flutter/material.dart';

/// A custom slider track shape that adds padding to both sides of the track
class CustomTrackShape extends RoundedRectSliderTrackShape {
  final double sidePadding;

  const CustomTrackShape({this.sidePadding = 0});

  @override
  Rect getPreferredRect({
    required RenderBox parentBox,
    Offset offset = Offset.zero,
    required SliderThemeData sliderTheme,
    bool isEnabled = false,
    bool isDiscrete = false,
  }) {
    final trackHeight = sliderTheme.trackHeight ?? 2;
    final trackLeft = offset.dx + sidePadding;
    final trackTop = offset.dy + (parentBox.size.height - trackHeight) / 2;
    final trackWidth = parentBox.size.width - sidePadding * 2;
    return Rect.fromLTWH(trackLeft, trackTop, trackWidth, trackHeight);
  }
}
