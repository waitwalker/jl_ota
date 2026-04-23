/// Scanned Device Model Class
///
/// Used to represent a scanned hardware device, including the device name, description, and online status.
/// - [name] Device name
/// - [desc] Device description
/// - [status] Device online status. true indicates online, false indicates offline.
class ScanDevice {
  static const String _keyName = 'name';
  static const String _keyDescription = 'desc';
  static const String _keyStatus = 'status';

  final String name;
  final String description;
  final bool isOnline;

  const ScanDevice({required this.name, required this.description, required this.isOnline});

  /// Creates a [ScanDevice] from a Map with null-safety defaults
  factory ScanDevice.fromMap(Map map) {
    return ScanDevice(
      name: map[_keyName] as String? ?? '',
      description: map[_keyDescription] as String? ?? '',
      isOnline: map[_keyStatus] as bool? ?? false,
    );
  }

  /// Converts the device to a Map for serialization
  Map<String, dynamic> toMap() => {_keyName: name, _keyDescription: description, _keyStatus: isOnline};

  @override
  String toString() => 'ScanDevice(name: $name, description: $description, isOnline: $isOnline)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ScanDevice && runtimeType == other.runtimeType && name == other.name && description == other.description && isOnline == other.isOnline;

  @override
  int get hashCode => Object.hash(name, description, isOnline);
}
