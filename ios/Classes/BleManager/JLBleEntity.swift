#if !SWIFT_PACKAGE || !targetEnvironment(simulator)
//
//  JLBleEntity.swift
//  JL_OTA
//
//  Created by 凌煊峰 on 2021/10/11.
//

import Foundation
import CoreBluetooth

/// 蓝牙设备模型
@objc class JLBleEntity: NSObject, NSCopying {

    private var _mPeripheral: CBPeripheral?

    @objc var mRSSI: NSNumber = 0
    @objc var mPeripheral: CBPeripheral {
        get { _mPeripheral! }
        set { _mPeripheral = newValue }
    }
    @objc var mName: String = ""
    @objc var bleMacAddress: String = ""
    @objc var edrMacAddress: String = ""
    /// 广播设备类型。传统设备为 -1，不能用 UInt8 保存。
    @objc var mType: Int = 0
    @objc var pid: UInt16 = 0
    @objc var uid: UInt16 = 0

    func copy(with zone: NSZone? = nil) -> Any {
        let entity = JLBleEntity()
        entity.mRSSI = self.mRSSI
        entity.mPeripheral = self.mPeripheral
        entity.mName = self.mName
        entity.bleMacAddress = self.bleMacAddress
        entity.edrMacAddress = self.edrMacAddress
        entity.pid = self.pid
        entity.uid = self.uid
        entity.mType = self.mType
        return entity
    }
}

#endif

