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
        LogManager.shared.cleanUp()
        OtaManager.shared.cleanUp()
        CustomCmdManager.shared.cleanUp()
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
        case MethodChannelConstants.METHOD_GET_LOG_FILE_DIR_PATH:
            SettingsManager.getLogFileDirPath(result: result)
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
        case MethodChannelConstants.METHOD_GET_APP_VERSION:
            SettingsManager.getAppVersion(result: result)
        case MethodChannelConstants.METHOD_GET_LOG_FILES:
            handleGetLogFiles(result: result)
        case MethodChannelConstants.METHOD_DELETE_ALL_LOG_FILE:
            handleDeleteAllLogFiles(result: result)
        case MethodChannelConstants.METHOD_LOG_FILE_INDEX:
            setLogFileIndex(call: call, result: result)
        case MethodChannelConstants.METHOD_SHARE_LOG_FILE:
            shareLogFile(call: call, result: result)
        case MethodChannelConstants.METHOD_READ_FILE_LIST:
            handleReadFileList(result: result)
        case MethodChannelConstants.METHOD_DELETE_OTA_FILE_INDEX:
            OtaManager.shared.deleteOtaFileIndex(call: call, result: result)
        case MethodChannelConstants.METHOD_GET_WIFI_IP_ADDRESS:
            OtaManager.shared.getWifiIpAddress(result: result)
        case MethodChannelConstants.METHOD_DOWNLOAD_FILE:
            handleDownloadFile(call: call, result: result)
        case MethodChannelConstants.METHOD_START_OTA:
            OtaManager.shared.startOTA(call: call, result: result)
        case MethodChannelConstants.METHOD_SEND_CUSTOM_COMMAND:
            sendCustomCmd(call:call,result:result)
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
        result(true)
    }
    
    /// Stops scanning for Bluetooth devices
    /// - Parameter result: Flutter result callback
    private func stopScan(result: @escaping FlutterResult) {
        // Stop scanning
        JLBleHandler.share().handleStopScanDevice()
        result(true)
    }
    
    private func connectDevice(call: FlutterMethodCall, result: @escaping FlutterResult) {
        // Check Bluetooth status
        if !JLBleHandler.share().handleGetBleStatus() {
            // Show alert if possible
            if let flutterViewController = UIApplication.shared.keyWindow?.rootViewController as? FlutterViewController {
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
        
        // Call the device connection logic
        connectDevice(at: index)
        
        guard let gattServiceUUIDs = ToolsHelper.getGattServiceUUIDs(),
              !gattServiceUUIDs.isEmpty else {
            eventHandler.sendEvent(EventChannelConstants.TYPE_DEVICE_CONNECTION, data: [
                EventChannelConstants.KEY_STATE: ConnectionState.connecting.rawValue
            ])
            result(false)
            return
        }

        eventHandler.sendEvent(
            EventChannelConstants.TYPE_DEVICE_CONNECTION,
            data: [
                EventChannelConstants.KEY_STATE: EventChannelHandler.ConnectionState.failed.rawValue
            ]
        )
        result(true)
    }
    
    /// Connects to a Bluetooth device at the specified index
    /// - Parameter index: The index of the device in the device list
    private func connectDevice(at index: Int) {
        // Check Bluetooth status
        guard JLBleHandler.share().handleGetBleStatus() else {
            return
        }
        
        // Ensure event handler exists
        guard let eventHandler = eventChannelHandler else {
            return
        }
        
        // Check index validity
        guard index >= 0, index < eventHandler.btEnityList.count else {
            return
        }
        
        if !ToolsHelper.isConnectBySDK() {
            // Custom connection method
            guard let selectedItem = eventHandler.btEnityList[index] as? JLBleEntity else {
                return
            }
            
            let peripheral = selectedItem.mPeripheral
            
            // Check device status
            guard peripheral.state != .connected, peripheral.state != .connecting else {
                return
            }
            
            JLBleManager.sharedInstance().isPaired = ToolsHelper.isSupportPair()
            JLBleManager.sharedInstance().connectBLE(peripheral)
        } else {
            // SDK connection method
            guard let selectedItem = eventHandler.btEnityList[index] as? JL_EntityM else {
                return
            }
            
            let item = selectedItem.mPeripheral
            
            // Check device status
            guard item.state != .connected, item.state != .connecting else {
                return
            }
            
            JL_RunSDK.sharedInstance().mBleMultiple.ble_PAIR_ENABLE = ToolsHelper.isSupportPair()
            JL_RunSDK.sharedInstance().mBleMultiple.connectEntity(selectedItem) { [weak self] status in
                guard let _ = self else { return }
                if status == JL_EntityM_Status.paired {
                    JL_RunSDK.sharedInstance().mBleEntityM = selectedItem
                    JL_RunSDK.sharedInstance().lastUUID = item.identifier.uuidString
                }
            }
        }
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
        
    private func handleGetLogFiles(result: @escaping FlutterResult) {
        let logManager = LogManager.shared
        if let sink = eventChannelHandler?.eventSink {
            logManager.setEventSink(sink: sink)
        } else {
            JLLogManager.logLevel(.DEBUG, content: "Cannot set event sink for LogManager - eventChannelHandler is nil")
        }
        logManager.loadLogFiles()
        result(true)
    }
    
    private func handleDeleteAllLogFiles(result: @escaping FlutterResult) {
        let logManager = LogManager.shared
        logManager.deleteAllLogs()
        result(true)
    }
    
    /// Handles the Flutter method call for setting the log file index.
    private func setLogFileIndex(call: FlutterMethodCall, result: @escaping FlutterResult) {
        let arguments = call.arguments as? [String: Any]
        let logFileIndex = arguments?[MethodChannelConstants.ARG_LOG_FILE_INDEX] as? Int ?? -1
        let logManager = LogManager.shared
        
        if let sink = eventChannelHandler?.eventSink {
            logManager.setEventSink(sink: sink)
        } else {
            JLLogManager.logLevel(.DEBUG, content: "Cannot set event sink for LogManager - eventChannelHandler is nil")
        }
        
        logManager.handleLogFileIndex(logFileIndex)
        result(true)
    }
    
    private func shareLogFile(call: FlutterMethodCall, result: @escaping FlutterResult) {
        let arguments = call.arguments as? [String: Any]
        let logFileIndex = arguments?[MethodChannelConstants.ARG_LOG_FILE_INDEX] as? Int ?? -1
        
        // Safely get the current view controller with backward compatibility
        let viewController: UIViewController? = {
            if #available(iOS 15.0, *) {
                return UIApplication.shared.connectedScenes
                    .compactMap { $0 as? UIWindowScene }
                    .flatMap { $0.windows }
                    .first { $0.isKeyWindow }?
                    .rootViewController
            } else if #available(iOS 13.0, *) {
                return UIApplication.shared.connectedScenes
                    .compactMap { $0 as? UIWindowScene }
                    .first?
                    .windows
                    .first { $0.isKeyWindow }?
                    .rootViewController
            } else {
                return UIApplication.shared.keyWindow?.rootViewController
            }
        }()
        
        guard let topViewController = viewController else {
            result(FlutterError(
                code: "NO_VIEW_CONTROLLER",
                message: "No view controller available to present share sheet",
                details: nil
            ))
            return
        }
        
        LogManager.shared.shareLogFile(index: logFileIndex, from: topViewController)
        result(true)
    }
        
    private func handleReadFileList(result: @escaping FlutterResult) {
        let otaManager = OtaManager.shared
        if let sink = eventChannelHandler?.eventSink {
            otaManager.setEventSink(sink: sink)
        } else {
            JLLogManager.logLevel(.DEBUG, content: "Cannot set event sink for OtaManager - eventChannelHandler is nil")
        }
        otaManager.scanForUpdateFiles()
        result(nil)
    }
    
    private func handleDownloadFile(call: FlutterMethodCall, result: @escaping FlutterResult) {
        OtaManager.shared.downloadFile(call: call, result: result)
        result(nil)
    }
    
    private func sendCustomCmd(call: FlutterMethodCall, result: @escaping FlutterResult){
        let customCmdManager = CustomCmdManager.shared
        if let sink = eventChannelHandler?.eventSink {
            customCmdManager.setEventSink(sink: sink)
        } else {
            JLLogManager.logLevel(.DEBUG, content: "Cannot set event sink for CustomCmdManager - eventChannelHandler is nil")
        }
        customCmdManager.handleCustomCmd(call: call, result: result)
    }
}
