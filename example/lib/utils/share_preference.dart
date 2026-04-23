import 'package:jl_ota/constant/constants.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Manages file-related preference storage operations
class FilePreferenceManager {
  static Future<void> saveFilterContent(String content) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.filterContent, content);
  }

  static Future<String> loadFilterContent() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(AppConstants.filterContent) ?? '';
  }

  static Future<void> saveOtaPath(String? path) async {
    final prefs = await SharedPreferences.getInstance();
    if (path == null) {
      await prefs.remove(AppConstants.otaPath);
    } else {
      await prefs.setString(AppConstants.otaPath, path);
    }
  }

  static Future<String?> loadOtaPath() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(AppConstants.otaPath);
  }

  static Future<void> saveAgreePolicy(bool agreePolicyState) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(AppConstants.agreePolicy, agreePolicyState);
  }

  static Future<bool> loadAgreePolicy() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(AppConstants.agreePolicy) ?? false;
  }
}
