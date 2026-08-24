// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'Jieli OTA';

  @override
  String get devices => 'Devices';

  @override
  String get update => 'Update';

  @override
  String get settings => 'Setting';

  @override
  String currentLanguage(String language) {
    return 'Current Language is $language ';
  }

  @override
  String get connect => 'Connect';

  @override
  String get disconnect => 'Disconnect';

  @override
  String get filter => 'Filter name';

  @override
  String get deviceList => 'Device List';

  @override
  String get cancel => 'Cancel';

  @override
  String get confirm => 'Confirm';

  @override
  String get pleaseSetFilter => 'Please set filter';

  @override
  String get copyRight => 'Copyright @2021–2025 Zhuhai Jieli Technology co., LTD All Rights Reserved';

  @override
  String get companyName => 'Zhuhai Jieli Technology co., LTD';

  @override
  String get privacyPolicyDialogTitle => 'User Agreement And Privacy Policy';

  @override
  String get welcomeMessage =>
      '　Welcome to Jieli OTA Update!\n　We take your privacy and personal information protection very seriously. Before using the \"Jieli OTA Update\" service, please read carefully';

  @override
  String get userAgreement => 'User Agreement';

  @override
  String get and => 'and';

  @override
  String get privacyPolicy => 'Privacy Policy';

  @override
  String get agreementText =>
      ', and fully understand the terms of the agreement.\n　If you agree and accept this notice and the relevant agreement content, please click Agree to start using our service.';

  @override
  String get agreeButton => 'Agree';

  @override
  String get disagreeButton => 'Disagree and Exit';

  @override
  String get btConnecting => 'Connecting...';

  @override
  String get save => 'Save';

  @override
  String get logLocation => 'Log Location:';

  @override
  String get deviceAuthentication => 'Device authentication';

  @override
  String get hidDevice => 'HID device';

  @override
  String get customReconnectMethod => 'Custom Reconnection Method';

  @override
  String get currentCommunicationMethod => 'Current Communication Method';

  @override
  String get communicationWayBle => 'BLE';

  @override
  String get communicationWaySpp => 'SPP';

  @override
  String get communicationWayGatt => 'GATT Over BR/EDR';

  @override
  String get adjustMtu => 'Adjust MTU';

  @override
  String get logFile => 'Log file';

  @override
  String get sdkVersion => 'SDK version';

  @override
  String get aboutApp => 'About app';

  @override
  String get saveAndRestartMessage => 'Settings saved. Restart app to apply changes?';

  @override
  String get restart => 'Restart';

  @override
  String get failedToSaveSettings => 'Failed to save settings';

  @override
  String get connectUsingSdkBluetooth => 'Connect using SDK Bluetooth';

  @override
  String get currentAppVersion => 'Current Version';

  @override
  String get icpInfo => 'ICP Registration Information';

  @override
  String get isDeleteAllLogFiles => 'Are you sure you want to delete all log files?';

  @override
  String get deviceStatus => 'Device status';

  @override
  String get connected => 'Connected';

  @override
  String get disconnected => 'Disconnected';

  @override
  String get deviceType => 'Device Type';

  @override
  String get unknownType => 'Unknown Type';

  @override
  String get classicBluetooth => 'Classic Bluetooth';

  @override
  String get bleDevice => 'BLE Device';

  @override
  String get dualModeBluetooth => 'Dual-Mode Bluetooth';

  @override
  String get fileSelection => 'File selection';

  @override
  String get delete => 'Delete';

  @override
  String get localAdd => 'Local add';

  @override
  String get computerTransfer => 'Computer transfer';

  @override
  String get scanDownload => 'Scan to download';

  @override
  String get saveFile => 'Save file';

  @override
  String get serviceStarted => 'Service started';

  @override
  String get ensureConnection => 'Please ensure the device is connected to the same Wi-Fi or to this device\'s hotspot';

  @override
  String get copySuccess => 'Copy successful, please open in the connected device\'s browser';

  @override
  String get collapse => 'Collapse';

  @override
  String get copyAddress => 'Copy address';

  @override
  String get selectUpgradeFile => 'Please select upgrade file';

  @override
  String get upgradeProcessTip => '(During the upgrade process, please keep Bluetooth and network enabled)';

  @override
  String get fileVerificationComplete => 'File verification complete, reconnecting to device…';

  @override
  String get reason => 'Reason: %s';

  @override
  String get otaComplete => 'Upgrade completed';

  @override
  String get otaFinish => 'Upgrade finished';

  @override
  String get otaUpgrading => 'Upgrading';

  @override
  String get otaUpgradeCancel => 'Upgrade cancelled';

  @override
  String get otaUpgradeNotStarted => 'Upgrade not started';

  @override
  String get otaCheckingUpgradeFile => 'Checking upgrade file';

  @override
  String get otaUpgradeFailed => 'Upgrade failed: %s';

  @override
  String get otaCheckFile => 'Verifying file';

  @override
  String get updateFailed => 'Update failed';

  @override
  String get unknownError => 'Unknown error';

  @override
  String get scanQrcode => 'Scan QR Code';

  @override
  String get photos => 'Photos';

  @override
  String get qrcodeIntoBox => 'Place the QR code/barcode inside the frame';

  @override
  String get failPhotosSystemReason => 'Unable to access photos due to system reasons';

  @override
  String get accessCameraReason => 'Camera access is required to scan QR codes for downloading resources';

  @override
  String get accessPhotosReason => 'Photo album access is required to scan QR codes for downloading resources';

  @override
  String get systemSetCamera => 'This feature requires your camera, please go to system settings to grant permission';

  @override
  String get systemSetExternalStorage => 'This feature requires your phone storage, please go to system settings to grant permission';

  @override
  String get downloadSavePending => 'Saving file. Please be patient...';

  @override
  String get downloadingFile => 'Downloading file';

  @override
  String get downloadSuccessful => 'Download successful';

  @override
  String get downloadCompleted => 'Download completed';

  @override
  String get pleaseRefreshWeb => 'Upload success, please refresh web page';

  @override
  String get pressAgainToExit => 'Press again to exit';

  @override
  String get notFoundQRCode => 'No QR code detected';

  @override
  String get fileShare => 'File sharing';

  @override
  String get shareUfwFile => 'Share ufw file';

  @override
  String get shareUfwFileTips => 'Instructions for sharing ufw files from third-party apps';

  @override
  String get deviceMustMandatoryUpgrade => 'Device must be forced to upgrade';

  @override
  String get bluetoothDisconnected => 'Bluetooth disconnected';

  @override
  String get gattUuidPlaceholder => 'Please enter one or more UUIDs, separated by commas or newlines';

  @override
  String get gattServiceUuid => 'GATT Service UUID';

  @override
  String get gattUuidTips => 'Example: 180A, 0000180D-0000-1000-8000-00805F9B34FB';

  @override
  String get gattUuidErrorEmpty => 'Please enter at least one UUID';

  @override
  String get gattUuidErrorInvalidFmt => 'Invalid UUID format:\n%s';

  @override
  String get customCommand => 'Custom command';

  @override
  String get sendCustomCmd => 'Send custom command';

  @override
  String get receivedData => 'Received data';

  @override
  String get inputData => 'Input data';
}
