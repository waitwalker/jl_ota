import 'dart:async';

import 'package:jl_ota/constant/constants.dart';
import 'package:jl_ota/ble_event_stream.dart';
import 'package:jl_ota/model/device_connection.dart';

/// Manages OTA update connections and device connections.
class OtaConnectionManager {
  final Function onOtaDataCleaned;
  StreamSubscription<Map<String, dynamic>>? _otaConnectionSubscription;
  StreamSubscription<DeviceConnection>? _deviceConnectionSubscription;

  OtaConnectionManager({required this.onOtaDataCleaned});

  void subscribeToOtaConnectionStream() {
    _otaConnectionSubscription?.cancel();
    _otaConnectionSubscription = BleEventStream.otaConnectionStream.listen((otaData) {
      onOtaDataCleaned();
    });
  }

  void subscribeToDeviceConnectionStream() {
    _deviceConnectionSubscription?.cancel();
    _deviceConnectionSubscription =
        BleEventStream.deviceConnectionStream.listen((connection) {
              if (connection.state == AppConstants.connectionDisconnect) {
                onOtaDataCleaned();
              }
            })
            as StreamSubscription<DeviceConnection>?;
  }

  void dispose() {
    _otaConnectionSubscription?.cancel();
    _deviceConnectionSubscription?.cancel();
  }
}
