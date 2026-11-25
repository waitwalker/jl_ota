#if !SWIFT_PACKAGE || !targetEnvironment(simulator)
//
//  JLBleManager.swift
//  JL_OTA
//
//  Created by 凌煊峰 on 2021/10/11.
//

import Foundation
import CoreBluetooth
import UIKit
import DFUnits
import JL_OTALib
import JL_HashPair
import JL_AdvParse
import JLLogHelper

private let SENDBYSINGLE = false // true: Send via signal detection false: Send by directly writing data
private let GATT_OVER_EDR_DEVICE = "GATT over EDR Device"

@objc protocol JLBleManagerOtaDelegate: NSObjectProtocol {
    /**
     *  ota升级过程状态回调
     */
    @objc(otaProgressWithOtaResult:withProgress:)
    func otaProgress(with result: JL_OTAResult, withProgress progress: Float)
}

@objc class JLBleManager: HandleBroadcastPtl,
    CBCentralManagerDelegate,
    CBPeripheralDelegate,
    JL_OTAManagerDelegate,
    JLHashHandlerDelegate,
    SingleSendDelegate
{

    @objc var mBleManagerState: CBManagerState = .unknown
    @objc var mBlePeripheral: CBPeripheral?

    /// 连接蓝牙是否需要认证配对
    @objc var isPaired: Bool = true

    /// 配对秘钥（默认为空）
    @objc var pairKey: Data?

    /// 连接设备的MTU（单次最大发送数据）
    @objc var bleMtu: Int = 0

    /// 上一次连接的蓝牙UUID
    @objc var lastUUID: String = ""

    /// 上一次连接的蓝牙地址
    @objc var lastBleMacAddress: String?

    @objc var otaManager: JL_OTAManager

    @objc var isConnected: Bool = false

    @objc var currentEntity: JLBleEntity?

    private var bleManager: CBCentralManager!
    private var pairHash: JLHashHandler
    private var pairStatus: Bool = false

    private var blePeripheralArr: [JLBleEntity] = []
    private var bleCurrentPeripheral: CBPeripheral?
    private var mService: CBService?
    private var mRcspWrite: CBCharacteristic?
    private var mRcspRead: CBCharacteristic?

    private var selectedOtaFilePath: String?
    private var connectByUUID: String?

    public typealias GET_DEVICE_CALLBACK = (Bool) -> Void
    public typealias CANCEL_CALLBACK = (UInt8) -> Void

    private var getCallback: GET_DEVICE_CALLBACK?
    private var cbuuidArray: [CBUUID]

    private static let singleton = JLBleManager()

    /**
     * 单例
     */
    @objc class func sharedInstance() -> JLBleManager {
        return singleton
    }

    override init() {
        otaManager = JL_OTAManager.getOTAManager()
        pairHash = JLHashHandler()
        cbuuidArray = [CBUUID(string: FLT_BLE_SERVICE)]
        super.init()

        isPaired = true
        pairStatus = false

        bleManager = CBCentralManager(delegate: self, queue: nil)

        /*--- JLSDK ADD ---*/
        JL_OTAManager.logSDKVersion()
        JLHashHandler.sdkVersion()
        otaManager.logSendData(false)
        otaManager.delegate = self

        pairHash.delegate = self
        connectByUUID = nil

        if SENDBYSINGLE {
            SingleDataSender.share().addDelegate(self)
        }
    }

    // MARK: - Device Scanning

    @objc func startScanBLE() {
        JLLogManager.logLevel(.DEBUG, content: "BLE ---> startScanBLE.")
        blePeripheralArr = []
        guard let bleManager = bleManager else { return }
        if bleManager.state == .poweredOn {
            scanGattOverEdr()
            bleManager.scanForPeripherals(withServices: nil, options: nil)
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                guard let self = self else { return }
                if self.bleManager.state == .poweredOn {
                    self.scanGattOverEdr()
                    self.bleManager.scanForPeripherals(withServices: nil, options: nil)
                }
            }
        }
    }

    private func scanGattOverEdr() {
        if ToolsHelper.isGattOverEdr() {
            registerForGattOverEdr()
        } else {
            unregisterForGattOverEdr()
        }
    }

    private func registerForGattOverEdr() {
        guard let uuidStrs = ToolsHelper.getGattServiceUUIDs() as? [String],
              !uuidStrs.isEmpty else {
            return
        }
        let uuids = convertToCBUUIDArray(uuidStrs)
        guard !uuids.isEmpty else { return }
        registerConnectionEvents(withUUIDs: uuids)
    }

    private func unregisterForGattOverEdr() {
        registerConnectionEvents(withUUIDs: nil)
    }

    private func convertToCBUUIDArray(_ uuidStrs: [String]) -> [CBUUID] {
        return uuidStrs.map { CBUUID(string: $0) }
    }

    private func registerConnectionEvents(withUUIDs cbuuidArray: [CBUUID]?) {
        if #available(iOS 13.0, *) {
            var matchingOptions: [CBConnectionEventMatchingOption: Any]? = nil
            if let cbuuidArray = cbuuidArray, !cbuuidArray.isEmpty {
                matchingOptions = [.serviceUUIDs: cbuuidArray]
            }
            bleManager.registerForConnectionEvents(options: matchingOptions)
        } else {
            JLLogManager.logLevel(.WARN, content: "BLE ---> registerForConnectionEventsWithOptions is not available before iOS 13.")
        }
    }

    @objc func stopScanBLE() {
        bleManager?.stopScan()
    }

    // MARK: - BLE Device Connection

    @objc func disconnectBLE() {
        if let peripheral = bleCurrentPeripheral {
            JLLogManager.logLevel(.DEBUG, content: "BLE --->To disconnectBLE.")
            bleManager.cancelPeripheralConnection(peripheral)
            isConnected = false
            currentEntity = nil
        }
    }

    @objc func connectBLE(_ peripheral: CBPeripheral) {
        if let current = bleCurrentPeripheral {
            bleManager.cancelPeripheralConnection(current)
        }
        bleCurrentPeripheral = peripheral
        bleCurrentPeripheral?.delegate = self
        bleManager.connect(
            peripheral,
            options: [CBConnectPeripheralOptionNotifyOnDisconnectionKey: true]
        )
        bleManager.stopScan()

        JLLogManager.logLevel(.DEBUG, content: "BLE Connecting... Name ---> \(peripheral.name ?? "")")
    }

    @objc(connectPeripheralWithUUID:)
    func connectPeripheral(withUUID uuid: String) {
        connectByUUID = uuid
        startScanBLE()
    }

    @objc func findHid(_ uuid: String) {
        guard let uuidNs = UUID(uuidString: uuid) else { return }
        let array = bleManager.retrievePeripherals(withIdentifiers: [uuidNs])
        for cbp in array {
            if cbp.identifier.uuidString == uuid {
                JLLogManager.logLevel(.DEBUG, content: "reconnect:\(cbp)")
                connectBLE(cbp)
                break
            }
        }
    }

    private func connectAction() {
        guard let connectUUID = connectByUUID,
              let uuid = UUID(uuidString: connectUUID) else { return }
        let phArr = bleManager.retrievePeripherals(withIdentifiers: [uuid])
        guard let peripheral = phArr.first else { return }

        if peripheral.state != .connected && peripheral.state != .connecting {
            let bleName = peripheral.name ?? ""
            let bleUuid = peripheral.identifier.uuidString
            JLLogManager.logLevel(.DEBUG, content: "FLT Connecting(Last)... Name ---> \(bleName) UUID:\(bleUuid)")

            bleCurrentPeripheral = peripheral
            bleCurrentPeripheral?.delegate = self
            bleManager.connect(
                peripheral,
                options: [CBConnectPeripheralOptionNotifyOnDisconnectionKey: true]
            )
            connectByUUID = nil
        }
    }

    // MARK: - CBCentralManagerDelegate

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        mBleManagerState = central.state

        if mBleManagerState != .poweredOn {
            mBlePeripheral = nil
            blePeripheralArr = []
        }
    }

    func centralManager(
        _ central: CBCentralManager,
        connectionEventDidOccur event: CBConnectionEvent,
        for peripheral: CBPeripheral
    ) {
        if event == .peerConnected {
            JLLogManager.logLevel(.DEBUG, content: "BLE ---> connectionEventDidOccur.")
            if ToolsHelper.isGattOverEdr() {
                let bleEntity = JLBleEntity()
                bleEntity.mName = peripheral.name ?? "Unknow"
                bleEntity.edrMacAddress = GATT_OVER_EDR_DEVICE
                bleEntity.mPeripheral = peripheral
                blePeripheralArr.append(bleEntity)
                if peripheral.identifier.uuidString == connectByUUID {
                    connectBLE(peripheral)
                    connectByUUID = nil
                }
            }
        } else if event == .peerDisconnected {
            JLLogManager.logLevel(.DEBUG, content: "BLE ---> connectionEventDidOccur disconnect:\(peripheral)")
        }
    }

    func centralManager(
        _ central: CBCentralManager,
        didDiscover peripheral: CBPeripheral,
        advertisementData: [String: Any],
        rssi RSSI: NSNumber
    ) {
        let advName = advertisementData["kCBAdvDataLocalName"] as? String ?? ""
        let bleName = advName.isEmpty ? (peripheral.name ?? "") : advName
        let bleAD = advertisementData["kCBAdvDataManufacturerData"] as? Data
        let info = JLAdvParse.bluetoothAdvParse(pairKey, advData: advertisementData)

        if !bleName.isEmpty {
            JLLogManager.logLevel(.DEBUG, content: "Found ----> NAME:\(bleName) RSSI:\(RSSI) AD:\(String(describing: bleAD))")
            addPeripheral(peripheral, rssi: RSSI, name: bleName, info: info)
            NotificationCenter.default.post(
                name: Notification.Name(kFLT_BLE_FOUND),
                object: blePeripheralArr,
                userInfo: nil
            )
        }

        // Reconnection during OTA upgrade process still runs when the local name is empty.
        if let mac = lastBleMacAddress,
           let adData = bleAD,
           JLAdvParse.otaBleMacAddress(mac, isEqualToCBAdvDataManufacturerData: adData) {
            connectBLE(peripheral)
        }
    }

    private func addPeripheral(
        _ peripheral: CBPeripheral,
        rssi: NSNumber,
        name: String,
        info: [AnyHashable: Any]
    ) {
        var flag = 0
        let bleUuid = peripheral.identifier.uuidString
        for bleEntity in blePeripheralArr {
            let infoUuid = bleEntity.mPeripheral.identifier.uuidString
            if infoUuid == bleUuid {
                bleEntity.mRSSI = rssi
                flag = 1
                break
            }
        }
        if flag == 0 && !name.isEmpty {
            let bleEntity = JLBleEntity()
            bleEntity.mName = name.isEmpty ? "Unknow" : name
            bleEntity.mRSSI = rssi
            let typeVal = (info["TYPE"] as? NSNumber)?.intValue ?? 0
            bleEntity.mType = typeVal
            bleEntity.edrMacAddress = (info["EDR"] as? String) ?? ""
            JLLogManager.logLevel(.DEBUG, content: "type:\(typeVal),name:\(name), uuid:\(bleUuid)")
            bleEntity.mPeripheral = peripheral
            blePeripheralArr.append(bleEntity)
        }
        if let connectUUID = connectByUUID, bleUuid == connectUUID {
            stopScanBLE()
            connectAction()
        }
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        JLLogManager.logLevel(.DEBUG, content: "BLE Connected ---> Device \(peripheral.name ?? "")")
        for entity in blePeripheralArr {
            if entity.mPeripheral.identifier.uuidString == peripheral.identifier.uuidString {
                currentEntity = entity
                break
            }
        }
        isConnected = true

        otaManager.mBLE_NAME = peripheral.name ?? ""
        otaManager.mBLE_UUID = peripheral.identifier.uuidString

        DFNotice.post(kFLT_BLE_CONNECTED, object: peripheral)
        // Discover services after successful connection
        peripheral.discoverServices(nil)
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        JLLogManager.logLevel(
            .DEBUG,
            content: "Err:BLE Connect FAIL ---> Device:\(peripheral.name ?? "") Error:\(String(describing: error))"
        )
        isConnected = false
        currentEntity = nil
        pairStatus = false
        NotificationCenter.default.post(name: Notification.Name(kFLT_BLE_CONNECT_FAILED), object: peripheral)
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        let errCode = (error as NSError?)?.code ?? 0
        JLLogManager.logLevel(.DEBUG, content: "BLE Disconnect ---> Device \(peripheral.name ?? "") error:\(errCode)")

        otaManager.noteEntityDisconnected()
        isConnected = false
        pairStatus = false
        /*--- UI refresh, device disconnected ---*/
        NotificationCenter.default.post(name: Notification.Name(kFLT_BLE_DISCONNECTED), object: peripheral)
    }

    // MARK: - CBPeripheralDelegate

    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if error != nil {
            JLLogManager.logLevel(.DEBUG, content: "Err: Discovered services fail.")
            return
        }
        mBlePeripheral = peripheral
        for service in peripheral.services ?? [] {
            JLLogManager.logLevel(.DEBUG, content: "BLE Service ---> \(service.uuid.uuidString)")
            peripheral.discoverCharacteristics(nil, for: service)
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if error != nil {
            JLLogManager.logLevel(.DEBUG, content: "Err: Discovered Characteristics fail.")
            return
        }

        if service.uuid.uuidString == FLT_BLE_SERVICE {
            for character in service.characteristics ?? [] {
                if character.uuid.uuidString == FLT_BLE_RCSP_W {
                    JLLogManager.logLevel(.DEBUG, content: "BLE Get Rcsp(Write) Channel ---> \(character.uuid.uuidString)")
                    mRcspWrite = character
                }

                if character.uuid.uuidString == FLT_BLE_RCSP_R {
                    JLLogManager.logLevel(.DEBUG, content: "BLE Get Rcsp(Read) Channel ---> \(character.uuid.uuidString)")
                    mRcspRead = character
                    peripheral.setNotifyValue(true, for: character)

                    if character.properties == .read {
                        peripheral.readValue(for: character)
                        JLLogManager.logLevel(.DEBUG, content: "BLE  Rcsp(Read) Read Value For Characteristic.")
                    }
                }
            }
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        if error != nil {
            JLLogManager.logLevel(.DEBUG, content: "Err: Update NotificationState For Characteristic fail.")
            return
        }

        if characteristic.service?.uuid.uuidString == FLT_BLE_SERVICE &&
            characteristic.uuid.uuidString == FLT_BLE_RCSP_R &&
            characteristic.isNotifying {

            bleMtu = peripheral.maximumWriteValueLength(for: .withoutResponse)
            JLLogManager.logLevel(.DEBUG, content: "BLE ---> MTU:\(bleMtu)")
            if isPaired {
                pairHash.hashResetPair()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                    guard let self = self else { return }
                    // Device authentication
                    self.pairHash.bluetoothPairingKey(self.pairKey) { [weak self] ret in
                        guard let self = self else { return }
                        if ret {
                            if self.lastBleMacAddress == nil {
                                self.lastUUID = peripheral.identifier.uuidString
                            }
                            JLLogManager.logLevel(.DEBUG, content: "bluetooth pairing success. UUID:\(self.lastUUID)")
                            self.lastBleMacAddress = nil
                            NotificationCenter.default.post(name: Notification.Name(kFLT_BLE_PAIRED), object: peripheral)
                            self.otaManager.noteEntityConnected()
                            self.pairStatus = true
                        } else {
                            JLLogManager.logLevel(.DEBUG, content: "JL_Assist Err: bluetooth pairing fail.")
                            self.bleManager.cancelPeripheralConnection(peripheral)
                        }
                    }
                }
            } else {
                if lastBleMacAddress == nil {
                    lastUUID = peripheral.identifier.uuidString
                }
                JLLogManager.logLevel(.DEBUG, content: "bluetooth pairing success. UUID:\(lastUUID)")
                lastBleMacAddress = nil
                NotificationCenter.default.post(name: Notification.Name(kFLT_BLE_PAIRED), object: peripheral)
                otaManager.noteEntityConnected()
            }
        }
        isConnected = true
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if error != nil {
            JLLogManager.logLevel(.DEBUG, content: "Err: receive data fail.")
            return
        }

        guard let value = characteristic.value else { return }
        if isPaired && !pairStatus {
            // Receive authentication handshake data from device
            pairHash.inputPairData(value)
        } else {
            // Received device data for normal communication
            otaManager.cmdOtaDataReceive(value)
        }
    }

    func peripheralIsReady(toSendWriteWithoutResponse peripheral: CBPeripheral) {
        if SENDBYSINGLE {
            SingleDataSender.share().sendSingle()
        }
    }

    // MARK: - Jieli Bluetooth Library OTA Process Related Business

    @objc func getDeviceInfo(_ callback: @escaping GET_DEVICE_CALLBACK) {
        getCallback = callback
        otaManager.cmdTargetFeature()
    }

    @objc(otaFuncWithFilePath:)
    func otaFunc(withFilePath otaFilePath: String) {
        JLLogManager.logLevel(.DEBUG, content: "current otaFilePath ---> \(otaFilePath)")
        selectedOtaFilePath = otaFilePath
        guard let otaData = try? Data(contentsOf: URL(fileURLWithPath: otaFilePath)) else {
            dispatchOtaProgress(.failErrorFile, progress: 0)
            return
        }

        otaManager.cmdOTAData(otaData) { [weak self] result, progress in
            self?.dispatchOtaProgress(result, progress: progress)
        }
    }

    @objc(otaFuncWithFilePathInner:)
    func otaFuncWithFilePathInner(_ otaFilePath: String) {
        JLLogManager.logLevel(.DEBUG, content: "current otaFilePath Inner ---> \(otaFilePath)")
        selectedOtaFilePath = otaFilePath
        guard let otaData = try? Data(contentsOf: URL(fileURLWithPath: otaFilePath)) else {
            dispatchOtaProgress(.failErrorFile, progress: 0)
            return
        }

        let option = JLOtaReConnectOption.default()
        option.serviceUUID = "AE00"
        otaManager.cmdUpgrade(otaData, option: option) { [weak self] result, progress in
            self?.dispatchOtaProgress(result, progress: progress)
        }
    }

    private func dispatchOtaProgress(_ result: JL_OTAResult, progress: Float) {
        for case let delegate as JLBleManagerOtaDelegate in delegates.allObjects {
            delegate.otaProgress(with: result, withProgress: progress)
        }
    }

    private func finishDeviceInfo(_ needForce: Bool) {
        let callback = getCallback
        getCallback = nil
        callback?(needForce)
    }

    @objc func otaFuncCancel(_ result: @escaping CANCEL_CALLBACK) {
        otaManager.cmdOTACancelResult { status, _, _ in
            result(status)
        }
    }

    // MARK: - OTA Manager Delegate Callback

    func otaCancel() {
        // OTA upgrade cancellation callback
    }

    func otaUpgradeResult(_ result: JL_OTAResult, progress: Float) {
        for case let delegate as JLBleManagerOtaDelegate in delegates.allObjects {
            delegate.otaProgress(with: result, withProgress: progress)
        }
    }

    func otaDataSend(_ data: Data) {
        writeDataByCbp(data)
    }

    func otaFeatureResult(_ manager: JL_OTAManager) {
        JLLogManager.logLevel(.DEBUG, content: "getDeviceInfo:\(#line)")
        if manager.otaStatus == .force {
            if manager.isSupportReuseSpaceOTA {
                if manager.otaSourceMode == .sourcesExtendModeNormal
                    || manager.otaSourceMode == .sourcesExtendModeDisable {
                    if manager.bootloaderType == .YES {
                        JLLogManager.logLevel(.DEBUG, content: "---> Entering Loader upgrade.")
                    } else {
                        JLLogManager.logLevel(.DEBUG, content: "---> Entering resource upgrade.")
                    }
                }
                JLLogManager.logLevel(
                    .DEBUG,
                    content: "---> Current mode is: otaSourceMode: \(manager.otaSourceMode.rawValue), bootloaderType: \(manager.bootloaderType.rawValue)"
                )
            }
            if let selectedPath = selectedOtaFilePath {
                otaFunc(withFilePath: selectedPath)
            }
            finishDeviceInfo(true)
            return
        } else {
            if manager.otaHeadset == .YES {
                if let selectedPath = selectedOtaFilePath {
                    otaFunc(withFilePath: selectedPath)
                }
                finishDeviceInfo(true)
                return
            }
            if manager.otaSourceMode == .sourcesExtendModeFirmwareOnly {
                if let selectedPath = selectedOtaFilePath {
                    otaFunc(withFilePath: selectedPath)
                }
                finishDeviceInfo(true)
                return
            }
        }
        DispatchQueue.main.async { [weak self] in
            self?.otaManager.cmdSystemFunction()
            self?.finishDeviceInfo(false)
        }
    }

    // MARK: - Hash Pair Delegate Callback

    func hash(onPairOutputData data: Data) {
        writeDataByCbp(data)
    }

    // MARK: - Data Send Manager

    private func writeDataByCbp(_ data: Data) {
        guard mBlePeripheral != nil, mRcspWrite != nil else {
            JLLogManager.logLevel(.DEBUG, content: "need to init")
            return
        }
        guard !data.isEmpty, bleMtu > 0 else { return }

        var remaining = data
        while !remaining.isEmpty {
            if remaining.count <= bleMtu {
                selectSendAction(remaining)
                break
            } else {
                let mtuData = remaining.subdata(in: 0..<bleMtu)
                selectSendAction(mtuData)
                remaining = remaining.subdata(in: bleMtu..<remaining.count)
            }
        }
    }

    private func selectSendAction(_ data: Data) {
        if SENDBYSINGLE {
            SingleDataSender.share().appendSend(data)
        } else {
            if let peripheral = mBlePeripheral, let writeChar = mRcspWrite {
                peripheral.writeValue(data, for: writeChar, type: .withoutResponse)
            }
        }
    }

    // MARK: - Send via Signal Detection

    func singleDidSendData(_ data: Data) {
        if let peripheral = mBlePeripheral, let writeChar = mRcspWrite {
            peripheral.writeValue(data, for: writeChar, type: .withoutResponse)
        }
    }
}

#endif

