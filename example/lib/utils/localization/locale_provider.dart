import 'package:flutter/material.dart';
import 'package:jl_ota_example/l10n/app_localizations.dart';

class LocaleProvider with ChangeNotifier {
  Locale? _locale = Locale("en", "US"); // Default locale

  Locale? get locale => _locale;

  void setLocale(Locale locale) {
    if (!AppLocalizations.supportedLocales.contains(locale)) return;

    _locale = locale;
    notifyListeners();
  }

  void clearLocale() {
    _locale = null;
    notifyListeners();
  }
}
