import 'package:flutter/services.dart';

import 'constant/ble_event_constants.dart';
import 'model/device_connection.dart';
import 'model/scan_device.dart';

/// Bluetooth Feature Plugin Wrapper
///
/// Communicates with the native Android side via 'EventChannel'.
/// All external interfaces are static methods/properties and can be directly accessed through BleEventStream.xxx.
class BleEventStream {
  static const EventChannel _eventChannel = EventChannel('com.jieli.ble_plugin/events');

  // 核心广播流
  // 单例模式:确保_baseStream只被初始化一次
  static Stream<dynamic>? _baseStream;

  // 提供一个公共的访问方法
  static Stream<dynamic> get baseStream {
    _baseStream ??= _eventChannel.receiveBroadcastStream();
    return _baseStream!;
  }

  // 蓝牙状态流
  static Stream<bool> get bluetoothStateStream {
    return baseStream.where((event) => event is Map && event[BleEventConstants.KEY_TYPE] == BleEventConstants.TYPE_BLUETOOTH_STATE).map((event) {
      final data = event[BleEventConstants.KEY_VALUE];
      return data[BleEventConstants.KEY_STATE] as bool;
    });
  }

  // 扫描状态流
  static Stream<String> get scanStateStream {
    return baseStream.where((event) => event is Map && event[BleEventConstants.KEY_TYPE] == BleEventConstants.TYPE_SCAN_DEVICE_LIST).map((event) {
      final data = event[BleEventConstants.KEY_VALUE];
      return data[BleEventConstants.KEY_STATE] as String? ?? '';
    });
  }

  // 扫描设备列表流
  static Stream<List<ScanDevice>> get scanDeviceListStream {
    return baseStream.where((event) => event is Map && event[BleEventConstants.KEY_TYPE] == BleEventConstants.TYPE_SCAN_DEVICE_LIST).map((event) {
      final list = event[BleEventConstants.KEY_VALUE][BleEventConstants.KEY_LIST] as List? ?? [];
      return list.whereType<Map>().map((deviceMap) => ScanDevice.fromMap(deviceMap)).toList();
    });
  }

  // 设备连接状态流
  static Stream<DeviceConnection> get deviceConnectionStream {
    return baseStream
        .where((event) {
          return event is Map && event[BleEventConstants.KEY_TYPE] == BleEventConstants.TYPE_DEVICE_CONNECTION;
        })
        .map((event) {
          final data = event[BleEventConstants.KEY_VALUE];
          return DeviceConnection.fromMap(data);
        });
  }

  // OTA连接状态流
  static Stream<Map<String, dynamic>> get otaConnectionStream {
    return baseStream.where((event) => event is Map && event[BleEventConstants.KEY_TYPE] == BleEventConstants.TYPE_OTA_CONNECTION).map((event) {
      final data = event[BleEventConstants.KEY_VALUE];
      return {
        BleEventConstants.KEY_STATE: data[BleEventConstants.KEY_STATE],
        BleEventConstants.KEY_DEVICE_TYPE: data[BleEventConstants.KEY_DEVICE_TYPE],
      };
    });
  }

  // 日志文件列表流
  static Stream<List<Map<String, String>>> get logFilesStream {
    return baseStream.where((event) => event is Map && event[BleEventConstants.KEY_TYPE] == BleEventConstants.TYPE_LOG_FILES).map((event) {
      final files = event[BleEventConstants.KEY_FILES] as List? ?? [];
      return files.whereType<Map>().map((fileMap) => {BleEventConstants.KEY_NAME: fileMap[BleEventConstants.KEY_NAME] as String? ?? ''}).toList();
    });
  }

  // 日志文件详情流
  static Stream<String> get logDetailFilesStream {
    return baseStream.where((event) => event is Map && event[BleEventConstants.KEY_TYPE] == BleEventConstants.TYPE_LOG_DETAIL_FILES).map((event) {
      final files = event[BleEventConstants.KEY_FILES] as List? ?? [];
      return files.first as String? ?? '';
    });
  }

  // 下载状态流
  static Stream<Map<String, dynamic>> get downloadStatusStream {
    return baseStream.where((event) => event is Map && event[BleEventConstants.KEY_TYPE] == BleEventConstants.TYPE_DOWNLOAD_STATUS).map((event) {
      final data = event[BleEventConstants.KEY_VALUE];
      return {
        BleEventConstants.KEY_STATUS: data[BleEventConstants.KEY_STATUS],
        BleEventConstants.KEY_PROGRESS: data[BleEventConstants.KEY_PROGRESS],
        BleEventConstants.KEY_MESSAGE: data[BleEventConstants.KEY_MESSAGE],
      };
    });
  }

  // OTA文件列表流
  static Stream<List<Map<String, String>>> get otaFileListStream {
    return baseStream.where((event) => event is Map && event[BleEventConstants.KEY_TYPE] == BleEventConstants.TYPE_OTA_FILE_LIST).map((event) {
      final list = event[BleEventConstants.KEY_VALUE][BleEventConstants.KEY_LIST] as List? ?? [];
      return list
          .whereType<Map>()
          .map(
            (fileMap) => {
              BleEventConstants.KEY_NAME: fileMap[BleEventConstants.KEY_NAME] as String? ?? '',
              BleEventConstants.KEY_PATH: fileMap[BleEventConstants.KEY_PATH] as String? ?? '',
            },
          )
          .toList();
    });
  }

  // 选中的文件路径流
  static Stream<List<String>> get selectedFilePathsStream {
    return baseStream.where((event) => event is Map && event[BleEventConstants.KEY_TYPE] == BleEventConstants.TYPE_SELECTED_FILE_PATHS).map((event) {
      final list = event[BleEventConstants.KEY_VALUE][BleEventConstants.KEY_LIST] as List? ?? [];
      return list.whereType<String>().toList();
    });
  }

  // 强制升级流
  static Stream<bool> get mandatoryUpgradeStream {
    return baseStream.where((event) => event is Map && event[BleEventConstants.KEY_TYPE] == BleEventConstants.TYPE_MANDATORY_UPGRADE).map((event) {
      final data = event[BleEventConstants.KEY_VALUE];
      return data[BleEventConstants.KEY_IS_REQUIRED] as bool;
    });
  }

  // OTA状态流
  static Stream<Map<String, dynamic>> get otaStateStream {
    return baseStream.where((event) => event is Map && event[BleEventConstants.KEY_TYPE] == BleEventConstants.TYPE_OTA_STATE).map((event) {
      final data = event[BleEventConstants.KEY_VALUE];
      final state = data[BleEventConstants.KEY_STATE];
      final result = {
        BleEventConstants.KEY_STATE: state,
        BleEventConstants.KEY_SUCCESS: data[BleEventConstants.KEY_SUCCESS],
        BleEventConstants.KEY_CODE: data[BleEventConstants.KEY_CODE],
        BleEventConstants.KEY_TYPE: data[BleEventConstants.KEY_TYPE],
        BleEventConstants.KEY_MESSAGE: data[BleEventConstants.KEY_MESSAGE],
      };
      if (state == BleEventConstants.KEY_STATE_WORKING) {
        result[BleEventConstants.KEY_PROGRESS] = data[BleEventConstants.KEY_PROGRESS];
      }
      return result;
    });
  }

  // 自定义命令数据流
  static Stream<Uint8List> get customCommandData {
    return baseStream.where((event) => event is Map && event[BleEventConstants.KEY_TYPE] == BleEventConstants.TYPE_CUSTOM_COMMAND_DATA).map((event) {
      try {
        final data = event[BleEventConstants.KEY_VALUE] as Map?;
        if (data == null) return Uint8List(0);

        final customData = data[BleEventConstants.KEY_CUSTOM_DATA];

        if (customData == null) {
          return Uint8List(0);
        }

        if (customData is List) {
          if (customData is List<int>) {
            return Uint8List.fromList(customData);
          }

          final List<int> result = [];
          for (var element in customData) {
            if (element is int) {
              result.add(element);
            } else if (element is num) {
              result.add(element.toInt());
            } else {
              return Uint8List(0);
            }
          }
          return Uint8List.fromList(result);
        }
        return Uint8List(0);
      } catch (e) {
        return Uint8List(0);
      }
    });
  }

  // 错误流
  static Stream<Map<String, String>> get errorStream {
    return baseStream.where((event) => event is PlatformException).map((event) {
      final error = event as PlatformException;
      if (error.code == BleEventConstants.ERROR) {
        return {BleEventConstants.KEY_CODE: error.code, BleEventConstants.KEY_MESSAGE: error.message ?? 'Unknown log error'};
      }
      throw error;
    });
  }
}
