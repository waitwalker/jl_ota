#if !SWIFT_PACKAGE || !targetEnvironment(simulator)
//
//  JL_RunSDK.swift
//  JL_OTA_InnerBle
//
//  Created by 凌煊峰 on 2021/10/9.
//

import Foundation
import CoreBluetooth
import JL_BLEKit
import DFUnits
import JL_OTALib
import JLLogHelper

let SMALL_V = "v"
let BIG_V = "V"
let OTA_UPGRADE = "upgrade"

@inline(__always)
func kJL_TXT(_ key: String) -> String {
    return DFUITools.languageText(key, table: "Localizable")
}

@objc protocol JL_RunSDKOtaDelegate: NSObjectProtocol {
    /**
     *  ota升级过程状态回调
     */
    @objc(otaProgressWithOtaResult:withProgress:)
    func otaProgress(with result: JL_OTAResult, withProgress progress: Float)
}

@objc class JL_RunSDK: NSObject, JL_ManagerMDelegate {

    @objc var mBleMultiple: JL_BLEMultiple
    @objc weak var mBleEntityM: JL_EntityM?
    @objc weak var otaDelegate: JL_RunSDKOtaDelegate?
    @objc var lastUUID: String = ""

    private var selectedOtaFilePath: String?
    private var connectUUID: String?

    private static let singleton = JL_RunSDK()

    /**
     * 单例
     */
    @objc class func sharedInstance() -> JL_RunSDK {
        return singleton
    }

    @objc class func textEntityStatus(_ status: JL_EntityM_Status) -> String {
        if status.rawValue < 0 {
            return kJL_TXT("unknown_error")
        }
        let arr: [String] = [
            kJL_TXT("bluetooth_off"),
            kJL_TXT("bt_connect_failed"),
            kJL_TXT("device_connecting"),
            kJL_TXT("repeated_connection"),
            kJL_TXT("connect_timeout"),
            kJL_TXT("reject_by_device"),
            kJL_TXT("paire_failed"),
            kJL_TXT("paire_timeout"),
            kJL_TXT("paire_ok"),
            kJL_TXT("master_slave_switch"),
            kJL_TXT("disconnect_success"),
            kJL_TXT("open_bluetooth")
        ]
        let idx = Int(status.rawValue)
        if idx + 1 <= arr.count {
            return arr[idx]
        } else {
            return kJL_TXT("unknown_error")
        }
    }

    override init() {
        mBleMultiple = JL_BLEMultiple()
        super.init()
        /*--- 初始化JL_SDK ---*/
        mBleMultiple.ble_FILTER_ENABLE = true
        mBleMultiple.ble_PAIR_ENABLE = true
        mBleMultiple.ble_TIMEOUT = 7
        connectUUID = nil
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(noteListen(_:)),
            name: nil,
            object: nil
        )
    }

    @objc private func noteListen(_ note: Notification) {
        guard let connectUUID = self.connectUUID else { return }
        let name = note.name.rawValue
        if name == kJL_BLE_M_FOUND {
            guard let itemsArray = note.object as? [JL_EntityM] else { return }
            for entity in itemsArray {
                if entity.mPeripheral.identifier.uuidString == connectUUID {
                    mBleMultiple.scanStop()
                    self.connectUUID = nil
                    mBleMultiple.connectEntity(entity) { [weak self] status in
                        if status == .paired {
                            self?.mBleEntityM = entity
                            return
                        }
                        JL_RunSDK.sharedInstance().notifyIfConnectFailed(status, peripheral: entity.mPeripheral)
                    }
                }
            }
        }
    }

    @objc func startLoopConnect(_ uuid: String) {
        connectUUID = uuid
        mBleMultiple.scanStart()
    }

    /// 连接回调里除配对成功和仍在连接中的状态外，通知 Flutter 连接失败。
    func notifyIfConnectFailed(_ status: JL_EntityM_Status, peripheral: CBPeripheral?) {
        switch status {
        case .paired, .connecting, .masterChanging, .connectRepeat:
            return
        default:
            NotificationCenter.default.post(name: Notification.Name(kFLT_BLE_CONNECT_FAILED), object: peripheral)
        }
    }

    @objc func getEntity(_ uuid: String) -> JL_EntityM? {
        guard let mConnectArr = mBleMultiple.bleConnectedArr as? [JL_EntityM] else {
            return nil
        }
        for entity in mConnectArr {
            let inUnid = entity.mPeripheral.identifier.uuidString
            if uuid == inUnid {
                return entity
            }
        }
        return nil
    }

    @objc func handelDeviceInfo() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.getDeviceInfo { _ in }
        }
    }

    // MARK: - 杰理蓝牙库OTA流程相关业务

    public typealias GET_DEVICE_CALLBACK = (Bool) -> Void

    /**
     *  获取已连接的蓝牙设备信息，这里如果上次设备升级没有成功，会要求执行otaFuncWithFilePath:强制升级
     */
    @objc func getDeviceInfo(_ callback: @escaping GET_DEVICE_CALLBACK) {
        guard let entity = mBleEntityM else {
            callback(false)
            return
        }
        /*--- 获取设备信息 ---*/
        entity.mCmdManager.cmdTargetFeatureResult { [weak self] status, _, _ in
            guard let self = self else {
                callback(false)
                return
            }
            if status == .success {
                guard let otaManager = self.mBleEntityM?.mCmdManager.mOTAManager else {
                    callback(false)
                    return
                }
                let upSt = otaManager.otaSourceMode
                if otaManager.otaStatus == .force {
                    if otaManager.isSupportReuseSpaceOTA {
                        if otaManager.otaSourceMode == .sourcesExtendModeNormal
                            || otaManager.otaSourceMode == .sourcesExtendModeDisable {
                            if otaManager.bootloaderType == .YES {
                                JLLogManager.logLevel(.DEBUG, content: "---> Entering Loader upgrade.")
                            } else {
                                JLLogManager.logLevel(.DEBUG, content: "---> Entering resource upgrade.")
                            }
                        }
                    } else {
                        JLLogManager.logLevel(.DEBUG, content: "---> Entering forced upgrade.")
                    }
                    if let selectedPath = self.selectedOtaFilePath {
                        self.otaFunc(withFilePath: selectedPath)
                    }
                    callback(true)
                    return
                } else {
                    if otaManager.otaHeadset == .YES {
                        if let selectedPath = self.selectedOtaFilePath {
                            self.otaFunc(withFilePath: selectedPath)
                        }
                        callback(true)
                        return
                    }
                    if upSt == .sourcesExtendModeFirmwareOnly {
                        if let selectedPath = self.selectedOtaFilePath {
                            self.otaFunc(withFilePath: selectedPath)
                        }
                        callback(true)
                        return
                    }
                }
                JL_Tools.mainTask { [weak self] in
                    /*--- 获取公共信息 ---*/
                    self?.mBleEntityM?.mCmdManager.cmdGetSystemInfo(.COMMON, result: nil)
                    callback(false)
                }
            } else {
                JLLogManager.logLevel(.DEBUG, content: "---> ERROR: Device information retrieval error!")
                callback(false)
            }
        }
    }

    /**
     *  OTA升级
     */
    @objc(otaFuncWithFilePath:)
    func otaFunc(withFilePath otaFilePath: String) {
        JLLogManager.logLevel(.DEBUG, content: "current otaFilePath ---> \(otaFilePath)")
        selectedOtaFilePath = otaFilePath
        guard let entity = mBleEntityM else {
            otaDelegate?.otaProgress(with: .fail, withProgress: 0)
            return
        }
        guard FileManager.default.fileExists(atPath: otaFilePath) else {
            otaDelegate?.otaProgress(with: .failErrorFile, withProgress: 0)
            return
        }
        mBleMultiple.otaFunc(with: entity, withFilePath: otaFilePath) { [weak self] result, progress in
            self?.otaDelegate?.otaProgress(with: result, withProgress: progress)
        }
    }
}

#endif

