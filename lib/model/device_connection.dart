/// 蓝牙设备连接状态数据模型类
///
/// 用于封装原生 Android 侧通过 EventChannel 实时上报的蓝牙物理链路连接状态。
class DeviceConnection {
  /// 状态字段在事件载荷中的字典键名
  static const String _keyState = 'state';

  /// 蓝牙连接状态数值
  ///
  /// 可选值对应：
  /// - `0`: [AppConstants.connectionDisconnect] 已断开连接
  /// - `1`: [AppConstants.connectionOK] 连接成功
  /// - `2`: [AppConstants.connectionFailed] 连接失败
  /// - `3`: [AppConstants.connectionConnecting] 正在建立连接中
  final int state;

  /// 构造一个设备连接状态模型实例
  ///
  /// [state] 连接状态枚举值
  const DeviceConnection({required this.state});

  /// 从原生上报的字典数据中解析并构造 [DeviceConnection]
  ///
  /// [map] 包含连接状态信息的 Map
  factory DeviceConnection.fromMap(Map<dynamic, dynamic> map) {
    assert(map.containsKey(_keyState), 'DeviceConnection map must contain state key');

    return DeviceConnection(state: map[_keyState] as int);
  }

  /// 将模型对象转换为 Map 结构，便于序列化传输或调试输出
  Map<String, dynamic> toMap() => {_keyState: state};

  @override
  String toString() => 'DeviceConnection(state: $state)';

  @override
  bool operator ==(Object other) => identical(this, other) || other is DeviceConnection && runtimeType == other.runtimeType && state == other.state;

  @override
  int get hashCode => state.hashCode;
}
