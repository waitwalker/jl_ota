import 'package:flutter/services.dart';

import 'example_channel_constants.dart';

/// Example-only native calls. Host OTA stays on [BleMethod].
class ExampleMethod {
  static const MethodChannel methodChannel = MethodChannel('com.jieli.otasdk.example/methods');

  static Future<String> getAppVersion() async {
    return await methodChannel.invokeMethod(ExampleChannelConstants.methodGetAppVersion) ?? 'V?.?.?(?)';
  }

  static Future<String> getLogFileDirPath() async {
    return await methodChannel.invokeMethod(ExampleChannelConstants.methodGetLogFileDirPath) ?? '';
  }

  static Future<void> getLogFiles() async {
    await methodChannel.invokeMethod(ExampleChannelConstants.methodGetLogFiles);
  }

  static Future<void> clickLogFileIndex(int logFileIndex) async {
    await methodChannel.invokeMethod(ExampleChannelConstants.methodLogFileIndex, {ExampleChannelConstants.argLogFileIndex: logFileIndex});
  }

  static Future<bool> deleteAllLogFiles() async {
    return await methodChannel.invokeMethod(ExampleChannelConstants.methodDeleteAllLogFile) ?? false;
  }

  static Future<void> shareLogFile(int logFileIndex) async {
    await methodChannel.invokeMethod(ExampleChannelConstants.methodShareLogFile, {ExampleChannelConstants.argLogFileIndex: logFileIndex});
  }

  static Future<void> downloadFile(String httpUrl) async {
    await methodChannel.invokeMethod(ExampleChannelConstants.methodDownloadFile, {ExampleChannelConstants.argHttpUrl: httpUrl});
  }

  static Future<void> readFileList() async {
    await methodChannel.invokeMethod(ExampleChannelConstants.methodReadFileList);
  }

  static Future<void> deleteOtaIndex(int pos) async {
    await methodChannel.invokeMethod(ExampleChannelConstants.methodDeleteOtaFileIndex, {ExampleChannelConstants.argPos: pos});
  }

  static Future<bool> tryToCheckStorageEnvironment() async {
    return await methodChannel.invokeMethod(ExampleChannelConstants.methodTryToCheckStorageEnvironment) ?? false;
  }

  static Future<void> pickFile() async {
    await methodChannel.invokeMethod(ExampleChannelConstants.methodPickFile);
  }

  static Future<String> getWifiIpAddress() async {
    final String? ipAddress = await methodChannel.invokeMethod<String>(ExampleChannelConstants.methodGetWifiIpAddress);
    return ipAddress ?? 'Failed to get WiFi IP address';
  }

  static Future<void> popAllActivity() async {
    await methodChannel.invokeMethod(ExampleChannelConstants.methodPopAllActivity);
  }

  static Future<void> exitApp() async {
    await methodChannel.invokeMethod('exitApp');
  }

  static Future<void> sendCustomCommand(Uint8List data) async {
    await methodChannel.invokeMethod(ExampleChannelConstants.methodSendCustomCommand, {ExampleChannelConstants.argCustomData: data});
  }
}
