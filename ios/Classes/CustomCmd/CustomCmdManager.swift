#if !SWIFT_PACKAGE || !targetEnvironment(simulator)
//
//  CustomCmdManager.swift
//  Pods
//
//  Created by 李放 on 2026/5/20.
//

import Foundation
import Flutter

// MARK: - CustomCmdConstants
private enum CustomCmdConstants {
    // Error Codes
    static let invalidArguments = "INVALID_ARGUMENTS"
    static let invalidDataType = "INVALID_DATA_TYPE"
    static let emptyData = "EMPTY_DATA"
    static let sendFailed = "SEND_FAILED"
    static let notConnected = "NOT_CONNECTED"
    
    // Error Messages
    static let invalidArgumentsMessage = "Invalid arguments"
    static let invalidDataTypeMessage = "Custom data should be a byte array"
    static let emptyDataMessage = "Custom data is empty"
    static let sendFailedMessage = "Status: "
    static let notConnectedMessage = "Custom command needs an authenticated SDK Bluetooth connection"
    
    // Response
    static let ackResponse = "ACK"
}

@objc public class CustomCmdManager: NSObject, JLCustomCmdPtl{
    @objc public static let shared = CustomCmdManager()
    private var eventSink: FlutterEventSink?
    private weak var boundManager: JL_CustomManager?
    
    override init() {
        super.init()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleConnectionReady),
            name: Notification.Name(kFLT_BLE_PAIRED),
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleConnectionReady),
            name: Notification.Name(kJL_BLE_M_ENTITY_CONNECTED),
            object: nil
        )
    }

    private func currentCustomManager() -> JL_CustomManager? {
        JL_RunSDK.sharedInstance().mBleEntityM?.mCmdManager.mCustomManager
    }

    private func bindDelegate() {
        let manager = currentCustomManager()
        if boundManager !== manager {
            if boundManager?.delegate === self {
                boundManager?.delegate = nil
            }
            manager?.delegate = self
            boundManager = manager
        } else if manager?.delegate == nil {
            manager?.delegate = self
        }
    }

    @objc private func handleConnectionReady() {
        bindDelegate()
    }
    
    @objc public func setEventSink(sink: FlutterEventSink?) {
        self.eventSink = sink
        bindDelegate()
    }

    public func send(data: Data, result: @escaping FlutterResult) {
        if data.isEmpty {
            result(FlutterError(code: CustomCmdConstants.emptyData,
                                message: CustomCmdConstants.emptyDataMessage,
                                details: nil))
            return
        }
        bindDelegate()
        guard let customMgr = currentCustomManager() else {
            result(FlutterError(code: CustomCmdConstants.notConnected,
                                message: CustomCmdConstants.notConnectedMessage,
                                details: nil))
            return
        }
        customMgr.cmdCustomData(data, isNeedResponse: true, result: { status, _, responseData in
            if status == JL_CMDStatus.success {
                if let responseData {
                    JLLogManager.logLevel(.DEBUG, content: "response data: \(responseData.count) bytes")
                }
                result(nil)
            } else {
                result(FlutterError(code: CustomCmdConstants.sendFailed,
                                   message: CustomCmdConstants.sendFailedMessage + "\(status.rawValue)",
                                   details: nil))
            }
        })
    }
    
    private func sendEventToFlutter(type: String, data: [String: Any]) {
        DispatchQueue.main.async {
            self.eventSink?([
                EventChannelConstants.KEY_TYPE: type,
                EventChannelConstants.KEY_VALUE: data
            ])
        }
    }

    private func sendCustomDataUpdate(data: Data) {
        let byteArray = [UInt8](data)
        let customData: [String: Any] = [
            "customData": byteArray
        ]
        sendEventToFlutter(type: "customDataUpdate", data: customData)
    }
    
    // MARK: - JLCustomCmdPtl Protocol Methods
    public func customCmdResponse(_ manager: JL_ManagerM, status: UInt8, with data: Data) {
        sendCustomDataUpdate(data: data)
    }

    public func customCmdRequire(_ manager: JL_ManagerM, with data: Data, isNeedResponse: Bool, sn: UInt8) {
        if isNeedResponse {
            if let responseData = CustomCmdConstants.ackResponse.data(using: .utf8) {
                manager.mCustomManager.cmdCustomResponse(sn, data: responseData)
            }
        }
    }
    
    public func cleanUp() {
        if boundManager?.delegate === self {
            boundManager?.delegate = nil
        }
        boundManager = nil
        eventSink = nil
    }
}

#endif
