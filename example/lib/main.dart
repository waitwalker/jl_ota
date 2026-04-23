import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:jl_ota_example/utils/data_notifier.dart';
import 'package:jl_ota_example/pages/welcome_page.dart';
import 'package:provider/provider.dart';
import './extensions/hex_color.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:jl_ota_example/l10n/app_localizations.dart';

/// Main entry point of the application
/// Initializes the app with necessary providers and configurations
void main() async {
  // Ensure that the Flutter binding is initialized.
  WidgetsFlutterBinding.ensureInitialized();

  // Set the orientation to portrait
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]).then((_) {
    runApp(ChangeNotifierProvider(create: (context) => DataNotifier(), child: MyApp()));
  });
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      localizationsDelegates: [
        ...AppLocalizations.localizationsDelegates,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      localeResolutionCallback: (locale, supportedLocales) {
        for (var supportedLocale in supportedLocales) {
          if (supportedLocale.languageCode == locale?.languageCode) {
            return supportedLocale;
          }
        }
        return supportedLocales.first;
      },
      theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: HexColor.hexColor('#FF398BFF'))),
      routes: {"/": (context) => WelcomePage()},
    );
  }
}
