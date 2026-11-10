/// Method and event names used only by the example app.
class ExampleChannelConstants {
  static const String methodGetAppVersion = 'getAppVersion';
  static const String methodGetLogFileDirPath = 'getLogFileDirPath';
  static const String methodGetLogFiles = 'getLogFiles';
  static const String methodLogFileIndex = 'logFileIndex';
  static const String methodShareLogFile = 'shareLogFile';
  static const String methodDownloadFile = 'downloadFile';
  static const String methodReadFileList = 'readFileList';
  static const String methodDeleteOtaFileIndex = 'deleteOtaFileIndex';
  static const String methodTryToCheckStorageEnvironment = 'tryToCheckStorageEnvironment';
  static const String methodPickFile = 'pickFile';
  static const String methodDeleteAllLogFile = 'deleteAllLogFile';
  static const String methodGetWifiIpAddress = 'getWifiIpAddress';
  static const String methodPopAllActivity = 'popAllActivity';
  static const String methodSendCustomCommand = 'sendCustomCommand';
  static const String methodOnFilePicked = 'onFilePicked';
  static const String methodHandleFilePicked = 'handleFilePicked';

  static const String argLogFileIndex = 'logFileIndex';
  static const String argHttpUrl = 'httpUrl';
  static const String argPos = 'pos';
  static const String argFileName = 'fileName';
  static const String argCustomData = 'customData';

  static const String typeLogFiles = 'logFiles';
  static const String typeLogDetailFiles = 'logDetailFiles';
  static const String typeDownloadStatus = 'downloadStatus';
  static const String typeOtaFileList = 'otaFileList';
  static const String typeOnFilePicked = 'onFilePicked';
  static const String typeHandleFilePicked = 'handleFilePicked';
  static const String typeCustomCommandData = 'customDataUpdate';

  static const String keyFiles = 'files';
  static const String keyFileName = 'fileName';
  static const String keyCustomData = 'customData';

  static const String statusOnProgress = 'onProgress';
  static const String statusOnStop = 'onStop';
  static const String statusOnError = 'onError';
  static const String statusOnStart = 'onStart';
  static const String statusUnknown = 'unknown';
}
