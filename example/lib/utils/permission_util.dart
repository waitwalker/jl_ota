import 'package:device_info_plus/device_info_plus.dart';
import 'package:jl_ota/constant/constants.dart';
import 'package:permission_handler/permission_handler.dart';

import 'app_util.dart';

/// Utility class for handling permissions in the application
class PermissionUtil {
  static Future<bool> isAndroid13OrHigher() async {
    if (AppUtil.isAndroid) {
      final deviceInfo = await DeviceInfoPlugin().androidInfo;
      return deviceInfo.version.sdkInt >= AppConstants.TIRAMISU;
    }
    return false;
  }

  static Future<PermissionStatus> requestGalleryPermission() async {
    if (await isAndroid13OrHigher() || AppUtil.isIOS) {
      return await Permission.photos.request();
    } else {
      return await Permission.storage.request();
    }
  }
}
