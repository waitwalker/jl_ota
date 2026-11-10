import 'package:flutter/services.dart';

import 'constant/ble_event_constants.dart';
import 'model/device_connection.dart';
import 'model/scan_device.dart';

/// 蓝牙原生事件流监听门面类
///
/// 通过 [EventChannel] 监听原生 Android 端（[EventChannelHandler]）异步分发的各类蓝牙事件，
/// 将底层单一的混合广播流过滤解析为强类型的特定业务事件流（如蓝牙开关、设备扫描、连接状态、OTA 进度等）。
class BleEventStream {
  /// 与原生通信的事件通道实例
  static const EventChannel _eventChannel = EventChannel('com.jieli.ble_plugin/events');

  /// 核心广播流缓存实例（单例模式，避免重复注册原生监听）
  static Stream<dynamic>? _baseStream;

  /// 获取底层原生事件广播流（单例懒加载）
  ///
  /// 若尚未建立监听，则调用 [EventChannel.receiveBroadcastStream] 初始化。
  static Stream<dynamic> get baseStream {
    _baseStream ??= _eventChannel.receiveBroadcastStream();
    return _baseStream!;
  }

  /// 蓝牙适配器开关状态变更事件流
  ///
  /// 订阅该流可实时获知系统蓝牙硬件的开启或关闭：
  /// - `true`: 系统蓝牙已开启
  /// - `false`: 系统蓝牙已关闭
  static Stream<bool> get bluetoothStateStream {
    return baseStream.where((event) => event is Map && event[BleEventConstants.KEY_TYPE] == BleEventConstants.TYPE_BLUETOOTH_STATE).map((event) {
      final data = event[BleEventConstants.KEY_VALUE];
      return data[BleEventConstants.KEY_STATE] as bool;
    });
  }

  /// 蓝牙扫描运行状态事件流
  ///
  /// 派发当前扫描器的工作状态字符串：
  /// - [BleEventConstants.SCAN_STATE_SCANNING]: 正在扫描
  /// - [BleEventConstants.SCAN_STATE_FOUND_DEV]: 发现设备
  /// - [BleEventConstants.SCAN_STATE_IDLE]: 扫描空闲或停止
  static Stream<String> get scanStateStream {
    return baseStream.where((event) => event is Map && event[BleEventConstants.KEY_TYPE] == BleEventConstants.TYPE_SCAN_DEVICE_LIST).map((event) {
      final data = event[BleEventConstants.KEY_VALUE];
      return data[BleEventConstants.KEY_STATE] as String? ?? '';
    });
  }

  /// 扫描发现的蓝牙设备列表更新事件流
  ///
  /// 每次扫描到底层设备列表更新时，派发最新的解析后设备列表 [List<ScanDevice>]。
  static Stream<List<ScanDevice>> get scanDeviceListStream {
    return baseStream.where((event) => event is Map && event[BleEventConstants.KEY_TYPE] == BleEventConstants.TYPE_SCAN_DEVICE_LIST).map((event) {
      final list = event[BleEventConstants.KEY_VALUE][BleEventConstants.KEY_LIST] as List? ?? [];
      return list.whereType<Map>().map((deviceMap) => ScanDevice.fromMap(deviceMap)).toList();
    });
  }

  /// 蓝牙设备物理连接状态变更事件流
  ///
  /// 派发包装后的 [DeviceConnection] 实例，包含连接中、已连接、断开等连接状态码。
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

  /// OTA 通信通道连接状态变更事件流
  ///
  /// 派发 Map 字典包含当前连接状态 [BleEventConstants.KEY_STATE] 以及目标设备类型 [BleEventConstants.KEY_DEVICE_TYPE]。
  static Stream<Map<String, dynamic>> get otaConnectionStream {
    return baseStream.where((event) => event is Map && event[BleEventConstants.KEY_TYPE] == BleEventConstants.TYPE_OTA_CONNECTION).map((event) {
      final data = event[BleEventConstants.KEY_VALUE];
      return {
        BleEventConstants.KEY_STATE: data[BleEventConstants.KEY_STATE],
        BleEventConstants.KEY_DEVICE_TYPE: data[BleEventConstants.KEY_DEVICE_TYPE],
      };
    });
  }

  /// 设备是否必须强制升级事件流
  ///
  /// 派发布尔值：
  /// - `true`: 设备必须强制完成固件升级，不可退出或取消
  /// - `false`: 普通可选升级模式
  static Stream<bool> get mandatoryUpgradeStream {
    return baseStream.where((event) => event is Map && event[BleEventConstants.KEY_TYPE] == BleEventConstants.TYPE_MANDATORY_UPGRADE).map((event) {
      final data = event[BleEventConstants.KEY_VALUE];
      return data[BleEventConstants.KEY_IS_REQUIRED] as bool;
    });
  }

  /// OTA 固件升级执行状态与传输进度事件流
  ///
  /// 派发 Map 结构包含升级阶段信息：
  /// - `state`: 当前升级阶段（idle / start / reconnect / working / unknown）
  /// - `success`: 操作是否成功布尔值
  /// - `code`: 状态码或错误码
  /// - `type`: 升级子类型（文件校验、固件写入等）
  /// - `message`: 描述提示信息
  /// - `progress`: 仅在 `state == 'working'` 时包含当前固件传输进度百分比
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
