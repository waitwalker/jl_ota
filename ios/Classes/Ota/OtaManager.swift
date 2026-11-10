#if !SWIFT_PACKAGE || !targetEnvironment(simulator)
//  OtaManager.swift
//  Runner
//
//  Created by 李放 on 2025/9/2.
//
import Foundation
import Flutter

// MARK: - Constants
private enum OtaConstants {
    static let PROGRESS_MAX_PERCENT = 100
    static let OTA_UPGRADE_SUCCESS_CODE = 0
}

/// A manager class for handling OTA (Over-The-Air) update related operations.
@objc class OtaManager: NSObject, JLBleHandlDelegate {
    
    // MARK: - Properties
    @objc static let shared = OtaManager()
    private var eventSink: FlutterEventSink?
    private var isCleanedUp = false
    private var isOtaFinished = false
    
    // MARK: - Initialization
    override init() {
        super.init()
        JLBleHandler.share().delegate = self
    }
    
    deinit {
        cleanUp()
    }

    // MARK: - Public Methods
    /// Set the event channel sink
    @objc func setEventSink(sink: FlutterEventSink?) {
        eventSink = sink
        if sink != nil {
            isCleanedUp = false
            if JLBleHandler.share().delegate == nil {
                JLBleHandler.share().delegate = self
            }
        }
    }
    
    /// Start the OTA update process with the specified file
    func startOTA(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let path = call.arguments as? [String: Any],
              let filePath = path[MethodChannelConstants.ARG_PATH] as? String else {
            result(FlutterError(code: "INVALID_INDEX", message: "Index must be non-negative", details: nil))
            return
        }
        
        isCleanedUp = false
        isOtaFinished = false
        if JLBleHandler.share().delegate == nil {
            JLBleHandler.share().delegate = self
        }
        JLBleHandler.share().handleOtaFunc(withFilePath: filePath)
        result(true)
    }
    
    @objc func cleanUp() {
        guard !isCleanedUp else {
            return
        }
        
        isCleanedUp = true
        
        // Clear event sink to prevent further callbacks
        eventSink = nil
        
        // Reset screen keep-on setting
        setKeepScreenOn(false)
        
        // Remove delegate reference to prevent callbacks
        if JLBleHandler.share().delegate === self {
            JLBleHandler.share().delegate = nil
        }
    }
    
    // MARK: - OTA Callback
    func otaProgressOtaResult(_ result: JL_OTAResult, withProgress progress: Float) {
        // Don't send events if cleaned up
        guard !isCleanedUp else { return }
        
        if let eventData = handleOtaResult(result, progress: progress) {
            sendEvent(type: EventChannelConstants.TYPE_OTA_STATE, data: eventData)
        }
    }
    
    // MARK: - Private Methods
    /// Send an event to the Flutter side
    private func sendEvent(type: String, data: [String: Any]) {
        // Don't send events if cleaned up
        guard !isCleanedUp else { return }
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self, !self.isCleanedUp else { return }
            self.eventSink?([
                EventChannelConstants.KEY_TYPE: type,
                EventChannelConstants.KEY_VALUE: data
            ])
        }
    }
    
    /// Set the screen keep-on state to prevent auto-lock during OTA
    private func setKeepScreenOn(_ enable: Bool) {
        UIApplication.shared.isIdleTimerDisabled = enable
    }
    
    /// Handle OTA result and return appropriate event data
    private func handleOtaResult(_ result: JL_OTAResult, progress: Float) -> [String: Any]? {
        switch result {
        case .preparing:
            return handlePreparing(progress)
            
        case .reconnect:
            return handleReconnect()
            
        case .reconnectWithMacAddr:
            return handleReconnectWithMac()
            
        case .prepared:
            return handlePrepared()
            
        case .success, .reboot:
            return handleSuccess()
            
        case .fail, .failCmdTimeout, .dataIsNull, .commandFail, .seekFail, .infoFail,
             .lowPower, .enterFail, .statusIsUpdating, .failedConnectMore, .failSameSN,
             .cancel, .failVerification, .failCompletely, .failKey, .failErrorFile,
             .failUboot, .failLenght, .failFlash, .failSameVersion, .failTWSDisconnect,
             .failNotInBin, .disconnect, .reconnectUpdateSource, .unknown:
            return handleFailure(result)
            
        case .upgrading:
            return makeUpgradingResult(progress)
            
        @unknown default:
            return makeUpgradingResult(progress)
        }
    }

    private func handlePreparing(_ progress: Float) -> [String: Any] {
        setKeepScreenOn(true)
        return [
            EventChannelConstants.KEY_STATE: EventChannelConstants.STATE_WORKING,
            EventChannelConstants.KEY_TYPE: EventChannelConstants.MSG_CHECKING_FILE,
            EventChannelConstants.KEY_PROGRESS: Int(round(progress * Float(OtaConstants.PROGRESS_MAX_PERCENT)))
        ]
    }

    private func handleReconnect() -> [String: Any] {
        JLBleHandler.share().handleReconnectByUUID()
        return [EventChannelConstants.KEY_STATE: EventChannelConstants.STATE_RECONNECT]
    }

    private func handleReconnectWithMac() -> [String: Any] {
        JLBleHandler.share().handleReconnectByMac()
        return [EventChannelConstants.KEY_STATE: EventChannelConstants.STATE_RECONNECT]
    }

    private func handlePrepared() -> [String: Any] {
        return [
            EventChannelConstants.KEY_STATE: EventChannelConstants.STATE_WORKING,
            EventChannelConstants.KEY_TYPE: EventChannelConstants.MSG_CHECKING_FILE,
            EventChannelConstants.KEY_PROGRESS: OtaConstants.PROGRESS_MAX_PERCENT
        ]
    }

    private func handleSuccess() -> [String: Any]? {
        if isOtaFinished {
            return nil
        }
        isOtaFinished = true
        setKeepScreenOn(false)
        return [
            EventChannelConstants.KEY_STATE: EventChannelConstants.STATE_IDLE,
            EventChannelConstants.KEY_SUCCESS: true,
            EventChannelConstants.KEY_CODE: OtaConstants.OTA_UPGRADE_SUCCESS_CODE,
            EventChannelConstants.KEY_MESSAGE: EventChannelConstants.MSG_SUCCESS
        ]
    }

    private func handleFailure(_ result: JL_OTAResult) -> [String: Any]? {
        if isOtaFinished {
            return nil
        }
        isOtaFinished = true
        setKeepScreenOn(false)
        let errorReason = ToolsHelper.errorReason(result)
        return [
            EventChannelConstants.KEY_STATE: EventChannelConstants.STATE_IDLE,
            EventChannelConstants.KEY_SUCCESS: false,
            EventChannelConstants.KEY_MESSAGE: errorReason
        ]
    }

    private func makeUpgradingResult(_ progress: Float) -> [String: Any] {
        return [
            EventChannelConstants.KEY_STATE: EventChannelConstants.STATE_WORKING,
            EventChannelConstants.KEY_TYPE: EventChannelConstants.MSG_UPGRADING,
            EventChannelConstants.KEY_PROGRESS: Int(round(progress * Float(OtaConstants.PROGRESS_MAX_PERCENT)))
        ]
    }
}

#endif
