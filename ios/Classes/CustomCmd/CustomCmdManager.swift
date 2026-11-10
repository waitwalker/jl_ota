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
    
    // Error Messages
    static let invalidArgumentsMessage = "Invalid arguments"
    static let invalidDataTypeMessage = "Custom data should be a byte array"
    static let emptyDataMessage = "Custom data is empty"
    static let sendFailedMessage = "Status: "
    
    // Response
    static let ackResponse = "ACK"
}

@objc public class CustomCmdManager: NSObject, JLCustomCmdPtl{
    @objc public static let shared = CustomCmdManager()
    private var eventSink: FlutterEventSink?

    private lazy var customMgr: JL_CustomManager? = {
        let mCustomManager = JL_RunSDK.sharedInstance().mBleEntityM?.mCmdManager.mCustomManager
        return mCustomManager
    }()
    
    override init() {
        super.init()
        initState()
    }
    
    private func initState() {
        customMgr?.delegate = self
    }
    
    @objc public func setEventSink(sink: FlutterEventSink?) {
        self.eventSink = sink
        if customMgr?.delegate == nil {
            customMgr?.delegate = self
        }
    }

    public func send(data: Data, result: @escaping FlutterResult) {
        if data.isEmpty {
            result(FlutterError(code: CustomCmdConstants.emptyData,
                                message: CustomCmdConstants.emptyDataMessage,
                                details: nil))
            return
        }
        customMgr?.cmdCustomData(data, isNeedResponse: true, result: { [weak self] status, _, responseData in
            guard self != nil else { return }
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
        customMgr?.delegate = nil
        eventSink = nil
    }
}

#endif
