/// Application-wide constants and configuration values
class AppConstants {
  /// User agreement URL for the application
  static const String userAgreementUrl = 'https://cam.jieliapp.com/app/app.user.service.protocol.html';

  /// Privacy policy URL for the application
  static const String privacyPolicyUrl = 'https://cam.jieliapp.com/app/JL_OTA_app_privacy_policy.html';

  /// Constant representing BLE communication method
  static const String communicationWayBle = 'BLE';

  /// Constant representing SPP communication method
  static const String communicationWaySpp = 'SPP';

  /// Icp number
  static const String icpNumber = '粤ICP备18069041号-15A';

  /// Icp url
  static const String icpUrl = 'https://beian.miit.gov.cn/';

  /// For tracking if user has agreed to policies
  static const String agreePolicy = 'agreePolicy';

  /// Filter content for file operations
  static const String filterContent = 'filterContent';

  /// OTA file storage path
  static const String otaPath = 'otaPath';

  /// Default update file name
  static const String updateFileName = 'upgrade.ufw';

  /// Sdk name
  static const String sdkName = 'sdk';

  /// App name
  static const String appName = 'app';

  /// Connection state: Disconnected
  static const int connectionDisconnect = 0;

  /// Connection state: Successfully connected
  static const int connectionOK = 1;

  /// Connection state: Connection failed
  static const int connectionFailed = 2;

  /// Connection state: Currently connecting
  static const int connectionConnecting = 3;

  /// Android 13
  static const int TIRAMISU = 33;

  /// Dialog bottom button height
  static const double dialogButtonHeight = 45.0;

  /// Return icon size value
  static const double returnIconSizeValue = 28.0;
}
