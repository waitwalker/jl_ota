/// Device Connection Status Model
///
/// Used to receive real-time connection status of Bluetooth devices from the native Android side.
class DeviceConnection {
  static const String _keyState = 'state';

  final int state;

  const DeviceConnection({required this.state});

  factory DeviceConnection.fromMap(Map<dynamic, dynamic> map) {
    assert(map.containsKey(_keyState), 'DeviceConnection map must contain state key');

    return DeviceConnection(state: map[_keyState] as int);
  }

  Map<String, dynamic> toMap() => {_keyState: state};

  @override
  String toString() => 'DeviceConnection(state: $state)';

  @override
  bool operator ==(Object other) => identical(this, other) || other is DeviceConnection && runtimeType == other.runtimeType && state == other.state;

  @override
  int get hashCode => state.hashCode;
}
