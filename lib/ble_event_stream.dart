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
}
