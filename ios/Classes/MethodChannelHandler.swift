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
    private weak var flutterViewController: FlutterViewController?
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
    ///   - flutterViewController: The Flutter view controller
    ///   - eventChannelHandler: The event channel handler instance
    init(flutterViewController: FlutterViewController?, eventChannelHandler: EventChannelHandler?) {
        self.flutterViewController = flutterViewController
        self.eventChannelHandler = eventChannelHandler
        super.init()
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
        case MethodChannelConstants.METHOD_GET_SDK_VERSION:
            SettingsManager.getSDKVersion(result: result)
        case MethodChannelConstants.METHOD_GET_APP_VERSION:
            SettingsManager.getAppVersion(result: result)
        case MethodChannelConstants.METHOD_GET_LOG_FILES:
            let logManager = LogManager.shared
            logManager.setEventSink(sink: eventChannelHandler!.eventSink)
            logManager.loadLogFiles()
            result(true)
        case MethodChannelConstants.METHOD_DELETE_ALL_LOG_FILE:
            let logManager = LogManager.shared
            logManager.deleteAllLogs()
            result(true)
        case MethodChannelConstants.METHOD_LOG_FILE_INDEX:
            setLogFileIndex(call: call, result: result)
        case MethodChannelConstants.METHOD_SHARE_LOG_FILE:
            shareLogFile(call: call, result: result)
        case MethodChannelConstants.METHOD_READ_FILE_LIST:
            let otaManager = OtaManager.shared
            otaManager.setEventSink(sink: eventChannelHandler!.eventSink)
            otaManager.scanForUpdateFiles()
        case MethodChannelConstants.METHOD_DELETE_OTA_FILE_INDEX:
            OtaManager.shared.deleteOtaFileIndex(call: call, result: result)
        case MethodChannelConstants.METHOD_GET_WIFI_IP_ADDRESS:
            OtaManager.shared.getWifiIpAddress(result: result)
        case MethodChannelConstants.METHOD_DOWNLOAD_FILE:
            OtaManager.shared.downloadFile(call: call, result: result)
            result(nil)
        case MethodChannelConstants.METHOD_START_OTA:
            OtaManager.shared.startOTA(call: call, result: result)
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
        
        // 开始扫描
        JLBleHandler.share().handleScanDevice()
        result(true)
    }
    
    /// Stops scanning for Bluetooth devices
    /// - Parameter result: Flutter result callback
    private func stopScan(result: @escaping FlutterResult) {
        // 停止扫描
        JLBleHandler.share().handleStopScanDevice()
        result(true)
    }
    
    private func connectDevice(call: FlutterMethodCall, result: @escaping FlutterResult) {
        if !JLBleHandler.share().handleGetBleStatus() {
            if let flutterViewController = UIApplication.shared.keyWindow?.rootViewController as? FlutterViewController {
                let localizedText = DFUITools.languageText("ble_not_open" as String, table: "Localizable")
                DFUITools.showText(localizedText, on: flutterViewController.view, delay: 1.0)
                return
            }
        }
        guard let arguments = call.arguments as? [String: Any],
              let index = arguments[MethodChannelConstants.ARG_INDEX] as? Int else {
            result(FlutterError(code: "INVALID_ARGUMENTS", message: "Missing or invalid index argument", details: nil))
            return
        }
                
        // 通过 eventChannelHandler 访问 btEnityList
        guard let eventHandler = eventChannelHandler else {
            result(FlutterError(code: "HANDLER_NOT_AVAILABLE", message: "Event channel handler not available", details: nil))
            return
        }
        
        if index < 0 || index >= eventHandler.btEnityList.count {
            result(FlutterError(code: "INVALID_INDEX", message: "index=\(index)", details: nil))
            return
        }
        
        // 调用连接设备的逻辑
        connectDevice(at: index)
        
        eventHandler.sendEvent(EventChannelConstants.TYPE_DEVICE_CONNECTION, data: [
            EventChannelConstants.KEY_STATE: ConnectionState.connecting.rawValue])
        
        result(true)
    }
    
    /// Connects to a Bluetooth device at the specified index
    /// - Parameter index: The index of the device in the device list
    func connectDevice(at index: Int) {
        // 检查蓝牙状态
        guard JLBleHandler.share().handleGetBleStatus() else {
            return
        }
        
        // 确保事件处理器存在
        guard let eventHandler = eventChannelHandler else {
            return
        }
        
        // 检查索引有效性
        guard index >= 0, index < eventHandler.btEnityList.count else {
            return
        }
        
        if !ToolsHelper.isConnectBySDK() {
            // 自定义连接方式
            guard let selectedItem = eventHandler.btEnityList[index] as? JLBleEntity else {
                return
            }
            
            let peripheral = selectedItem.mPeripheral
            
            // 检查设备状态
            guard peripheral.state != .connected, peripheral.state != .connecting else {
                return
            }
            
            JLBleManager.sharedInstance().isPaired = ToolsHelper.isSupportPair()
            JLBleManager.sharedInstance().connectBLE(peripheral)
        } else {
            // SDK连接方式
            guard let selectedItem = eventHandler.btEnityList[index] as? JL_EntityM else {
                return
            }
            
            let peripheral = selectedItem.mPeripheral
            
            // 检查设备状态
            guard peripheral.state != .connected, peripheral.state != .connecting else {
                return
            }
            
            JL_RunSDK.sharedInstance().mBleMultiple.ble_PAIR_ENABLE = ToolsHelper.isSupportPair()
            JL_RunSDK.sharedInstance().mBleMultiple.connectEntity(selectedItem) { status in
            }
        }
    }
    
    /// Disconnects from a Bluetooth device at the specified index
    private func disconnectDevice(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let arguments = call.arguments as? [String: Any],
              let index = arguments[MethodChannelConstants.ARG_INDEX] as? Int else {
            result(FlutterError(code: "INVALID_ARGUMENTS", message: "Missing or invalid index argument", details: nil))
            return
        }
        
        // 通过 eventChannelHandler 访问 btEnityList
        guard let eventHandler = eventChannelHandler else {
            result(FlutterError(code: "HANDLER_NOT_AVAILABLE", message: "Event channel handler not available", details: nil))
            return
        }
        
        // 检查索引是否在有效范围内
        if index < 0 || index >= eventHandler.btEnityList.count {
            result(FlutterError(code: "INVALID_INDEX", message: "index=\(index)", details: nil))
            return
        }
        
        // 获取指定索引的设备
        let device: Any = eventHandler.btEnityList[index]
        
        // 断开设备连接
        if !ToolsHelper.isConnectBySDK(), let entity = device as? JLBleEntity {
            // 自定义连接方式的断开逻辑
            if entity.mPeripheral.state == .connected {
                JLBleHandler.share().handleDisconnect()
            }
        } else if let entity = device as? JL_EntityM {
            // SDK连接方式的断开逻辑
            if entity.mPeripheral.state == .connected {
                JL_RunSDK.sharedInstance().mBleMultiple.disconnectEntity(entity) { status in
                    // 断开完成后的回调
                }
            }
        }
        
        // 返回成功结果
        result(true)
    }
    
    /// Handles the Flutter method call for setting the log file index.
    private func setLogFileIndex(call: FlutterMethodCall, result: @escaping FlutterResult) {
        let arguments = call.arguments as? [String: Any]
        let logFileIndex = arguments?[MethodChannelConstants.ARG_LOG_FILE_INDEX] as? Int ?? -1
        let logManager = LogManager.shared
        logManager.setEventSink(sink: eventChannelHandler!.eventSink)
        logManager.handleLogFileIndex(logFileIndex)
        result(true)
    }
    
    private func shareLogFile(call: FlutterMethodCall, result: @escaping FlutterResult) {
        let arguments = call.arguments as? [String: Any]
        let logFileIndex = arguments?[MethodChannelConstants.ARG_LOG_FILE_INDEX] as? Int ?? -1
        
        // Assuming you have access to the current view controller
        if let viewController = UIApplication.shared.keyWindow?.rootViewController {
            LogManager.shared.shareLogFile(index: logFileIndex, from: viewController)
            result(true)
        } else {
            result(FlutterError(
                code: "NO_VIEW_CONTROLLER",
                message: "No view controller available to present share sheet",
                details: nil
            ))
        }
    }
}
