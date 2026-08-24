import 'jl_adv_data.dart';

/// Scanned Device Model Class
///
/// Used to represent a scanned hardware device, including the device name, description, online status, and broadcast data.
/// - [name] Device name
/// - [description] Device description
/// - [isOnline] Device online status. true indicates online, false indicates offline.
/// - [advData] JieLi BLE broadcast advertisement data
class ScanDevice {
  static const String _keyName = 'name';
  static const String _keyDescription = 'desc';
  static const String _keyStatus = 'status';
  static const String _keyAdvData = 'adv_data';
  static const String _keyAdvDataCamel = 'advData';

  final String name;
  final String description;
  final bool isOnline;
  final JlAdvData? advData;

  const ScanDevice({required this.name, required this.description, required this.isOnline, this.advData});

  /// Creates a [ScanDevice] from a Map with null-safety defaults
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

  /// Converts the device to a Map for serialization
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
