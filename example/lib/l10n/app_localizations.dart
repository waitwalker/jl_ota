import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ja.dart';
import 'app_localizations_ko.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale) : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates = <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[Locale('en'), Locale('ja'), Locale('ko'), Locale('zh')];

  /// App name
  ///
  /// In en, this message translates to:
  /// **'Jieli OTA'**
  String get appName;

  /// Devices
  ///
  /// In en, this message translates to:
  /// **'Devices'**
  String get devices;

  /// Update
  ///
  /// In en, this message translates to:
  /// **'Update'**
  String get update;

  /// Setting
  ///
  /// In en, this message translates to:
  /// **'Setting'**
  String get settings;

  /// Current Language
  ///
  /// In en, this message translates to:
  /// **'Current Language is {language} '**
  String currentLanguage(String language);

  /// Connect
  ///
  /// In en, this message translates to:
  /// **'Connect'**
  String get connect;

  /// Disconnect
  ///
  /// In en, this message translates to:
  /// **'Disconnect'**
  String get disconnect;

  /// Filter
  ///
  /// In en, this message translates to:
  /// **'Filter name'**
  String get filter;

  /// Device List
  ///
  /// In en, this message translates to:
  /// **'Device List'**
  String get deviceList;

  /// Cancel
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// Confirm
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get confirm;

  /// Please set filter
  ///
  /// In en, this message translates to:
  /// **'Please set filter'**
  String get pleaseSetFilter;

  /// Copyright
  ///
  /// In en, this message translates to:
  /// **'Copyright @2021–2025 Zhuhai Jieli Technology co., LTD All Rights Reserved'**
  String get copyRight;

  /// Company name
  ///
  /// In en, this message translates to:
  /// **'Zhuhai Jieli Technology co., LTD'**
  String get companyName;

  /// Title for privacy policy dialog
  ///
  /// In en, this message translates to:
  /// **'User Agreement And Privacy Policy'**
  String get privacyPolicyDialogTitle;

  /// Welcome message first text
  ///
  /// In en, this message translates to:
  /// **'　Welcome to Jieli OTA Update!\n　We take your privacy and personal information protection very seriously. Before using the \"Jieli OTA Update\" service, please read carefully'**
  String get welcomeMessage;

  /// User Agreement text
  ///
  /// In en, this message translates to:
  /// **'User Agreement'**
  String get userAgreement;

  /// And text
  ///
  /// In en, this message translates to:
  /// **'and'**
  String get and;

  /// PrivacyPolicy text
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get privacyPolicy;

  /// Agreement text with indentation
  ///
  /// In en, this message translates to:
  /// **', and fully understand the terms of the agreement.\n　If you agree and accept this notice and the relevant agreement content, please click Agree to start using our service.'**
  String get agreementText;

  /// AgreeButton button
  ///
  /// In en, this message translates to:
  /// **'Agree'**
  String get agreeButton;

  /// DisagreeButton button
  ///
  /// In en, this message translates to:
  /// **'Disagree and Exit'**
  String get disagreeButton;

  /// Connecting status
  ///
  /// In en, this message translates to:
  /// **'Connecting...'**
  String get btConnecting;

  /// Save button text
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// Displays the storage location of the log file
  ///
  /// In en, this message translates to:
  /// **'Log Location:'**
  String get logLocation;

  /// Title for device authentication option
  ///
  /// In en, this message translates to:
  /// **'Device authentication'**
  String get deviceAuthentication;

  /// Title for HID device option
  ///
  /// In en, this message translates to:
  /// **'HID device'**
  String get hidDevice;

  /// Title for custom reconnection method option
  ///
  /// In en, this message translates to:
  /// **'Custom Reconnection Method'**
  String get customReconnectMethod;

  /// Label indicating the current communication method
  ///
  /// In en, this message translates to:
  /// **'Current Communication Method'**
  String get currentCommunicationMethod;

  /// Communication way is ble option
  ///
  /// In en, this message translates to:
  /// **'BLE'**
  String get communicationWayBle;

  /// Communication way is spp option
  ///
  /// In en, this message translates to:
  /// **'SPP'**
  String get communicationWaySpp;

  /// Communication way is gatt option
  ///
  /// In en, this message translates to:
  /// **'GATT Over BR/EDR'**
  String get communicationWayGatt;

  /// Adjust the MTU size
  ///
  /// In en, this message translates to:
  /// **'Adjust MTU'**
  String get adjustMtu;

  /// Application log file
  ///
  /// In en, this message translates to:
  /// **'Log file'**
  String get logFile;

  /// Software version number
  ///
  /// In en, this message translates to:
  /// **'SDK version'**
  String get sdkVersion;

  /// Application information and description
  ///
  /// In en, this message translates to:
  /// **'About app'**
  String get aboutApp;

  /// Prompt message asking user to restart app after saving settings
  ///
  /// In en, this message translates to:
  /// **'Settings saved. Restart app to apply changes?'**
  String get saveAndRestartMessage;

  /// Restart the application
  ///
  /// In en, this message translates to:
  /// **'Restart'**
  String get restart;

  /// Message indicating that the settings failed to save
  ///
  /// In en, this message translates to:
  /// **'Failed to save settings'**
  String get failedToSaveSettings;

  /// Connect to the device using the Bluetooth functionality provided by the SDK
  ///
  /// In en, this message translates to:
  /// **'Connect using SDK Bluetooth'**
  String get connectUsingSdkBluetooth;

  /// Current app version description text
  ///
  /// In en, this message translates to:
  /// **'Current Version'**
  String get currentAppVersion;

  /// ICP registration information text
  ///
  /// In en, this message translates to:
  /// **'ICP Registration Information'**
  String get icpInfo;

  /// Delete all log files text
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete all log files?'**
  String get isDeleteAllLogFiles;

  /// Label for device connection status
  ///
  /// In en, this message translates to:
  /// **'Device status'**
  String get deviceStatus;

  /// Text for connected state
  ///
  /// In en, this message translates to:
  /// **'Connected'**
  String get connected;

  /// Text for disconnected state
  ///
  /// In en, this message translates to:
  /// **'Disconnected'**
  String get disconnected;

  /// Label for device category
  ///
  /// In en, this message translates to:
  /// **'Device Type'**
  String get deviceType;

  /// Label for unknown device type
  ///
  /// In en, this message translates to:
  /// **'Unknown Type'**
  String get unknownType;

  /// Label for classic Bluetooth devices
  ///
  /// In en, this message translates to:
  /// **'Classic Bluetooth'**
  String get classicBluetooth;

  /// Label for Bluetooth Low Energy devices
  ///
  /// In en, this message translates to:
  /// **'BLE Device'**
  String get bleDevice;

  /// Label for devices supporting both classic and BLE
  ///
  /// In en, this message translates to:
  /// **'Dual-Mode Bluetooth'**
  String get dualModeBluetooth;

  /// Label for file selection functionality
  ///
  /// In en, this message translates to:
  /// **'File selection'**
  String get fileSelection;

  /// Label for delete
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// Label for local add
  ///
  /// In en, this message translates to:
  /// **'Local add'**
  String get localAdd;

  /// Label for computer transfer
  ///
  /// In en, this message translates to:
  /// **'Computer transfer'**
  String get computerTransfer;

  /// Label for scan download
  ///
  /// In en, this message translates to:
  /// **'Scan to download'**
  String get scanDownload;

  /// Label for save file
  ///
  /// In en, this message translates to:
  /// **'Save file'**
  String get saveFile;

  /// Label for service started
  ///
  /// In en, this message translates to:
  /// **'Service started'**
  String get serviceStarted;

  /// Prompt to check network connection
  ///
  /// In en, this message translates to:
  /// **'Please ensure the device is connected to the same Wi-Fi or to this device\'s hotspot'**
  String get ensureConnection;

  /// Notification for successful copy operation with browser instruction
  ///
  /// In en, this message translates to:
  /// **'Copy successful, please open in the connected device\'s browser'**
  String get copySuccess;

  /// Label for collapse action
  ///
  /// In en, this message translates to:
  /// **'Collapse'**
  String get collapse;

  /// Label for copy address action
  ///
  /// In en, this message translates to:
  /// **'Copy address'**
  String get copyAddress;

  /// Label for selecting upgrade file
  ///
  /// In en, this message translates to:
  /// **'Please select upgrade file'**
  String get selectUpgradeFile;

  /// Tip for keeping Bluetooth and network enabled during upgrade process
  ///
  /// In en, this message translates to:
  /// **'(During the upgrade process, please keep Bluetooth and network enabled)'**
  String get upgradeProcessTip;

  /// Message indicating file verification is complete and reconnecting to device
  ///
  /// In en, this message translates to:
  /// **'File verification complete, reconnecting to device…'**
  String get fileVerificationComplete;

  /// Label prefix indicating reason or cause
  ///
  /// In en, this message translates to:
  /// **'Reason: %s'**
  String get reason;

  /// OTA upgrade completed
  ///
  /// In en, this message translates to:
  /// **'Upgrade completed'**
  String get otaComplete;

  /// OTA upgrade finished
  ///
  /// In en, this message translates to:
  /// **'Upgrade finished'**
  String get otaFinish;

  /// OTA upgrade in progress
  ///
  /// In en, this message translates to:
  /// **'Upgrading'**
  String get otaUpgrading;

  /// OTA upgrade cancelled
  ///
  /// In en, this message translates to:
  /// **'Upgrade cancelled'**
  String get otaUpgradeCancel;

  /// OTA upgrade not started
  ///
  /// In en, this message translates to:
  /// **'Upgrade not started'**
  String get otaUpgradeNotStarted;

  /// Checking upgrade file
  ///
  /// In en, this message translates to:
  /// **'Checking upgrade file'**
  String get otaCheckingUpgradeFile;

  /// OTA upgrade failed with reason
  ///
  /// In en, this message translates to:
  /// **'Upgrade failed: %s'**
  String get otaUpgradeFailed;

  /// Verifying file
  ///
  /// In en, this message translates to:
  /// **'Verifying file'**
  String get otaCheckFile;

  /// Update failed
  ///
  /// In en, this message translates to:
  /// **'Update failed'**
  String get updateFailed;

  /// Unknown error
  ///
  /// In en, this message translates to:
  /// **'Unknown error'**
  String get unknownError;

  /// Scan QR Code text
  ///
  /// In en, this message translates to:
  /// **'Scan QR Code'**
  String get scanQrcode;

  /// Photos text
  ///
  /// In en, this message translates to:
  /// **'Photos'**
  String get photos;

  /// Place the QR code/barcode inside the frame text
  ///
  /// In en, this message translates to:
  /// **'Place the QR code/barcode inside the frame'**
  String get qrcodeIntoBox;

  /// Unable to access photos due to system reasons text
  ///
  /// In en, this message translates to:
  /// **'Unable to access photos due to system reasons'**
  String get failPhotosSystemReason;

  /// Camera access is required to scan QR codes for downloading resources text
  ///
  /// In en, this message translates to:
  /// **'Camera access is required to scan QR codes for downloading resources'**
  String get accessCameraReason;

  /// Photo album access is required to scan QR codes for downloading resources text
  ///
  /// In en, this message translates to:
  /// **'Photo album access is required to scan QR codes for downloading resources'**
  String get accessPhotosReason;

  /// This feature requires your camera, please go to system settings to grant permission text
  ///
  /// In en, this message translates to:
  /// **'This feature requires your camera, please go to system settings to grant permission'**
  String get systemSetCamera;

  /// This feature requires your phone storage, please go to system settings to grant permission text
  ///
  /// In en, this message translates to:
  /// **'This feature requires your phone storage, please go to system settings to grant permission'**
  String get systemSetExternalStorage;

  /// Saving file text
  ///
  /// In en, this message translates to:
  /// **'Saving file. Please be patient...'**
  String get downloadSavePending;

  /// Downloading file text
  ///
  /// In en, this message translates to:
  /// **'Downloading file'**
  String get downloadingFile;

  /// Download successful text
  ///
  /// In en, this message translates to:
  /// **'Download successful'**
  String get downloadSuccessful;

  /// Download completed text
  ///
  /// In en, this message translates to:
  /// **'Download completed'**
  String get downloadCompleted;

  /// Refresh web text
  ///
  /// In en, this message translates to:
  /// **'Upload success, please refresh web page'**
  String get pleaseRefreshWeb;

  /// Double tap to exit app prompt
  ///
  /// In en, this message translates to:
  /// **'Press again to exit'**
  String get pressAgainToExit;

  /// Prompt when no QR code is detected
  ///
  /// In en, this message translates to:
  /// **'No QR code detected'**
  String get notFoundQRCode;

  /// Label for file sharing feature
  ///
  /// In en, this message translates to:
  /// **'File sharing'**
  String get fileShare;

  /// Title for sharing ufw file
  ///
  /// In en, this message translates to:
  /// **'Share ufw file'**
  String get shareUfwFile;

  /// Label for instructions for sharing ufw files from third-party apps
  ///
  /// In en, this message translates to:
  /// **'Instructions for sharing ufw files from third-party apps'**
  String get shareUfwFileTips;

  /// Label for device must be forced to upgrade
  ///
  /// In en, this message translates to:
  /// **'Device must be forced to upgrade'**
  String get deviceMustMandatoryUpgrade;

  /// Label for bluetooth disconnected
  ///
  /// In en, this message translates to:
  /// **'Bluetooth disconnected'**
  String get bluetoothDisconnected;

  /// Label for gatt uuid placeholder
  ///
  /// In en, this message translates to:
  /// **'Please enter one or more UUIDs, separated by commas or newlines'**
  String get gattUuidPlaceholder;

  /// Label for gatt service uuid
  ///
  /// In en, this message translates to:
  /// **'GATT Service UUID'**
  String get gattServiceUuid;

  /// Label for gatt uuid tips
  ///
  /// In en, this message translates to:
  /// **'Example: 180A, 0000180D-0000-1000-8000-00805F9B34FB'**
  String get gattUuidTips;

  /// Label for gatt uuid error empty
  ///
  /// In en, this message translates to:
  /// **'Please enter at least one UUID'**
  String get gattUuidErrorEmpty;

  /// Label for gatt uuid error empty
  ///
  /// In en, this message translates to:
  /// **'Invalid UUID format:\n%s'**
  String get gattUuidErrorInvalidFmt;

  /// Label for custom command
  ///
  /// In en, this message translates to:
  /// **'Custom command'**
  String get customCommand;

  /// Label for send custom command
  ///
  /// In en, this message translates to:
  /// **'Send custom command'**
  String get sendCustomCmd;

  /// Label for received data
  ///
  /// In en, this message translates to:
  /// **'Received data'**
  String get receivedData;

  /// Label for input data
  ///
  /// In en, this message translates to:
  /// **'Input data'**
  String get inputData;
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>['en', 'ja', 'ko', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'ja':
      return AppLocalizationsJa();
    case 'ko':
      return AppLocalizationsKo();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
