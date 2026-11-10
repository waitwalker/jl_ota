#if targetEnvironment(simulator)
import Flutter
import Foundation

/// Registers channels without loading the device-only Jieli SDK.
public class JlOtaPlugin: NSObject, FlutterPlugin, FlutterStreamHandler {
    private var eventChannel: FlutterEventChannel?

    public static func register(with registrar: FlutterPluginRegistrar) {
        let instance = JlOtaPlugin()
        let methodChannel = FlutterMethodChannel(
            name: "com.jieli.ble_plugin/methods",
            binaryMessenger: registrar.messenger()
        )
        instance.eventChannel = FlutterEventChannel(
            name: "com.jieli.ble_plugin/events",
            binaryMessenger: registrar.messenger()
        )
        instance.eventChannel?.setStreamHandler(instance)
        registrar.addMethodCallDelegate(instance, channel: methodChannel)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case MethodChannelConstants.METHOD_IS_SCANNING,
            MethodChannelConstants.METHOD_CHECK_BLUETOOTH_ENVIRONMENT,
            MethodChannelConstants.METHOD_TYPE_IS_OTA:
            result(false)
        case MethodChannelConstants.METHOD_STOP_SCAN,
            MethodChannelConstants.METHOD_DISCONNECT_BT_DEVICE,
            MethodChannelConstants.METHOD_SET_LOG_ENABLED:
            result(true)
        default:
            result(
                FlutterError(
                    code: "SIMULATOR_UNSUPPORTED",
                    message: "Jieli Bluetooth and OTA require a physical iOS device.",
                    details: nil
                )
            )
        }
    }

    public func onListen(
        withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink
    ) -> FlutterError? {
        events(["type": "scanDeviceList", "value": ["state": "idle", "list": []]])
        return nil
    }

    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        return nil
    }
}
#endif
