#if !SWIFT_PACKAGE || !targetEnvironment(simulator)
//
//  JLBleAssistManager.swift
//  JL_OTA
//
//  Created by 凌煊峰 on 2021/10/11.
//

import Foundation
import CoreBluetooth
import UIKit
import JL_BLEKit
import DFUnits
import JL_OTALib
import JLLogHelper

// MARK: - BLE状态通知
let kFLT_BLE_FOUND        = "FLT_BLE_FOUND"        // 发现设备
let kFLT_BLE_PAIRED       = "FLT_BLE_PAIRED"       // 已配对
let kFLT_BLE_CONNECTED    = "FLT_BLE_CONNECTED"    // 已连接
let kFLT_BLE_DISCONNECTED = "FLT_BLE_DISCONNECTED" // 断开连接
let kFLT_BLE_CONNECT_FAILED = "FLT_BLE_CONNECT_FAILED" // 连接失败

let FLT_BLE_SERVICE = "AE00" // 服务号
let FLT_BLE_RCSP_W  = "AE01" // 命令“写”通道
let FLT_BLE_RCSP_R  = "AE02" // 命令“读”通道

@objc protocol JLBleAssistManagerOtaDelegate: NSObjectProtocol {
    /**
     *  ota升级过程状态回调
     */
    @objc(otaProgressWithOtaResult:withProgress:)
    func otaProgress(with result: JL_OTAResult, withProgress progress: Float)
}

@objc class JLBleAssistManager: ECOneToMorePtl, CBCentralManagerDelegate, CBPeripheralDelegate {

    @objc var mBleManagerState: CBManagerState = .unknown
    @objc var mBlePeripheral: CBPeripheral?
    @objc var isFilter: Bool = true
    @objc var isPaired: Bool = true {
        didSet {
            mAssist.mNeedPaired = isPaired
        }
    }
    @objc var lastUUID: String = ""
    @objc var lastBleMacAddress: String?
    @objc var mAssist: JL_Assist
    @objc var isConnected: Bool = false
    @objc var currentEntity: JLBleEntity?

    private var bleManager: CBCentralManager!
    private var blePeripheralArr: [JLBleEntity] = []
    private var bleCurrentPeripheral: CBPeripheral?
    private var selectedOtaFilePath: String?
    private var connectByUUID: String?

    private static let singleton = JLBleAssistManager()

    /**
     * 单例
     */
    @objc class func sharedInstance() -> JLBleAssistManager {
        return singleton
    }

    override init() {
        mAssist = JL_Assist()
        super.init()
        isFilter = true
        isPaired = true

        bleManager = CBCentralManager(delegate: self, queue: nil)

        /*--- JLSDK ADD ---*/
        mAssist.mNeedPaired = isPaired
        mAssist.mPairKey = nil
        mAssist.mService = FLT_BLE_SERVICE
        mAssist.mRcsp_W = FLT_BLE_RCSP_W
        mAssist.mRcsp_R = FLT_BLE_RCSP_R
        connectByUUID = nil
    }

    // MARK: - 扫描设备相关

    @objc func startScanBLE() {
        JLLogManager.logLevel(.DEBUG, content: "BLE ---> startScanBLE.")
        blePeripheralArr = []
        guard let bleManager = bleManager else { return }
        if bleManager.state == .poweredOn {
            bleManager.scanForPeripherals(withServices: nil, options: nil)
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                if self?.bleManager.state == .poweredOn {
                    self?.bleManager.scanForPeripherals(withServices: nil, options: nil)
                }
            }
        }
    }

    @objc func stopScanBLE() {
        bleManager?.stopScan()
    }

    // MARK: - 蓝牙设备连接相关

    @objc func disconnectBLE() {
        if let peripheral = bleCurrentPeripheral {
            JLLogManager.logLevel(.DEBUG, content: "BLE --->To disconnectBLE.")
            bleManager.cancelPeripheralConnection(peripheral)
            isConnected = false
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
        mAssist.assistUpdate(central.state)

        if mBleManagerState != .poweredOn {
            mBlePeripheral = nil
            blePeripheralArr = []
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

        if !bleName.isEmpty {
            JLLogManager.logLevel(.DEBUG, content: "Found ----> NAME:\(bleName) RSSI:\(RSSI) AD:\(String(describing: bleAD))")
            addDiscoveredPeripheral(peripheral, rssi: RSSI, name: bleName)
            DFNotice.post(kFLT_BLE_FOUND, object: blePeripheralArr)
            if peripheral.identifier.uuidString == connectByUUID {
                stopScanBLE()
                connectAction()
            }
        }

        if let mac = lastBleMacAddress,
           let adData = bleAD,
           JL_BLEAction.otaBleMacAddress(mac, isEqualToCBAdvDataManufacturerData: adData) {
            connectBLE(peripheral)
        }
    }

    private func addDiscoveredPeripheral(_ peripheral: CBPeripheral, rssi: NSNumber, name: String) {
        let bleUuid = peripheral.identifier.uuidString
        if let existing = blePeripheralArr.first(where: { $0.mPeripheral.identifier.uuidString == bleUuid }) {
            existing.mRSSI = rssi
            existing.mName = name
            return
        }
        let bleEntity = JLBleEntity()
        bleEntity.mName = name
        bleEntity.mRSSI = rssi
        bleEntity.mPeripheral = peripheral
        blePeripheralArr.append(bleEntity)
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
        DFNotice.post(kFLT_BLE_CONNECTED, object: peripheral)
        peripheral.discoverServices(nil)
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        JLLogManager.logLevel(
            .DEBUG,
            content: "Err:BLE Connect FAIL ---> Device:\(peripheral.name ?? "") Error:\(String(describing: error))"
        )
        isConnected = false
        currentEntity = nil
        NotificationCenter.default.post(name: Notification.Name(kFLT_BLE_CONNECT_FAILED), object: peripheral)
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        let errCode = (error as NSError?)?.code ?? 0
        JLLogManager.logLevel(.DEBUG, content: "BLE Disconnect ---> Device \(peripheral.name ?? "") error:\(errCode)")
        mBlePeripheral = nil
        mAssist.assistDisconnectPeripheral(peripheral)
        isConnected = false
        JL_Tools.post(kFLT_BLE_DISCONNECTED, object: peripheral)
    }

    // MARK: - CBPeripheralDelegate

    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if error != nil {
            JLLogManager.logLevel(.DEBUG, content: "Err: Discovered services fail.")
            return
        }
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
        mAssist.assistDiscoverCharacteristics(for: service, peripheral: peripheral)
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        if error != nil {
            JLLogManager.logLevel(.DEBUG, content: "Err: Update NotificationState For Characteristic fail.")
            return
        }
        mAssist.assistUpdate(characteristic, peripheral: peripheral) { [weak self] isPaired in
            guard let self = self else { return }
            if isPaired {
                self.lastUUID = peripheral.identifier.uuidString
                self.lastBleMacAddress = nil
                self.mBlePeripheral = peripheral
                JL_Tools.post(kFLT_BLE_PAIRED, object: peripheral)
            } else {
                self.bleManager.cancelPeripheralConnection(peripheral)
            }
            self.isConnected = true
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if error != nil {
            JLLogManager.logLevel(.DEBUG, content: "Err: receive data fail.")
            return
        }
        mAssist.assistUpdateValue(for: characteristic)
    }

    // MARK: - 杰理蓝牙库OTA流程相关业务

    public typealias GET_DEVICE_CALLBACK = (Bool) -> Void

    @objc func getDeviceInfo(_ callback: @escaping GET_DEVICE_CALLBACK) {
        JLLogManager.logLevel(.DEBUG, content: "getDeviceInfo:\(#line)")
        mAssist.mCmdManager.cmdTargetFeatureResult { [weak self] status, _, _ in
            guard let self = self else {
                callback(false)
                return
            }
            JLLogManager.logLevel(.DEBUG, content: "getDeviceInfo:\(#line)")
            if status == .success {
                let model = self.mAssist.mCmdManager.outputDeviceModel()
                if model.otaStatus == .force {
                    JLLogManager.logLevel(.DEBUG, content: "---> Enter force upgrade.")
                    if let selectedPath = self.selectedOtaFilePath {
                        self.otaFunc(withFilePath: selectedPath)
                    }
                    callback(true)
                    return
                } else {
                    if model.otaHeadset == .YES {
                        JLLogManager.logLevel(.DEBUG, content: "---> Enter force upgrade: OTA the other earbud.")
                        if let selectedPath = self.selectedOtaFilePath {
                            self.otaFunc(withFilePath: selectedPath)
                        }
                        callback(true)
                        return
                    }
                }
                JLLogManager.logLevel(.DEBUG, content: "---> The device works fine...")
                JL_Tools.mainTask { [weak self] in
                    self?.mAssist.mCmdManager.cmdGetSystemInfo(.COMMON, result: nil)
                    callback(false)
                }
            } else {
                JLLogManager.logLevel(.DEBUG, content: "---> ERROR：There was an error retrieving the device information!")
                callback(false)
            }
        }
    }

    @objc(otaFuncWithFilePath:)
    func otaFunc(withFilePath otaFilePath: String) {
        JLLogManager.logLevel(.DEBUG, content: "current otaFilePath ---> \(otaFilePath)")
        selectedOtaFilePath = otaFilePath
        guard let otaData = try? Data(contentsOf: URL(fileURLWithPath: otaFilePath)) else {
            for case let delegate as JLBleAssistManagerOtaDelegate in delegates.allObjects {
                delegate.otaProgress(with: .failErrorFile, withProgress: 0)
            }
            return
        }

        let otaManager = mAssist.mCmdManager.mOTAManager
        otaManager.cmdOTAData(otaData) { [weak self] result, progress in
            guard let self = self else { return }
            for case let objc as JLBleAssistManagerOtaDelegate in self.delegates.allObjects {
                objc.otaProgress(with: result, withProgress: progress)
            }
        }
    }
}

#endif

