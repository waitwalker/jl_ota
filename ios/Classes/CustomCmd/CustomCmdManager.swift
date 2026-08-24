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

@objc class CustomCmdManager: NSObject, JLCustomCmdPtl{
    @objc static let shared = CustomCmdManager()
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
    
    @objc func setEventSink(sink: FlutterEventSink?) {
        self.eventSink = sink
    }
    
    func handleCustomCmd(call: FlutterMethodCall, result: @escaping FlutterResult){
        switch call.method {
        case MethodChannelConstants.METHOD_SEND_CUSTOM_COMMAND:
            sendCustomCmd(call: call, result: result)
        default:
            result(FlutterMethodNotImplemented)
        }
    }
    
    private func sendCustomCmd(call: FlutterMethodCall, result: @escaping FlutterResult){
        
        guard let arguments = call.arguments as? [String: Any] else {
            result(FlutterError(code: CustomCmdConstants.invalidArguments,
                                message: CustomCmdConstants.invalidArgumentsMessage,
                                details: nil))
            return
        }
        
        guard let flutterData = arguments[MethodChannelConstants.ARG_CUSTOM_DATA] as? FlutterStandardTypedData else {
            result(FlutterError(code: CustomCmdConstants.invalidDataType,
                                message: CustomCmdConstants.invalidDataTypeMessage,
                                details: nil))
            return
        }
        
        let data = flutterData.data
        
        if data.isEmpty {
            result(FlutterError(code: CustomCmdConstants.emptyData,
                                message: CustomCmdConstants.emptyDataMessage,
                                details: nil))
            return
        }
        

        customMgr?.cmdCustomData(data,
                                   isNeedResponse: true,
                                   result: { [weak self] status, sn, responseData in
            guard self != nil else { return }
            
            if status == JL_CMDStatus.success {
                if let responseData = responseData {
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
    
    /// 发送事件到Flutter
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
            EventChannelConstants.KEY_CUSTOM_DATA: byteArray
        ]
        sendEventToFlutter(type:EventChannelConstants.TYPE_CUSTOM_DATA_UPDATE, data: customData)
    }
    
    // MARK: - JLCustomCmdPtl Protocol Methods
    func customCmdResponse(_ manager: JL_ManagerM, status: UInt8, with data: Data) {
        sendCustomDataUpdate(data: data)
    }

    func customCmdRequire(_ manager: JL_ManagerM, with data: Data, isNeedResponse: Bool, sn: UInt8) {
        if isNeedResponse {
            if let responseData = CustomCmdConstants.ackResponse.data(using: .utf8) {
                manager.mCustomManager.cmdCustomResponse(sn, data: responseData)
            }
        }
    }
    
    func cleanUp() {
        customMgr?.delegate = nil
        eventSink = nil
    }
}
