import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';

/// A separate widget for displaying download file content
class DownloadFileContent extends StatelessWidget {
  final int progress;
  final String fileName;

  // Define color constants
  static const Color darkTextColor = Color(0xFF242424);
  static const Color lightTextColor = Color(0xFF919191);
  static const Color progressBackgroundColor = Color(0xFFD8D8D8);
  static const Color progressValueColor = Color(0xFF398BFF);

  // Define text styles
  static const TextStyle boldDarkTextStyle = TextStyle(fontSize: 16, color: darkTextColor, fontWeight: FontWeight.bold, fontFamily: 'PingFangSC');

  static const TextStyle lightTextStyle = TextStyle(fontSize: 15, color: lightTextColor, fontFamily: 'PingFangSC');

  // Define spacing constants
  static const double topSpacing = 30.0;
  static const double horizontalSpacing = 20.0;
  static const double progressHorizontalSpacing = 28.0;
  static const double smallSpacing = 8.0;
  static const double mediumSpacing = 12.0;
  static const double bottomSpacing = 24.0;
  static const double progressHeight = 3.0;
  static const double progressBorderRadius = 1.5;

  const DownloadFileContent({super.key, required this.progress, required this.fileName});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;

    return Column(
      children: [
        SizedBox(height: topSpacing),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(loc.downloadingFile, style: boldDarkTextStyle),
            SizedBox(width: mediumSpacing),
            Text('$progress%', style: boldDarkTextStyle),
          ],
        ),
        SizedBox(height: smallSpacing),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: horizontalSpacing),
          child: Text(fileName, style: lightTextStyle, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis),
        ),
        SizedBox(height: bottomSpacing),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: progressHorizontalSpacing),
          child: LinearProgressIndicator(
            value: progress / 100,
            backgroundColor: progressBackgroundColor,
            valueColor: const AlwaysStoppedAnimation<Color>(progressValueColor),
            minHeight: progressHeight,
            borderRadius: BorderRadius.circular(progressBorderRadius),
          ),
        ),
      ],
    );
  }
}
