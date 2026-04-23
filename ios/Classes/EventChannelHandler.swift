//
//  EventChannelHandler.swift
//  Runner
//
//  Created by 李放 on 2025/9/1.
//

import Foundation
import Flutter
import CoreBluetooth

/// Handles event channel communication between Flutter and native iOS code.
/// Manages Bluetooth device discovery, connection states, and event streaming to Flutter.
/// Listens for Bluetooth-related notifications and converts them into events for Flutter consumption.
class EventChannelHandler: NSObject, FlutterStreamHandler {
    private weak var flutterViewController: FlutterViewController?
    private var scanState: ScanState = .idle
    private static let DELAY_EXIT_TIME: Double = 0.5 // 延迟时间500毫秒
    private static let DELAY_EXIT_LONG_TIME: Double = 30.0 // 延迟时间30秒
    public var eventSink: FlutterEventSink?
    public var btEnityList: [Any] = []
    
    /// Scanning state enumeration
    enum ScanState {
        case scanning
        case foundDevice
        case idle
    }
    
    /// Connection state enumeration
    enum ConnectionState: Int {
        case disconnected = 0
        case connected = 1
        case failed = 2
        case connecting = 3
    }
    
    /// Initializes the event channel handler
    /// - Parameter flutterViewController: The Flutter view controller
    init(flutterViewController: FlutterViewController?) {
        self.flutterViewController = flutterViewController
        super.init()
        initData()
    }
    
    // MARK: - Initialization Methods
    
    private func initData() {
        //DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            // Initialize notification observers
            NotificationCenter.default.addObserver(self, selector: #selector(self.handleAllNotifications(_:)), name: nil, object: nil)
            self.btEnityList = []
            self.sendScanDeviceListToFlutter()
        //}
    }
    
    // MARK: - BLE Operations
    /// Send scan device list to flutter
    func sendScanDeviceListToFlutter() {
        if !JLBleHandler.share().handleGetBleStatus() {
            //sendEvent("ble_not_open", data: nil)
            return
        }
        
        // Set scanning state
        scanState = .scanning
        sendScanDeviceList(scanState: .scanning)
    }
    
    // MARK: - Notification Handling
    @objc private func handleAllNotifications(_ notification: Notification) {
        let name = notification.name.rawValue
        
//        if ToolsHelper.isConnectBySDK() {
//            btEnityList.removeAll()
//        }
        
        if !ToolsHelper.isConnectBySDK() {
            // Custom connection mode notification handling
            if name == kFLT_BLE_FOUND {
                // 清空现有设备列表
                btEnityList.removeAll()
                
                if let bleArray = notification.object as? [JLBleEntity] {
                    // Add to list
                    for entity in bleArray {
                        if !btEnityList.contains(where: { ($0 as! JLBleEntity).mPeripheral.identifier == entity.mPeripheral.identifier }){
                            btEnityList.append(entity)
                        }
                    }
                    
                    // Sort by signal strength
                    btEnityList.sort { (entity1, entity2) -> Bool in
                        let rssi1 = (entity1 as! JLBleEntity).mRSSI.intValue
                        let rssi2 = (entity2 as! JLBleEntity).mRSSI.intValue
                        return rssi1 > rssi2
                    }
                    
                    // Add connected device to the beginning of the list
                    if let currentEntity = JLBleManager.sharedInstance().currentEntity, !btEnityList.contains(where: { ($0 as! JLBleEntity).mPeripheral.identifier == currentEntity.mPeripheral.identifier }) {
                        btEnityList.insert(currentEntity, at: 0)
                    }
                    
                    sendScanDeviceList(scanState: .foundDevice)
                }
            } else if name == kFLT_BLE_CONNECTED || name == kFLT_BLE_DISCONNECTED || name == kJL_BLE_M_OFF {
                if(name == kFLT_BLE_CONNECTED) {
                    sendEvent(EventChannelConstants.TYPE_DEVICE_CONNECTION, data: [
                        EventChannelConstants.KEY_STATE: ConnectionState.connected.rawValue])
                }else {
                    JLBleManager.sharedInstance().currentEntity = nil
                    sendEvent(EventChannelConstants.TYPE_DEVICE_CONNECTION, data: [
                        EventChannelConstants.KEY_STATE: ConnectionState.disconnected.rawValue])
                }
                sendScanDeviceList(scanState: .idle)
            } else if name == kFLT_BLE_PAIRED {
                if let peripheral = notification.object as? CBPeripheral {
                    JLLogManager.logLevel(.DEBUG, content: "FTL BLE Paired ---> \(peripheral.name ?? "") UUID:\(peripheral.identifier.uuidString)")
                    sendScanDeviceList(scanState: .idle)
                    
                    // Get device information
                    DispatchQueue.main.asyncAfter(deadline: .now() + EventChannelHandler.DELAY_EXIT_TIME) {
                        JLBleManager.sharedInstance().getDeviceInfo { needForcedUpgrade in
                            if needForcedUpgrade {
                                self.sendEvent(EventChannelConstants.TYPE_MANDATORY_UPGRADE, data: [
                                    EventChannelConstants.KEY_IS_REQUIRED: true
                                ])
//                                if let flutterViewController = UIApplication.shared.keyWindow?.rootViewController as? FlutterViewController {
//                                    let localizedText = DFUITools.languageText("need_upgrade_now" as String, table: "Localizable")
//                                    DFUITools.showText(localizedText, on: flutterViewController.view, delay: 1.0)
//                                    return
//                                }
                            }
                        }
                    }
                }
            }
        } else {
            // SDK connection mode notification handling
            if name == kJL_BLE_M_FOUND {
                if let entities = notification.object as? [JL_EntityM] {
                    // 清空现有设备列表
                    btEnityList.removeAll()
                    
                    // 将通知中的设备对象赋值给设备列表
                    btEnityList = entities
                    
                    // 如果有已配对设备且不在列表中，插入到首位
                    if let entity = JL_RunSDK.sharedInstance().mBleEntityM {
                        if entity.mBLE_IS_PAIRED {
                            let btEnityListArray = self.btEnityList as? [JL_EntityM] ?? []
                            if !btEnityListArray.contains(entity) {
                                self.btEnityList.insert(entity, at: 0)
                            }
                        }
                    }
                    
                    // 发送扫描到的设备列表
                    sendScanDeviceList(scanState: .foundDevice)
                }
            } else if name == kJL_BLE_M_ENTITY_CONNECTED {
                if let cpb = notification.object as? CBPeripheral {
                    let connectedList = JL_RunSDK.sharedInstance().mBleMultiple.bleConnectedArr
                    for entity in connectedList {
                        if (entity as AnyObject).mPeripheral.identifier.uuidString == cpb.identifier.uuidString {
                            JL_RunSDK.sharedInstance().mBleEntityM = entity as? JL_EntityM
                            break
                        }
                    }
                    
                    // Get device information
                    DispatchQueue.main.asyncAfter(deadline: .now() + EventChannelHandler.DELAY_EXIT_TIME) {
                        JL_RunSDK.sharedInstance().getDeviceInfo { needForcedUpgrade in
                            if needForcedUpgrade {
                                self.sendEvent(EventChannelConstants.TYPE_MANDATORY_UPGRADE, data: [
                                    EventChannelConstants.KEY_IS_REQUIRED: true
                                ])
//                                if let flutterViewController = UIApplication.shared.keyWindow?.rootViewController as? FlutterViewController {
//                                    let localizedText = DFUITools.languageText("need_upgrade_now" as String, table: "Localizable")
//                                    DFUITools.showText(localizedText, on: flutterViewController.view, delay: 1.0)
//                                    return
//                                }
                            }
                        }
                    }
                    
                    sendEvent(EventChannelConstants.TYPE_DEVICE_CONNECTION, data: [
                        EventChannelConstants.KEY_STATE: ConnectionState.connected.rawValue])
                    sendScanDeviceList(scanState: .idle)
                }
            } else if name == kJL_BLE_M_ENTITY_DISCONNECTED || name == kJL_BLE_M_OFF {
                sendScanDeviceList(scanState: .idle)
                sendEvent(EventChannelConstants.TYPE_DEVICE_CONNECTION, data: [
                    EventChannelConstants.KEY_STATE: ConnectionState.disconnected.rawValue])
            }
        }
        
        if(name == kJL_BLE_M_ENTITY_CONNECTED
           || name == kFLT_BLE_CONNECTED
           || name == kFLT_BLE_DISCONNECTED
           || name == kJL_BLE_M_ENTITY_DISCONNECTED || name == kJL_BLE_M_OFF){
            checkDeviceConnectState()
        }
    }
    
    private func checkDeviceConnectState() {
        var isConnected = false
        var deviceType = ""
        
        isConnected = JLBleHandler.share().isConnected()
        deviceType = JLBleHandler.deviceType()
        
        // 发送OTA连接状态事件
        sendEvent(EventChannelConstants.TYPE_OTA_CONNECTION, data: [
            EventChannelConstants.KEY_STATE: isConnected ? ConnectionState.connected.rawValue : ConnectionState.disconnected.rawValue,
            EventChannelConstants.KEY_DEVICE_TYPE: deviceType
        ])
    }
    
    /// Sends scanned device list event to Flutter
    private func sendScanDeviceList(scanState: ScanState) {
        let scanStateStr: String
        switch scanState {
        case .scanning:
            scanStateStr = EventChannelConstants.SCAN_STATE_SCANNING
        case .foundDevice:
            scanStateStr = EventChannelConstants.SCAN_STATE_FOUND_DEV
        case .idle:
            scanStateStr = EventChannelConstants.SCAN_STATE_IDLE
        }
        
        sendEvent(EventChannelConstants.TYPE_SCAN_DEVICE_LIST, data: [
            EventChannelConstants.KEY_STATE: scanStateStr,
            EventChannelConstants.KEY_LIST: convertDeviceListToDictionary()
        ])
        
        DispatchQueue.main.asyncAfter(deadline: .now() + EventChannelHandler.DELAY_EXIT_LONG_TIME) { // 30-second scan timeout
            self.sendScanDeviceList(scanState: .idle)
        }
    }
    
    /// Gets device description with RSSI and MAC address
    private func getDeviceDesc(_ device: Any) -> String {
        if let entity = device as? JLBleEntity {
            let formattedMac = formatMacAddress(entity.edrMacAddress)
            return String(format: "rssi: %d, address: %@", entity.mRSSI.intValue, formattedMac)
        } else if let entity = device as? JL_EntityM {
            let formattedMac = formatMacAddress(entity.mEdr)
            return String(format: "rssi: %d, address: %@", entity.mRSSI.intValue, formattedMac)
        }
        return "N/A"
    }
    
    /// Formats MAC address to colon-separated uppercase format
    private func formatMacAddress(_ macAddress: String) -> String {
        // Return empty string if MAC address is empty
        guard !macAddress.isEmpty else {
            return ""
        }
        
        // Remove all non-hex characters (keep letters and numbers)
        let cleanedMac = macAddress.uppercased().filter { "0123456789ABCDEF".contains($0) }
        
        // Ensure correct length (MAC address should be 12 characters)
        guard cleanedMac.count == 12 else {
            return macAddress // Return original if length is incorrect
        }
        
        // Insert colon every two characters
        var formattedMac = ""
        for (index, char) in cleanedMac.enumerated() {
            if index > 0 && index % 2 == 0 {
                formattedMac += ":"
            }
            formattedMac += String(char)
        }
        
        return formattedMac
    }
    
    /// Gets device name
    private func getDeviceName(_ device: Any) -> String {
        if let entity = device as? JLBleEntity {
            return entity.mPeripheral.name ?? "N/A"
        } else if let entity = device as? JL_EntityM {
            return entity.mPeripheral.name ?? "N/A"
        }
        return "N/A"
    }
    
    /// Gets device connection status
    private func getDeviceStatus(_ device: Any) -> Bool {
        if let entity = device as? JLBleEntity {
            return entity.mPeripheral.state == .connected
        } else if let entity = device as? JL_EntityM {
            return entity.mPeripheral.state == .connected
        }
        return false
    }
    
    /// Converts device list to dictionary format for Flutter consumption
    private func convertDeviceListToDictionary() -> [[String: Any]] {
        var deviceList: [[String: Any]] = []
        
        for item in btEnityList {
            let deviceInfo: [String: Any] = [
                EventChannelConstants.KEY_NAME: getDeviceName(item),
                EventChannelConstants.KEY_DESC: getDeviceDesc(item),
                EventChannelConstants.KEY_STATUS: getDeviceStatus(item)
            ]
            
            deviceList.append(deviceInfo)
        }
        
        return deviceList
    }
    
    /// Sends event to Flutter via event channel
    public func sendEvent(_ eventName: String, data: Any?) {
        let eventData: [String: Any] = [
            EventChannelConstants.KEY_TYPE: eventName,
            EventChannelConstants.KEY_VALUE: data ?? NSNull()
        ]
        eventSink?(eventData)
    }
    
    // MARK: - FlutterStreamHandler Protocol Implementation
    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        eventSink = events
        return nil
    }
    
    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        eventSink = nil
        return nil
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        btEnityList.removeAll()
    }
}
