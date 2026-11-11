#if !SWIFT_PACKAGE || !targetEnvironment(simulator)
//
//  JLBleHandler.swift
//  JL_OTA
//
//  Created by EzioChan on 2022/10/12.
//  Copyright © 2022 Zhuhia Jieli Technology. All rights reserved.
//

import Foundation
import CoreBluetooth
import JL_BLEKit
import JL_OTALib
import JL_AdvParse
import JLLogHelper

let JL_BLE_CONNECTWAY_CHANGE = "JL_BLE_CONNECTWAY_CHANGE"
let kFLT_BLE_OTA_CALLBACK = "kFLT_BLE_OTA_CALLBACK"

@objc protocol JLBleHandlDelegate: NSObjectProtocol {
    /**
     *  ota升级过程状态回调
     */
    @objc(otaProgressOtaResult:withProgress:)
    func otaProgressOtaResult(_ result: JL_OTAResult, withProgress progress: Float)
}

@objc class JLBleHandler: NSObject, JLBleManagerOtaDelegate, JL_RunSDKOtaDelegate {

    private static let kDeviceTypeSoundBox = "sound box"
    private static let kDeviceTypeChargingBin = "charging box"
    private static let kDeviceTypeTWS = "TWS"
    private static let kDeviceTypeHeadset = "headset"
    private static let kDeviceTypeSoundCard = "sound card"
    private static let kDeviceTypeWatch = "watch"
    private static let kDeviceTypeTradition = "tradition"
    static let unknownDeviceType = "unKnow"

    private var sdkManager: JL_BLEMultiple!
    private var userManager: JLBleManager!

    @objc weak var delegate: JLBleHandlDelegate? {
        didSet {
            JL_RunSDK.sharedInstance().otaDelegate = self
        }
    }

    private static let handler = JLBleHandler()

    @objc class func share() -> JLBleHandler {
        return handler
    }

    override init() {
        super.init()
        setupManagers()
    }

    private func setupManagers() {
        sdkManager = JL_RunSDK.sharedInstance().mBleMultiple
        JL_RunSDK.sharedInstance().otaDelegate = self
        sdkManager.ble_FILTER_ENABLE = true

        userManager = JLBleManager.sharedInstance()
        userManager.addDelegate(self)
    }

    @objc func isConnected() -> Bool {
        if ToolsHelper.isConnectBySDK() {
            return JL_RunSDK.sharedInstance().mBleEntityM?.mIsAuth ?? false
        } else {
            return JLBleManager.sharedInstance().isConnected
        }
    }

    @objc func handleWeatherNeedUpdate() -> Bool {
        let otaStatus = getCurrentOtaStatus()
        return otaStatus == .force
    }

    private func getCurrentOtaStatus() -> JL_OtaStatus {
        if ToolsHelper.isConnectBySDK() {
            guard let model = JL_RunSDK.sharedInstance().mBleEntityM?.mCmdManager.outputDeviceModel() else {
                return .normal
            }
            return model.otaStatus
        } else {
            return userManager.otaManager.otaStatus
        }
    }

    @objc func handleDeviceNowUUID() -> String? {
        if ToolsHelper.isConnectBySDK() {
            return JL_RunSDK.sharedInstance().mBleEntityM?.mPeripheral.identifier.uuidString
        } else {
            return JLBleManager.sharedInstance().mBlePeripheral?.identifier.uuidString
        }
    }

    @objc func handleGetBleStatus() -> Bool {
        if ToolsHelper.isConnectBySDK() {
            return sdkManager.bleManagerState == .poweredOn
        } else {
            return JLBleManager.sharedInstance().mBleManagerState == .poweredOn
        }
    }

    @objc func handleScanDevice() {
        if ToolsHelper.isConnectBySDK() {
            sdkManager.scanStart()
        } else {
            userManager.startScanBLE()
        }
    }

    @objc func handleStopScanDevice() {
        if ToolsHelper.isConnectBySDK() {
            sdkManager.scanStop()
        } else {
            userManager.stopScanBLE()
        }
    }

    @objc func handleDisconnect() {
        if let entity = JL_RunSDK.sharedInstance().mBleEntityM {
            sdkManager.disconnectEntity(entity) { _ in
                // Disconnect result handled internally
            }
        }
        userManager.disconnectBLE()
    }

    @objc func handleReconnectByMac() {
        if ToolsHelper.isConnectBySDK() {
            let addr = JL_RunSDK.sharedInstance().mBleEntityM?.mBleAddr ?? ""
            JLLogManager.logLevel(.DEBUG, content: "---> OTA SDK attempt to reconnect to the device using its MAC address... \(addr)")
            sdkManager.scanStart()
        } else {
            let addr = userManager.otaManager.bleAddr
            JLLogManager.logLevel(.DEBUG, content: "---> OTA reconnecting via MAC... \(addr)")
            JLBleManager.sharedInstance().lastBleMacAddress = userManager.otaManager.bleAddr
            JLBleManager.sharedInstance().startScanBLE()
        }
    }

    @objc func handleReconnectByUUID() {
        if ToolsHelper.isConnectBySDK() {
            sdkManager.ble_PAIR_ENABLE = ToolsHelper.isSupportPair()
            let item = JL_RunSDK.sharedInstance().mBleEntityM?.mItem ?? ""
            JLLogManager.logLevel(.DEBUG, content: "---> OTA SDK reconnecting device... \(item)")

            if let entity = sdkManager.makeEntity(withUUID: JL_RunSDK.sharedInstance().lastUUID) {
                sdkManager.connectEntity(entity) { _ in
                    // Connection result handled internally
                }
            }
        } else {
            let name = userManager.mBlePeripheral?.name ?? ""
            let uuid = userManager.lastUUID
            JLLogManager.logLevel(.DEBUG, content: "---> OTA SDK reconnecting device by custom ... \(name),\(uuid)")
            userManager.connectPeripheral(withUUID: userManager.lastUUID)
        }
    }

    @objc(handleConnectWithUUID:)
    func handleConnect(withUUID uuid: String) {
        if ToolsHelper.isConnectBySDK() {
            JL_RunSDK.sharedInstance().startLoopConnect(uuid)
        } else {
            userManager.connectPeripheral(withUUID: uuid)
        }
    }

    @objc(handleOtaFuncWithFilePath:)
    func handleOtaFunc(withFilePath otaFilePath: String) {
        guard FileManager.default.fileExists(atPath: otaFilePath) else {
            delegate?.otaProgressOtaResult(.failErrorFile, withProgress: 0)
            return
        }
        if ToolsHelper.isConnectBySDK() {
            JL_RunSDK.sharedInstance().otaFunc(withFilePath: otaFilePath)
        } else {
            JLBleManager.sharedInstance().otaFunc(withFilePath: otaFilePath)
        }
    }

    @objc func handleOtaCancelUpdate(_ block: ((JL_CMDStatus) -> Void)?) {
        guard let block = block else { return }

        if ToolsHelper.isConnectBySDK() {
            cancelOtaUpdateWithSDK(block)
        } else {
            cancelOtaUpdateWithCustomManager(block)
        }
    }

    private func cancelOtaUpdateWithSDK(_ block: @escaping (JL_CMDStatus) -> Void) {
        if let entity = JL_RunSDK.sharedInstance().mBleEntityM {
            entity.mCmdManager.mOTAManager.cmdOTACancelResult { status, _, _ in
                block(JL_CMDStatus(rawValue: status) ?? .fail)
            }
        } else {
            block(.fail)
        }
    }

    private func cancelOtaUpdateWithCustomManager(_ block: @escaping (JL_CMDStatus) -> Void) {
        if JLBleManager.sharedInstance().currentEntity != nil {
            JLBleManager.sharedInstance().otaFuncCancel { status in
                block(JL_CMDStatus(rawValue: status) ?? .fail)
            }
        } else {
            block(.fail)
        }
    }

    @objc class func deviceType() -> String {
        guard let type = getCurrentDeviceType() else {
            return unknownDeviceType
        }
        return stringFromDeviceType(type)
    }

    private class func getCurrentDeviceType() -> JL_DeviceType? {
        if ToolsHelper.isConnectBySDK() {
            return JL_RunSDK.sharedInstance().mBleEntityM?.mType
        }
        guard let rawType = JLBleManager.sharedInstance().currentEntity?.mType else {
            return nil
        }
        return JL_DeviceType(rawValue: rawType)
    }

    private class func stringFromDeviceType(_ type: JL_DeviceType) -> String {
        switch type {
        case .soundBox:
            return kDeviceTypeSoundBox
        case .chargingBin:
            return kDeviceTypeChargingBin
        case .TWS:
            return kDeviceTypeTWS
        case .headset:
            return kDeviceTypeHeadset
        case .soundCard:
            return kDeviceTypeSoundCard
        case .watch:
            return kDeviceTypeWatch
        case .tradition:
            return kDeviceTypeTradition
        default:
            return unknownDeviceType
        }
    }

    @objc(otaProgressWithOtaResult:withProgress:)
    func otaProgress(with result: JL_OTAResult, withProgress progress: Float) {
        delegate?.otaProgressOtaResult(result, withProgress: progress)
    }
}

#endif

