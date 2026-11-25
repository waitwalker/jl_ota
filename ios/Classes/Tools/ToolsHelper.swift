#if !SWIFT_PACKAGE || !targetEnvironment(simulator)
//
//  ToolsHelper.swift
//  JL_OTA
//
//  Created by EzioChan on 2022/10/10.
//  Copyright © 2022 Zhuhia Jieli Technology. All rights reserved.
//

import Foundation
import DFUnits
import JL_OTALib
import JLLogHelper

@objc enum ProductType: UInt {
    case normal = 0
    case broadcast = 1
}

@objc class ToolsHelper: NSObject {

    private var logTimer: Timer?
    private var targetPath: String = ""
    private var maxSize: Int = 0

    private static let helper = ToolsHelper()

    @objc class func share() -> ToolsHelper {
        return helper
    }

    private func countLogSize() {
        if let data = try? Data(contentsOf: URL(fileURLWithPath: targetPath)),
           data.count > maxSize {
            try? Data().write(to: URL(fileURLWithPath: targetPath), options: .atomic)
        }
    }

    /// 获取是否支持多选
    @objc class func isSupportSelectMore() -> Bool {
        if let val = DFTools.getUserByKey("SupportSelectMore") as? NSNumber {
            return val.boolValue
        } else {
            return false
        }
    }

    /// 设置是否可以多选
    /// - Parameter status: 是否多选
    @objc class func setSupportSelect(_ status: Bool) {
        DFTools.setUser(NSNumber(value: status), forKey: "SupportSelectMore")
    }

    /// 获取是否需要设备认证
    @objc class func isSupportPair() -> Bool {
        if let val = DFTools.getUserByKey("SupportPair") as? NSNumber {
            return val.boolValue
        } else {
            setSupportPair(true)
            return true
        }
    }

    /// 设置是否需要认证
    /// - Parameter status: 是否认证
    @objc class func setSupportPair(_ status: Bool) {
        DFTools.setUser(NSNumber(value: status), forKey: "SupportPair")
    }

    /// 设置是否HID
    /// - Parameter status: 是否HID
    @objc class func setSupportHID(_ status: Bool) {
        DFTools.setUser(NSNumber(value: status), forKey: "SupportHID")
    }

    /// 获取是否HID
    @objc class func isSupportHID() -> Bool {
        if let val = DFTools.getUserByKey("SupportHID") as? NSNumber {
            return val.boolValue
        } else {
            setSupportHID(false)
            return false
        }
    }

    /// 设置是否需要广播音箱过滤
    /// - Parameter status: 是否广播音箱过滤
    @objc class func setBroadcastFitter(_ status: Bool) {
        DFTools.setUser(NSNumber(value: status), forKey: "BroadcastFitter")
    }

    /// 获取是否需要广播音箱过滤
    @objc class func isBroadcastFitter() -> Bool {
        if let val = DFTools.getUserByKey("BroadcastFitter") as? NSNumber {
            return val.boolValue
        } else {
            setBroadcastFitter(true)
            return true
        }
    }

    /// 设置是否开启广播音箱
    /// - Parameter status: 是否广播音箱
    @objc class func setBroadcast(_ status: Bool) {
        DFTools.setUser(NSNumber(value: status), forKey: "Broadcast_tag")
    }

    /// 获取是否开启广播音箱
    @objc class func isBroadcast() -> Bool {
        if let val = DFTools.getUserByKey("Broadcast_tag") as? NSNumber {
            return val.boolValue
        } else {
            setBroadcast(false)
            return false
        }
    }

    /// 是否使用SDK蓝牙连接
    @objc class func isConnectBySDK() -> Bool {
        if let val = DFTools.getUserByKey("ConnectBySDK") as? NSNumber {
            return val.boolValue
        } else {
            setConnectBySDK(false)
            return false
        }
    }

    /// 设置是否使用SDK蓝牙连接
    /// - Parameter status: 是否使用SDK蓝牙连接
    @objc class func setConnectBySDK(_ status: Bool) {
        DFTools.setUser(NSNumber(value: status), forKey: "ConnectBySDK")
    }

    /// 是否使用GATT over EDR连接
    @objc class func isGattOverEdr() -> Bool {
        if let val = DFTools.getUserByKey("GattOverEdr") as? NSNumber {
            return val.boolValue
        } else {
            setGattOverEdr(false)
            return false
        }
    }

    /// 设置是否使用GATT over EDR
    /// - Parameter status: 是否使用GATT over EDR
    @objc class func setGattOverEdr(_ status: Bool) {
        DFTools.setUser(NSNumber(value: status), forKey: "GattOverEdr")
    }

    /// 设置GATT服务UUIDs
    /// - Parameter uuids: UUIDs
    @objc class func setGattServiceUUIDs(_ uuids: [Any]) {
        DFTools.setUser(uuids, forKey: "GattServiceUUIDs")
    }

    /// 获取GATT服务UUIDs
    @objc class func getGattServiceUUIDs() -> [Any]? {
        if let arr = DFTools.getUserByKey("GattServiceUUIDs") as? [Any] {
            return Array(arr)
        } else {
            return nil
        }
    }

    /// 是否启用自动化测试
    @objc class func isAutoTestOta() -> Bool {
        if let val = DFTools.getUserByKey("AutoTestOta") as? NSNumber {
            return val.boolValue
        } else {
            return false
        }
    }

    /// 设置是否启用自动化测试
    /// - Parameter status: 是否自动化测试
    @objc class func setAutoTestOta(_ status: Bool) {
        DFTools.setUser(NSNumber(value: status), forKey: "AutoTestOta")
        setSupportSelect(status)
    }

    /// 自动化测试次数
    @objc class func getAutoTestOtaNumber() -> Int {
        if let val = DFTools.getUserByKey("AutoTestOtaNumber") as? NSNumber {
            let num = val.intValue
            JLLogManager.logLevel(.DEBUG, content: "getAutoTestOtaNumber:\(num)")
            return num
        } else {
            JLLogManager.logLevel(.DEBUG, content: "getAutoTestOtaNumber:1")
            return 1
        }
    }

    /// 设置自动化测试次数
    /// - Parameter number: 次数
    @objc class func setAutoTestOtaNumber(_ number: Int) {
        JLLogManager.logLevel(.DEBUG, content: "setAutoTestOtaNumber:\(number)")
        DFTools.setUser(NSNumber(value: Int32(number)), forKey: "AutoTestOtaNumber")
    }

    /// 设置容错次数
    /// - Parameter status: 状态
    @objc class func setFaultTolerant(_ status: Bool) {
        DFTools.setUser(NSNumber(value: status), forKey: "fault_tolerant")
    }

    /// 获取是否需要容错
    @objc class func getFaultTolerant() -> Bool {
        if let val = DFTools.getUserByKey("fault_tolerant") as? NSNumber {
            return val.boolValue
        } else {
            return false
        }
    }

    /// 获取容错次数
    @objc class func getFaultTolerantTimes() -> Int {
        if let val = DFTools.getUserByKey("fault_tolerant_times") as? NSNumber {
            return val.intValue
        } else {
            return 5
        }
    }

    /// 设置容错次数
    /// - Parameter number: 容错次数
    @objc class func setFaultTolerantTimes(_ number: Int) {
        DFTools.setUser(NSNumber(value: Int32(number)), forKey: "fault_tolerant_times")
    }

    /// 根据错误编码返回字符串
    /// - Parameter result: 错误编号
    @objc class func errorReason(_ result: JL_OTAResult) -> String {
        switch result {
        case .success:
            return kJL_TXT("result_success")
        case .fail:
            return kJL_TXT("result_fail")
        case .dataIsNull:
            return kJL_TXT("result_data_is_null")
        case .commandFail:
            return kJL_TXT("result_command_fail")
        case .seekFail:
            return kJL_TXT("result_seek_fail")
        case .infoFail:
            return kJL_TXT("result_info_fail")
        case .lowPower:
            return kJL_TXT("result_low_power")
        case .enterFail:
            return kJL_TXT("result_enter_fail")
        case .upgrading:
            return kJL_TXT("result_upgrading")
        case .reconnect:
            return kJL_TXT("result_reconnect")
        case .reboot:
            return kJL_TXT("result_reboot")
        case .preparing:
            return kJL_TXT("result_preparing")
        case .prepared:
            return kJL_TXT("result_prepared")
        case .failVerification:
            return kJL_TXT("result_fail_verification")
        case .failCompletely:
            return kJL_TXT("result_fail_completely")
        case .failKey:
            return kJL_TXT("result_fail_key")
        case .failErrorFile:
            return kJL_TXT("result_fail_error_file")
        case .failUboot:
            return kJL_TXT("result_fail_uboot")
        case .failLenght:
            return kJL_TXT("result_fail_lenght")
        case .failFlash:
            return kJL_TXT("result_fail_flash")
        case .failCmdTimeout:
            return kJL_TXT("result_fail_cmd_timeout")
        case .failSameVersion:
            return kJL_TXT("result_fail_same_version")
        case .failTWSDisconnect:
            return kJL_TXT("result_fail_tws_disconnect")
        case .failNotInBin:
            return kJL_TXT("result_fail_not_in_bin")
        case .reconnectWithMacAddr:
            return kJL_TXT("result_reconnect_with_mac_addr")
        case .unknown:
            return kJL_TXT("result_unknown")
        case .disconnect:
            return kJL_TXT("result_disconnect")
        case .failedConnectMore:
            return kJL_TXT("result_failed_connect_more")
        case .statusIsUpdating:
            return kJL_TXT("result_status_is_updating")
        case .failSameSN:
            return kJL_TXT("result_fail_same_sn")
        case .cancel:
            return kJL_TXT("result_cancel")
        case .reconnectUpdateSource:
            return kJL_TXT("result_reconnect_update_source")
        @unknown default:
            return ""
        }
    }

    @objc class func setProductType(_ type: ProductType) {
        DFTools.setUser(NSNumber(value: Int32(type.rawValue)), forKey: "ProductType")
    }

    @objc class func getproductType() -> ProductType {
        if let val = DFTools.getUserByKey("ProductType") as? NSNumber,
           let type = ProductType(rawValue: val.uintValue) {
            return type
        } else {
            return .normal
        }
    }

    @objc class func ufwDataSave(_ data: Data, path url: URL) {
        var fname = url.lastPathComponent
        guard let docDir = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first else {
            return
        }
        let basicPath = (docDir as NSString).appendingPathComponent(OTA_UPGRADE)
        let fm = FileManager.default
        var isDir: ObjCBool = false
        let isDirExist = fm.fileExists(atPath: basicPath, isDirectory: &isDir)

        if !(isDirExist && isDir.boolValue) {
            do {
                try fm.createDirectory(atPath: basicPath, withIntermediateDirectories: true, attributes: nil)
            } catch {
                JLLogManager.logLevel(.DEBUG, content: "Create upgrade Directory Failed.")
            }
        }
        var docPath = (basicPath as NSString).appendingPathComponent(fname)
        if fm.fileExists(atPath: docPath) {
            let arr = fname.components(separatedBy: ".")
            let dfm = DateFormatter()
            dfm.dateFormat = "yyyyMMddHHmmss"
            let newDateStr = dfm.string(from: Date())
            if arr.count >= 2 {
                fname = "\(arr[0])_\(newDateStr).\(arr[1])"
            } else {
                fname = "\(fname)_\(newDateStr)"
            }
        }
        docPath = (basicPath as NSString).appendingPathComponent(fname)
        fm.createFile(atPath: docPath, contents: data, attributes: nil)
    }

    /// 创建存储路径名字
    /// ufw名字
    /// - Parameter fileName: 文件名
    @objc class func targetSavePath(_ fileName: String) -> URL {
        var targetName = fileName
        let docDir = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first ?? ""
        let basicPath = (docDir as NSString).appendingPathComponent(OTA_UPGRADE)
        let fm = FileManager.default
        var isDir: ObjCBool = false
        let isDirExist = fm.fileExists(atPath: basicPath, isDirectory: &isDir)

        if !(isDirExist && isDir.boolValue) {
            do {
                try fm.createDirectory(atPath: basicPath, withIntermediateDirectories: true, attributes: nil)
            } catch {
                JLLogManager.logLevel(.DEBUG, content: "Create upgrade Directory Failed.")
            }
        }
        var docPath = (basicPath as NSString).appendingPathComponent(targetName)
        if fm.fileExists(atPath: docPath) {
            let arr = targetName.components(separatedBy: ".")
            let dfm = DateFormatter()
            dfm.dateFormat = "yyyyMMddHHmmss"
            let newDateStr = dfm.string(from: Date())
            if arr.count >= 2 {
                targetName = "\(arr[0])_\(newDateStr).\(arr[1])"
            } else {
                targetName = "\(targetName)_\(newDateStr)"
            }
        }
        docPath = (basicPath as NSString).appendingPathComponent(targetName)
        return URL(fileURLWithPath: docPath)
    }
}

#endif

