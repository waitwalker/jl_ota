import 'package:jl_ota/constant/ble_event_constants.dart';
import 'package:jl_ota/ble_method.dart';

/// Manages OTA files, including reading and deleting files.
class OtaFileManager {
  final List<Map<String, String>> otaFileList;
  final Function(List<Map<String, String>>) onFileListUpdated;
  final Function(String?) onSelectedFileChanged;

  OtaFileManager({required this.otaFileList, required this.onFileListUpdated, required this.onSelectedFileChanged});

  Future<void> deleteFile(int index) async {
    try {
      await BleMethod.deleteOtaIndex(index);
      final filePath = otaFileList[index][BleEventConstants.KEY_PATH];
      onSelectedFileChanged(filePath);
    } catch (e) {
      //print("Failed to delete file: $e");
    }
  }
}
