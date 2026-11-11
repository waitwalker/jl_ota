#if !SWIFT_PACKAGE || !targetEnvironment(simulator)
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
    private static let DELAY_EXIT_TIME: Double = 0.5 // Delay time 500 milliseconds
    private static let DELAY_EXIT_LONG_TIME: Double = 30.0 // Delay time 30 seconds
    private static let GATT_OVER_EDR = "GATT over EDR"
    
    // Thread safety
    private let serialQueue = DispatchQueue(label: "com.eventchannel.serial")
    
    // Track async tasks for cleanup
    private var pendingWorkItems: [DispatchWorkItem] = []
    private var currentScanTimeoutWorkItem: DispatchWorkItem?
    
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
    override init() {
        super.init()
        initData()
    }
        
    private func initData() {
        setupNotificationObservers()
        self.btEnityList = []
    }
    
    private func setupNotificationObservers() {
        let notificationNames: [Notification.Name] = [
            Notification.Name(kFLT_BLE_FOUND),
            Notification.Name(kFLT_BLE_CONNECTED),
            Notification.Name(kFLT_BLE_DISCONNECTED),
            Notification.Name(kFLT_BLE_PAIRED),
            Notification.Name(kJL_BLE_M_FOUND),
            Notification.Name(kJL_BLE_M_ENTITY_CONNECTED),
            Notification.Name(kJL_BLE_M_ENTITY_DISCONNECTED),
            Notification.Name(kJL_BLE_M_OFF),
            Notification.Name(kFLT_BLE_CONNECT_FAILED)
        ]
        
        for name in notificationNames {
            NotificationCenter.default.addObserver(self, selector: #selector(self.handleAllNotifications(_:)), name: name, object: nil)
        }
    }
        
    /// Send scan device list to flutter
    func notifyScanStopped() {
        cancelCurrentScanTimeout()
        sendScanDeviceList(scanState: .idle)
    }

    func sendScanDeviceListToFlutter() {
        if !JLBleHandler.share().handleGetBleStatus() {
            return
        }
        
        sendScanDeviceList(scanState: .scanning)
    }
        
    @objc private func handleAllNotifications(_ notification: Notification) {
        let name = notification.name.rawValue
        if name == kFLT_BLE_CONNECT_FAILED {
            handleConnectFailed()
            return
        }
        
        if !ToolsHelper.isConnectBySDK() {
            // Custom connection mode notification handling
            if name == kFLT_BLE_FOUND {
                handleCustomModeDeviceFound(notification)
            } else if name == kFLT_BLE_CONNECTED || name == kFLT_BLE_DISCONNECTED || name == kJL_BLE_M_OFF {
                handleCustomModeConnectionChange(name)
            } else if name == kFLT_BLE_PAIRED {
                handleCustomModePaired(notification)
            }
        } else {
            // SDK connection mode notification handling
            if name == kJL_BLE_M_FOUND {
                handleSDKModeDeviceFound(notification)
            } else if name == kJL_BLE_M_ENTITY_CONNECTED {
                handleSDKModeConnected(notification)
            } else if name == kJL_BLE_M_ENTITY_DISCONNECTED || name == kJL_BLE_M_OFF {
                handleSDKModeDisconnected()
            }
        }
        
        if(name == kJL_BLE_M_ENTITY_CONNECTED
           || name == kFLT_BLE_CONNECTED
           || name == kFLT_BLE_DISCONNECTED
           || name == kJL_BLE_M_ENTITY_DISCONNECTED || name == kJL_BLE_M_OFF){
            checkDeviceConnectState()
        }
    }
        
    private func handleCustomModeDeviceFound(_ notification: Notification) {
        serialQueue.sync {
            processCustomModeDeviceFound(notification)
        }
        sendScanDeviceList(scanState: .foundDevice)
    }

    private func processCustomModeDeviceFound(_ notification: Notification) {
        guard let bleArray = notification.object as? [JLBleEntity] else { return }
        
        btEnityList.removeAll()
        addUniqueDevices(from: bleArray)
        sortDevicesByRSSI()
        ensureCurrentDeviceAtTop()
    }

    private func addUniqueDevices(from devices: [JLBleEntity]) {
        for entity in devices {
            if !deviceExists(entity) {
                btEnityList.append(entity)
            }
        }
    }

    private func deviceExists(_ entity: JLBleEntity) -> Bool {
        return btEnityList.contains { item in
            guard let existingEntity = item as? JLBleEntity else { return false }
            return existingEntity.mPeripheral.identifier == entity.mPeripheral.identifier
        }
    }

    private func sortDevicesByRSSI() {
        btEnityList.sort { item1, item2 in
            guard let entity1 = item1 as? JLBleEntity,
                  let entity2 = item2 as? JLBleEntity else { return false }
            return entity1.mRSSI.intValue > entity2.mRSSI.intValue
        }
    }

    private func ensureCurrentDeviceAtTop() {
        guard let currentEntity = JLBleManager.sharedInstance().currentEntity else { return }
        
        let exists = btEnityList.contains { item in
            guard let existingEntity = item as? JLBleEntity else { return false }
            return existingEntity.mPeripheral.identifier == currentEntity.mPeripheral.identifier
        }
        
        if !exists {
            btEnityList.insert(currentEntity, at: 0)
        }
    }
    
    private func handleCustomModeConnectionChange(_ name: String) {
        if(name == kFLT_BLE_CONNECTED) {
            sendEvent(EventChannelConstants.TYPE_DEVICE_CONNECTION, data: [
                EventChannelConstants.KEY_STATE: ConnectionState.connected.rawValue])
        } else {
            JLBleManager.sharedInstance().currentEntity = nil
            sendEvent(EventChannelConstants.TYPE_DEVICE_CONNECTION, data: [
                EventChannelConstants.KEY_STATE: ConnectionState.disconnected.rawValue])
        }
        sendScanDeviceList(scanState: .idle)
    }
    
    private func handleCustomModePaired(_ notification: Notification) {
        guard let peripheral = notification.object as? CBPeripheral else {
            return
        }
        
        JLLogManager.logLevel(.DEBUG, content: "FTL BLE Paired ---> \(peripheral.name ?? "") UUID:\(peripheral.identifier.uuidString)")
        sendScanDeviceList(scanState: .idle)
        
        let workItem = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            JLBleManager.sharedInstance().getDeviceInfo { [weak self] needForcedUpgrade in
                guard let self = self else { return }
                if needForcedUpgrade {
                    self.sendEvent(EventChannelConstants.TYPE_MANDATORY_UPGRADE, data: [
                        EventChannelConstants.KEY_IS_REQUIRED: true
                    ])
                }
                // 设备信息查询完成后再带上真实 deviceType，宿主据此开始 OTA。
                self.checkDeviceConnectState(deviceInfoReady: true)
            }
        }
        addPendingWorkItem(workItem)
        DispatchQueue.main.asyncAfter(deadline: .now() + EventChannelHandler.DELAY_EXIT_TIME, execute: workItem)
    }
        
    private func handleSDKModeDeviceFound(_ notification: Notification) {
        guard let entities = notification.object as? [JL_EntityM] else {
            return
        }
        
        serialQueue.sync {
            performDeviceListUpdate(with: entities)
        }
        
        sendScanDeviceList(scanState: .foundDevice)
    }

    private func performDeviceListUpdate(with entities: [JL_EntityM]) {
        resetDeviceList(with: entities)
        addGattOverEdrDevices()
        addAuthenticatedDevices()
    }

    private func resetDeviceList(with newEntities: [JL_EntityM]) {
        btEnityList.removeAll()
        btEnityList = newEntities
    }

    private func addGattOverEdrDevices() {
        guard ToolsHelper.isGattOverEdr() else { return }
        
        let cbperipherals = JL_RunSDK.sharedInstance().mBleMultiple.bleAttDevices
        
        for peripheral in cbperipherals {
            guard !isExitInListUnsafe(peripheral) else { continue }
            
            let newEntity = createGattOverEdrEntity(from: peripheral)
            btEnityList.insert(newEntity, at: 0)
        }
    }

    /// 创建 GATT over EDR 设备实体
    private func createGattOverEdrEntity(from peripheral: CBPeripheral) -> JL_EntityM {
        let newEntity = JL_EntityM()
        newEntity.setBlePeripheral(peripheral)
        newEntity.mEdr = EventChannelHandler.GATT_OVER_EDR
        return newEntity
    }

    private func addAuthenticatedDevices() {
        guard let entity = JL_RunSDK.sharedInstance().mBleEntityM else { return }
        guard entity.mIsAuth else { return }
        guard !isExitInListUnsafe(entity.mPeripheral) else { return }
        
        btEnityList.insert(entity, at: 0)
    }
    
    private func handleSDKModeConnected(_ notification: Notification) {
        guard let cpb = notification.object as? CBPeripheral else {
            return
        }
        
        let connectedList = JL_RunSDK.sharedInstance().mBleMultiple.bleConnectedArr
        for entity in connectedList {
            if (entity as AnyObject).mPeripheral.identifier.uuidString == cpb.identifier.uuidString {
                JL_RunSDK.sharedInstance().mBleEntityM = entity as? JL_EntityM
                break
            }
        }
        
        let workItem = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            JL_RunSDK.sharedInstance().getDeviceInfo { [weak self] needForcedUpgrade in
                guard let self = self else { return }
                if needForcedUpgrade {
                    self.sendEvent(EventChannelConstants.TYPE_MANDATORY_UPGRADE, data: [
                        EventChannelConstants.KEY_IS_REQUIRED: true
                    ])
                }
                self.checkDeviceConnectState(deviceInfoReady: true)
            }
        }
        addPendingWorkItem(workItem)
        DispatchQueue.main.asyncAfter(deadline: .now() + EventChannelHandler.DELAY_EXIT_TIME, execute: workItem)
        
        sendEvent(EventChannelConstants.TYPE_DEVICE_CONNECTION, data: [
            EventChannelConstants.KEY_STATE: ConnectionState.connected.rawValue])
        sendScanDeviceList(scanState: .idle)
    }
    
    private func handleSDKModeDisconnected() {
        sendScanDeviceList(scanState: .idle)
        sendEvent(EventChannelConstants.TYPE_DEVICE_CONNECTION, data: [
            EventChannelConstants.KEY_STATE: ConnectionState.disconnected.rawValue])
    }
    
    /// GATT 刚连上时 deviceType 固定为 unKnow。设备信息回调之后再发真实类型，宿主才开始 OTA。
    private func checkDeviceConnectState(deviceInfoReady: Bool = false) {
        let isConnected = JLBleHandler.share().isConnected()
        let deviceType = (isConnected && deviceInfoReady) ? JLBleHandler.deviceType() : JLBleHandler.unknownDeviceType
        
        sendEvent(EventChannelConstants.TYPE_OTA_CONNECTION, data: [
            EventChannelConstants.KEY_STATE: isConnected ? ConnectionState.connected.rawValue : ConnectionState.disconnected.rawValue,
            EventChannelConstants.KEY_DEVICE_TYPE: deviceType
        ])
    }

    private func handleConnectFailed() {
        sendEvent(EventChannelConstants.TYPE_DEVICE_CONNECTION, data: [
            EventChannelConstants.KEY_STATE: ConnectionState.failed.rawValue
        ])
        sendEvent(EventChannelConstants.TYPE_OTA_CONNECTION, data: [
            EventChannelConstants.KEY_STATE: ConnectionState.failed.rawValue,
            EventChannelConstants.KEY_DEVICE_TYPE: JLBleHandler.unknownDeviceType
        ])
    }
    
    /// Sends scanned device list event to Flutter
    private func sendScanDeviceList(scanState: ScanState) {
        let scanStateStr = scanStateString(from: scanState)
        let deviceList = convertDeviceListToDictionary()
        
        sendScanEvent(state: scanStateStr, deviceList: deviceList)
        handleScanTimeoutIfNeeded(scanState: scanState)
    }

    // MARK: - Private Helpers

    private func scanStateString(from scanState: ScanState) -> String {
        switch scanState {
        case .scanning:
            return EventChannelConstants.SCAN_STATE_SCANNING
        case .foundDevice:
            return EventChannelConstants.SCAN_STATE_FOUND_DEV
        case .idle:
            return EventChannelConstants.SCAN_STATE_IDLE
        }
    }

    private func sendScanEvent(state: String, deviceList: [[String: Any]]) {
        sendEvent(
            EventChannelConstants.TYPE_SCAN_DEVICE_LIST,
            data: [
                EventChannelConstants.KEY_STATE: state,
                EventChannelConstants.KEY_LIST: deviceList
            ]
        )
    }

    private func handleScanTimeoutIfNeeded(scanState: ScanState) {
        guard scanState == .scanning else {
            if scanState == .idle {
                cancelCurrentScanTimeout()
            }
            return
        }
        
        cancelCurrentScanTimeout()
        scheduleScanTimeout()
    }

    private func cancelCurrentScanTimeout() {
        currentScanTimeoutWorkItem?.cancel()
    }

    private func scheduleScanTimeout() {
        let workItem = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            JLBleHandler.share().handleStopScanDevice()
            self.sendScanDeviceList(scanState: .idle)
        }
        
        currentScanTimeoutWorkItem = workItem
        addPendingWorkItem(workItem)
        
        DispatchQueue.main.asyncAfter(
            deadline: .now() + EventChannelHandler.DELAY_EXIT_LONG_TIME,
            execute: workItem
        )
    }
    
    /// Gets device description with RSSI and MAC address
    private func getDeviceDesc(_ device: Any) -> String {
        if let entity = device as? JLBleEntity {
            let address = getDeviceAddress(edrMac: entity.edrMacAddress, peripheral: entity.mPeripheral)
            let rssiValue = entity.mRSSI.intValue
            return String(format: "rssi: %d, address: %@", rssiValue, address)
        } else if let entity = device as? JL_EntityM {
            let address = getDeviceAddress(edrMac: entity.mEdr, peripheral: entity.mPeripheral)
            let rssiValue = entity.mRSSI.intValue
            return String(format: "rssi: %d, address: %@", rssiValue, address)
        }
        return ""
    }

    /// 获取设备地址：优先使用格式化后的 EDR MAC，为空时回退到 peripheral UUID
    private func getDeviceAddress(edrMac: String, peripheral: CBPeripheral) -> String {
        let formatted = formatMacAddress(edrMac)
        if !formatted.isEmpty {
            return formatted
        }
        // iOS 不暴露真实 MAC 地址，使用 CBPeripheral.identifier 作为设备唯一标识
        return peripheral.identifier.uuidString
    }
    
    /// Formats MAC address to colon-separated uppercase format
    private func formatMacAddress(_ macAddress: String) -> String {
        guard !macAddress.isEmpty else { return "" }
        
        let cleanedMac = macAddress.uppercased().filter { "0123456789ABCDEF".contains($0) }
        guard cleanedMac.count == 12 else { return "" }
        
        let chunks = stride(from: 0, to: cleanedMac.count, by: 2).map {
            let start = cleanedMac.index(cleanedMac.startIndex, offsetBy: $0)
            let end = cleanedMac.index(start, offsetBy: 2)
            return String(cleanedMac[start..<end])
        }
        return chunks.joined(separator: ":")
    }
    
    private func getPeripheral(from device: Any) -> CBPeripheral? {
        switch device {
        case let entity as JLBleEntity:
            return entity.mPeripheral
        case let entity as JL_EntityM:
            return entity.mPeripheral
        default:
            return nil
        }
    }

    /// Gets device name
    private func getDeviceName(_ device: Any) -> String {
        return getPeripheral(from: device)?.name ?? ""
    }

    /// Gets device connection status
    private func getDeviceStatus(_ device: Any) -> Bool {
        return getPeripheral(from: device)?.state == .connected
    }

    /// Converts device list to dictionary format for Flutter consumption
    private func convertDeviceListToDictionary() -> [[String: Any]] {
        var deviceList: [[String: Any]] = []
        
        // Thread-safe read
        serialQueue.sync {
            for item in btEnityList {
                let deviceInfo: [String: Any] = [
                    EventChannelConstants.KEY_NAME: getDeviceName(item),
                    EventChannelConstants.KEY_DESC: getDeviceDesc(item),
                    EventChannelConstants.KEY_STATUS: getDeviceStatus(item)
                ]
                deviceList.append(deviceInfo)
            }
        }
        
        return deviceList
    }
    
    private func isExitInListUnsafe(_ peripheral: CBPeripheral) -> Bool {
        let targetUUID = peripheral.identifier.uuidString
        return btEnityList.contains { item in
            guard let entity = item as? JL_EntityM else { return false }
            return entity.mPeripheral.identifier.uuidString == targetUUID
        }
    }

    func isExitInList(_ peripheral: CBPeripheral) -> Bool {
        var result = false
        serialQueue.sync {
            result = isExitInListUnsafe(peripheral)
        }
        return result
    }
        
    /// Sends event to Flutter via event channel
    public func sendEvent(_ eventName: String, data: Any?) {
        let eventData: [String: Any] = [
            EventChannelConstants.KEY_TYPE: eventName,
            EventChannelConstants.KEY_VALUE: data ?? NSNull()
        ]
        
        // Ensure we're on main thread for Flutter communication
        if Thread.isMainThread {
            eventSink?(eventData)
        } else {
            DispatchQueue.main.async { [weak self] in
                self?.eventSink?(eventData)
            }
        }
    }
        
    private func addPendingWorkItem(_ item: DispatchWorkItem) {
        serialQueue.async { [weak self] in
            self?.pendingWorkItems.append(item)
        }
    }
        
    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        eventSink = events
        OtaManager.shared.setEventSink(sink: events)
        return nil
    }
    
    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        eventSink = nil
        OtaManager.shared.setEventSink(sink: nil)
        return nil
    }
    
    func cancelAllPendingWork() {
        serialQueue.async { [self] in
            pendingWorkItems.forEach { $0.cancel() }
            pendingWorkItems.removeAll()
            currentScanTimeoutWorkItem?.cancel()
            currentScanTimeoutWorkItem = nil
        }
    }
        
    deinit {
        cancelAllPendingWork()
        NotificationCenter.default.removeObserver(self)
        
        serialQueue.sync {
            btEnityList.removeAll()
        }
        
        eventSink = nil
    }
}

#endif
