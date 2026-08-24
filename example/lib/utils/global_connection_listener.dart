import 'dart:async';
import 'dart:developer';

import 'package:jl_ota/ble_event_stream.dart';
import 'package:jl_ota/model/device_connection.dart';

import 'connection_state_manager.dart';

/// Global Connection State Manager
class GlobalConnectionListener {
  static final GlobalConnectionListener _instance = GlobalConnectionListener._internal();

  StreamSubscription<DeviceConnection>? _deviceConnectionSubscription;
  bool _isInitialized = false;

  GlobalConnectionListener._internal();

  factory GlobalConnectionListener() => _instance;

  /// 初始化全局连接监听
  void initialize() {
    if (_isInitialized) return;

    _subscribeToDeviceConnectionStream();
    _isInitialized = true;
  }

  /// 订阅设备连接状态变化
  void _subscribeToDeviceConnectionStream() {
    _deviceConnectionSubscription = BleEventStream.deviceConnectionStream.listen(
      (connection) {
        // 更新全局连接状态
        ConnectionStateManager().updateConnectState(connection.state);
        log("Global connection status: ${connection.state}");
      },
      onError: (error) {
        log("Global device connection stream error: $error");
      },
    );
  }

  /// 清理资源（在应用退出时调用）
  void dispose() {
    _deviceConnectionSubscription?.cancel();
    _deviceConnectionSubscription = null;
    _isInitialized = false;
  }

  /// 获取当前连接状态
  static int get currentState {
    return ConnectionStateManager().connectState;
  }
}
