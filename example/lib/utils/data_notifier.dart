import 'package:flutter/material.dart';

/// A notifier class to manage data updates.
class DataNotifier extends ChangeNotifier {
  Map<String, dynamic>? _otaData;

  Map<String, dynamic>? get otaData => _otaData;

  void setOtaData(Map<String, dynamic> otaData) {
    _otaData = otaData;
    notifyListeners();
  }
}
