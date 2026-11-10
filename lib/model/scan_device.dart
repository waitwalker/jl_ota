import 'jl_adv_data.dart';

/// 扫描发现的蓝牙设备模型类
///
/// 用于封装扫描发现的蓝牙硬件设备信息，包含设备名称、描述（通常为 MAC 地址或附加信息）、在线状态以及杰理私有广播数据。
class ScanDevice {
  /// 设备名称字段在原生字典中的键名
  static const String _keyName = 'name';

  /// 设备描述字段在原生字典中的键名
  static const String _keyDescription = 'desc';

  /// 设备状态字段在原生字典中的键名
  static const String _keyStatus = 'status';

  /// 厂商广播数据字段在原生字典中的下划线格式键名
  static const String _keyAdvData = 'adv_data';

  /// 厂商广播数据字段在原生字典中的驼峰格式键名
  static const String _keyAdvDataCamel = 'advData';

  /// 蓝牙设备名称
  final String name;

  /// 蓝牙设备描述（通常包含 MAC 地址、信号强度 RSSI 等信息）
  final String description;

  /// 设备在线/连接就绪状态：true 表示在线可用，false 表示离线或断开
  final bool isOnline;

  /// 杰理私有 BLE 广播解析数据模型（包含电量、充电状态、TWS 状态、UID/PID 等）
  final JlAdvData? advData;

  /// 构造一个扫描发现的设备实体
  ///
  /// - [name] 设备广播名称
  /// - [description] 设备详细描述
  /// - [isOnline] 设备是否在线
  /// - [advData] 杰理 BLE 厂商广播数据（可选）
  const ScanDevice({required this.name, required this.description, required this.isOnline, this.advData});

  /// 从原生上报的动态 Map 中安全解析并构造 [ScanDevice]
  ///
  /// 对可能缺失或格式不一致的字段具备空安全兜底处理。
  /// [map] 包含设备信息的 Map 对象
  factory ScanDevice.fromMap(dynamic map) {
    if (map == null || map is! Map) {
      return const ScanDevice(name: '', description: '', isOnline: false);
    }

    final rawAdvData = map[_keyAdvData] ?? map[_keyAdvDataCamel];
    final advData = JlAdvData.fromMap(rawAdvData);

    return ScanDevice(
      name: map[_keyName]?.toString() ?? '',
      description: map[_keyDescription]?.toString() ?? '',
      isOnline: map[_keyStatus] is bool ? map[_keyStatus] as bool : (map[_keyStatus]?.toString() == 'true'),
      advData: advData,
    );
  }

  /// 将设备对象转换为 Map，便于序列化传输或数据存储
  Map<String, dynamic> toMap() => {
    _keyName: name,
    _keyDescription: description,
    _keyStatus: isOnline,
    if (advData != null) _keyAdvData: advData!.toMap(),
  };

  @override
  String toString() => 'ScanDevice(name: $name, description: $description, isOnline: $isOnline, advData: $advData)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ScanDevice &&
          runtimeType == other.runtimeType &&
          name == other.name &&
          description == other.description &&
          isOnline == other.isOnline &&
          advData == other.advData;

  @override
  int get hashCode => Object.hash(name, description, isOnline, advData);
}
