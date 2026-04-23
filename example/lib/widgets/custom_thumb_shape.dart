import 'package:flutter/material.dart';

/// A custom slider thumb shape that displays an image asset
class CustomThumbShape extends SliderComponentShape {
  final String thumbAsset;
  final double thumbWidth;
  final double thumbHeight;
  ImageStream? _imageStream;
  ImageStreamListener? _imageListener;
  ImageInfo? _cachedImage;

  CustomThumbShape({required this.thumbAsset, required this.thumbWidth, required this.thumbHeight});

  void dispose() {
    _removeImageListener();
    _cachedImage?.dispose();
    _cachedImage = null;
  }

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) {
    return Size(thumbWidth, thumbHeight);
  }

  void _removeImageListener() {
    if (_imageStream != null && _imageListener != null) {
      _imageStream!.removeListener(_imageListener!);
    }
    _imageListener = null;
    _imageStream = null;
  }

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    required bool isDiscrete,
    required TextPainter labelPainter,
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required TextDirection textDirection,
    required double value,
    required double textScaleFactor,
    required Size sizeWithOverflow,
  }) {
    final canvas = context.canvas;

    if (_cachedImage == null) {
      final image = AssetImage(thumbAsset);
      _removeImageListener();

      _imageStream = image.resolve(ImageConfiguration.empty);
      _imageListener = ImageStreamListener(
        (ImageInfo info, bool sync) {
          _cachedImage?.dispose();
          _cachedImage = info;

          WidgetsBinding.instance.addPostFrameCallback((_) {
            parentBox.markNeedsPaint();
          });
        },
        onError: (dynamic exception, StackTrace? stackTrace) {
          debugPrint('Failed to load thumb image: $exception');
        },
      );

      _imageStream!.addListener(_imageListener!);
    }

    if (_cachedImage != null) {
      _drawImage(canvas, center);
    }
  }

  void _drawImage(Canvas canvas, Offset center) {
    if (_cachedImage == null) return;

    final offset = Offset(center.dx - thumbWidth / 2, center.dy - thumbHeight / 2);

    canvas.drawImageRect(
      _cachedImage!.image,
      Rect.fromLTWH(0, 0, _cachedImage!.image.width.toDouble(), _cachedImage!.image.height.toDouble()),
      Rect.fromLTWH(offset.dx, offset.dy, thumbWidth, thumbHeight),
      Paint(),
    );
  }
}
