import 'package:flutter/foundation.dart';
import 'package:jl_ota/constant/constants.dart';

/// Global connection state manager for Bluetooth device connectivity.
class ConnectionStateManager extends ChangeNotifier {
  static ConnectionStateManager? _instance;

  ConnectionStateManager._internal();

  factory ConnectionStateManager() {
    _instance ??= ConnectionStateManager._internal();
    return _instance!;
  }

  int _connectState = AppConstants.connectionFailed;

  int get connectState => _connectState;

  void updateConnectState(int newState) {
    if (_connectState != newState) {
      _connectState = newState;
      notifyListeners();
    }
  }

  static int get currentState => _instance?._connectState ?? AppConstants.connectionFailed;
}
