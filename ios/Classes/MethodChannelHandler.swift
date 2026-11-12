#if !SWIFT_PACKAGE || !targetEnvironment(simulator)
//
//  MethodChannelHandler.swift
//  Runner
//
//  Created by 李放 on 2025/9/1.
//

import Foundation
import Flutter

/// Handles method channel communication between Flutter and native iOS code.
/// Manages Bluetooth-related operations including device scanning, connection, disconnection,
/// and log file path retrieval. Acts as a bridge for method calls from Flutter to native iOS functionality.
class MethodChannelHandler: NSObject {
    private weak var eventChannelHandler: EventChannelHandler?
    
    /// 连接状态枚举
    enum ConnectionState: Int {
        case disconnected = 0
        case connected = 1
        case failed = 2
        case connecting = 3
    }
    
    /// Initializes the method channel handler
    /// - Parameters:
    ///   - eventChannelHandler: The event channel handler instance
    init(eventChannelHandler: EventChannelHandler?) {
        self.eventChannelHandler = eventChannelHandler
        super.init()
    }
    
    deinit {
        dispose()
    }
    
    /// Cleans up resources to prevent memory leaks
    func dispose() {
        OtaManager.shared.cleanUp()
        SettingsManager.cleanUp()
        
        // Clear references
        eventChannelHandler = nil
    }
    
    /// Handles method calls from Flutter
    /// - Parameters:
    ///   - call: Method call information
    ///   - result: Result callback
    func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case MethodChannelConstants.METHOD_START_SCAN:
            startScan(result: result)
        case MethodChannelConstants.METHOD_STOP_SCAN:
            stopScan(result: result)
        case MethodChannelConstants.METHOD_CONNECT_DEVICE:
            connectDevice(call: call, result: result)
        case MethodChannelConstants.METHOD_DISCONNECT_BT_DEVICE:
            disconnectDevice(call: call, result: result)
        case MethodChannelConstants.METHOD_IS_USE_DEVICE_AUTH:
            SettingsManager.getUseDeviceAuth(result: result)
        case MethodChannelConstants.METHOD_SET_USE_DEVICE_AUTH:
            SettingsManager.setUseDeviceAuth(call: call, result: result)
        case MethodChannelConstants.METHOD_IS_USING_SDK_BLUETOOTH:
            SettingsManager.getUseSDKBluetooth(result: result)
        case MethodChannelConstants.METHOD_SET_USING_SDK_BLUETOOTH:
            SettingsManager.setUseSDKBluetooth(call: call, result: result)
        case MethodChannelConstants.METHOD_IS_USING_GATT_OVER_EDR:
            SettingsManager.getGattOverEdrState(result: result)
        case MethodChannelConstants.METHOD_SET_GATT_OVER_EDR:
            SettingsManager.setGattOverEdrState(call: call, result: result)
        case MethodChannelConstants.METHOD_GET_GATT_SERVICE_UUIDS:
            SettingsManager.getGattServiceUuids(result: result)
        case MethodChannelConstants.METHOD_SET_GATT_SERVICE_UUIDS:
            SettingsManager.setGattServiceUuids(call: call, result: result)
        case MethodChannelConstants.METHOD_GET_SDK_VERSION:
            SettingsManager.getSDKVersion(result: result)
        case MethodChannelConstants.METHOD_START_OTA:
            // Hosts may skip readFileList; bind sink here so OTA state is not dropped.
            bindOtaEventSink()
            OtaManager.shared.startOTA(call: call, result: result)
        case MethodChannelConstants.METHOD_SET_LOG_ENABLED:
            let enabled = (call.arguments as? [String: Any])?[MethodChannelConstants.ARG_ENABLED] as? Bool ?? false
            JlOtaPlugin.setLogEnabled(enabled)
            result(true)
        default:
            result(FlutterMethodNotImplemented)
        }
    }
        
    /// Starts scanning for Bluetooth devices
    /// - Parameter result: Flutter result callback
    private func startScan(result: @escaping FlutterResult) {
        if (!JLBleHandler.share().handleGetBleStatus()) {
            result(FlutterError(code: "BLE_NOT_AVAILABLE", message: "Bluetooth not available", details: nil))
            return
        }
        
        // Start scanning
        JLBleHandler.share().handleScanDevice()
        eventChannelHandler?.sendScanDeviceListToFlutter()
        result(true)
    }
    
    /// Stops scanning for Bluetooth devices
    /// - Parameter result: Flutter result callback
    private func stopScan(result: @escaping FlutterResult) {
        // Stop scanning
        JLBleHandler.share().handleStopScanDevice()
        eventChannelHandler?.notifyScanStopped()
        result(true)
    }
    
    /// 取当前前台界面的 Flutter 控制器，用来在蓝牙未打开时弹出提示。
    /// iOS 13 起 keyWindow 已废弃，改为从当前 WindowScene 取 key window。
    private func foregroundFlutterViewController() -> FlutterViewController? {
        let rootViewController: UIViewController?
        if #available(iOS 13.0, *) {
            rootViewController = UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap { $0.windows }
                .first(where: { $0.isKeyWindow })?
                .rootViewController
        } else {
            rootViewController = UIApplication.shared.keyWindow?.rootViewController
        }
        return rootViewController as? FlutterViewController
    }

    private func connectDevice(call: FlutterMethodCall, result: @escaping FlutterResult) {
        // Check Bluetooth status
        if !JLBleHandler.share().handleGetBleStatus() {
            // Show alert if possible
            if let flutterViewController = foregroundFlutterViewController() {
                let localizedText = DFUITools.languageText("ble_not_open" as String, table: "Localizable")
                DFUITools.showText(localizedText, on: flutterViewController.view, delay: 1.0)
            }
            // Always return error when Bluetooth is not available
            result(FlutterError(code: "BLE_NOT_AVAILABLE", message: "Bluetooth not available", details: nil))
            return
        }
        
        guard let arguments = call.arguments as? [String: Any],
              let index = arguments[MethodChannelConstants.ARG_INDEX] as? Int else {
            result(FlutterError(code: "INVALID_ARGUMENTS", message: "Missing or invalid index argument", details: nil))
            return
        }
        
        // Access btEnityList through eventChannelHandler
        guard let eventHandler = eventChannelHandler else {
            result(FlutterError(code: "HANDLER_NOT_AVAILABLE", message: "Event channel handler not available", details: nil))
            return
        }
        
        guard index >= 0, index < eventHandler.btEnityList.count else {
            result(FlutterError(code: "INVALID_INDEX", message: "index=\(index)", details: nil))
            return
        }
        
        guard connectDevice(at: index) else {
            result(FlutterError(code: "CONNECT_FAILED", message: "Unable to start connection", details: nil))
            return
        }

        eventHandler.sendEvent(EventChannelConstants.TYPE_DEVICE_CONNECTION, data: [
            EventChannelConstants.KEY_STATE: ConnectionState.connecting.rawValue
        ])
        result(true)
    }
    
    /// Connects to a Bluetooth device at the specified index.
    /// - Returns: false when this index cannot start a new connection.
    private func connectDevice(at index: Int) -> Bool {
        guard JLBleHandler.share().handleGetBleStatus() else {
            return false
        }
        guard let eventHandler = eventChannelHandler else {
            return false
        }
        guard index >= 0, index < eventHandler.btEnityList.count else {
            return false
        }
        
        if !ToolsHelper.isConnectBySDK() {
            guard let selectedItem = eventHandler.btEnityList[index] as? JLBleEntity else {
                return false
            }
            let peripheral = selectedItem.mPeripheral
            guard peripheral.state != .connected, peripheral.state != .connecting else {
                return false
            }
            
            JLBleManager.sharedInstance().isPaired = ToolsHelper.isSupportPair()
            JLBleManager.sharedInstance().connectBLE(peripheral)
            return true
        }

        guard let selectedItem = eventHandler.btEnityList[index] as? JL_EntityM else {
            return false
        }
        let item = selectedItem.mPeripheral
        guard item.state != .connected, item.state != .connecting else {
            return false
        }
        
        JL_RunSDK.sharedInstance().mBleMultiple.ble_PAIR_ENABLE = ToolsHelper.isSupportPair()
        JL_RunSDK.sharedInstance().mBleMultiple.connectEntity(selectedItem) { status in
            if status == .paired {
                JL_RunSDK.sharedInstance().mBleEntityM = selectedItem
                JL_RunSDK.sharedInstance().lastUUID = item.identifier.uuidString
                return
            }
            JL_RunSDK.sharedInstance().notifyIfConnectFailed(status, peripheral: item)
        }
        return true
    }
    
    /// Disconnects from a Bluetooth device at the specified index
    private func disconnectDevice(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let arguments = call.arguments as? [String: Any],
              let index = arguments[MethodChannelConstants.ARG_INDEX] as? Int else {
            result(FlutterError(code: "INVALID_ARGUMENTS",
                               message: "Missing or invalid index argument",
                               details: nil))
            return
        }
        
        guard let eventHandler = eventChannelHandler else {
            result(FlutterError(code: "HANDLER_NOT_AVAILABLE",
                               message: "Event channel handler not available",
                               details: nil))
            return
        }
        
        guard index >= 0 && index < eventHandler.btEnityList.count else {
            result(FlutterError(code: "INVALID_INDEX",
                               message: "Index \(index) out of range (0..<\(eventHandler.btEnityList.count))",
                               details: nil))
            return
        }
        
        let device = eventHandler.btEnityList[index]
        performDisconnection(for: device)
        
        result(true)
    }

    private func performDisconnection(for device: Any) {
        if !ToolsHelper.isConnectBySDK(), let entity = device as? JLBleEntity {
            disconnectCustomEntity(entity)
        } else if let entity = device as? JL_EntityM {
            disconnectSDKEntity(entity)
        }
    }

    private func disconnectCustomEntity(_ entity: JLBleEntity) {
        guard entity.mPeripheral.state == .connected else {
            JLLogManager.logLevel(.DEBUG, content: "Device already disconnected or not connected")
            return
        }
        JLBleHandler.share().handleDisconnect()
        JLLogManager.logLevel(.DEBUG, content: "Disconnected custom entity")
    }

    private func disconnectSDKEntity(_ entity: JL_EntityM) {
        guard entity.mPeripheral.state == .connected else {
            JLLogManager.logLevel(.DEBUG, content: "Device already disconnected or not connected")
            return
        }
        
        JL_RunSDK.sharedInstance().mBleMultiple.disconnectEntity(entity) { [weak self] status in
            guard self != nil else { return }
            JLLogManager.logLevel(.DEBUG, content: "SDK disconnection completed with status: \(status)")
        }
    }
        
    /// Bind EventChannel sink to OtaManager so OTA state can reach Flutter.
    private func bindOtaEventSink() {
        if let sink = eventChannelHandler?.eventSink {
            OtaManager.shared.setEventSink(sink: sink)
        } else {
            JLLogManager.logLevel(.DEBUG, content: "Cannot set event sink for OtaManager - eventChannelHandler is nil")
        }
    }
}

#endif
