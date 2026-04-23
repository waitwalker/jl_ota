import 'dart:developer';
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:jl_ota/ble_method.dart';

import 'package:jl_ota/constant/constants.dart';

/// Application Utility Class
///
/// Provides a collection of common utility functions and validations
/// used throughout the application, including platform detection,
/// URL validation, file accessibility checks, and BLE operations.
///
/// All methods are static and can be accessed without instantiating the class.
class AppUtil {
  /// Checks if the current platform is Android
  static bool get isAndroid => Platform.isAndroid;

  /// Checks if the current platform is iOS
  static bool get isIOS => Platform.isIOS;

  /// Reads BLE file list asynchronously
  ///
  /// Attempts to read the file list from a BLE device
  /// using the BleMethod class. Catches and logs any errors that occur
  /// during the operation.
  ///
  /// Returns a Future that completes when the operation is finished.
  static Future<void> readFileList() async {
    try {
      await BleMethod.readFileList();
    } catch (e) {
      log("Failed to read OTA file list: $e");
    }
  }

  /// Validates if a string is a properly formatted HTTP or HTTPS URL
  ///
  /// [code]: The string to validate as a URL
  /// Returns true if the string is a valid HTTP/HTTPS URL, false otherwise
  static bool isValidUrl(String code) {
    try {
      final uri = Uri.parse(code);
      return uri.isScheme('http') || uri.isScheme('https');
    } catch (e) {
      return false;
    }
  }

  /// Checks if a file at the given URL is accessible
  ///
  /// Sends a HEAD request to the specified URL to verify if the file
  /// exists and is accessible without downloading the entire content.
  ///
  /// [url]: The URL of the file to check
  /// Returns a Future that completes with true if the file is accessible,
  /// false otherwise
  static Future<bool> isFileAccessible(String url) async {
    HttpClient? httpClient;
    try {
      httpClient = HttpClient();
      var request = await httpClient.headUrl(Uri.parse(url));
      var response = await request.close();
      return response.statusCode == HttpStatus.ok;
    } catch (e) {
      return false;
    } finally {
      httpClient?.close();
    }
  }

  /// Checks if the device is running Android 13 (API level 33) or higher
  ///
  /// Returns a Future that completes with:
  /// - `true` if the device is Android and SDK version is 33+
  /// - `false` if the device is not Android or SDK version is below 33
  static Future<bool> isAndroid13OrHigher() async {
    if (AppUtil.isAndroid) {
      final deviceInfo = await DeviceInfoPlugin().androidInfo;
      return deviceInfo.version.sdkInt >= AppConstants.TIRAMISU;
    }
    return false;
  }

  /// Asynchronously picks a file using the [BleMethod.pickFile] method.
  static Future<void> pickFile() async {
    try {
      await BleMethod.pickFile();
      log("File picked successfully");
    } catch (e) {
      log("Failed to pick file: $e");
    }
  }
}
