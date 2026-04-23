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
    static let FILE_SIZE_CONVERSION_FACTOR = 1024.0
}

/// A manager class for handling OTA (Over-The-Air) update related operations.
@objc class OtaManager: NSObject, JLBleHandlDelegate {
    
    // MARK: - Properties
    @objc static let shared = OtaManager()
    private var eventSink: FlutterEventSink?
    private(set) var itemArray: [String] = []
    private var ipAddress: String?

    // MARK: - Initialization
    override init() {
        super.init()
        JLBleHandler.share().delegate = self
    }

    // MARK: - Public Methods
        /// 设置事件通道的 sink
    @objc func setEventSink(sink: FlutterEventSink?) {
        eventSink = sink
    }
    
    /// 删除OTA文件索引
    func deleteOtaFileIndex(call: FlutterMethodCall, result: FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let pos = args[MethodChannelConstants.ARG_POS] as? Int else {
            result(FlutterError(code: "INVALID_ARGUMENT", message: "Invalid arguments", details: nil))
            return
        }
        
        guard pos >= 0 && pos < itemArray.count else {
            result(FlutterError(code: "INVALID_INDEX", message: "Index must be non-negative and within bounds", details: nil))
            return
        }
        
        deleteOtaFile(at: pos)
        result(nil)
    }
    
    /// 扫描更新文件
    @discardableResult
    @objc func scanForUpdateFiles() -> [String] {
        let fileManager = FileManager.default
        guard let documentDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            JLLogManager.logLevel(.DEBUG, content: "Document directory not found")
            return itemArray
        }
        
        let upgradeDirectory = documentDirectory.appendingPathComponent(OTA_UPGRADE)
        
        do {
            try fileManager.createDirectory(at: upgradeDirectory, withIntermediateDirectories: true, attributes: nil)
            let subPaths = try fileManager.contentsOfDirectory(atPath: upgradeDirectory.path)
            itemArray = subPaths.map { upgradeDirectory.appendingPathComponent($0).path }
            sendFileListToFlutter()
        } catch {
            JLLogManager.logLevel(.DEBUG, content: "Get ota upgrade file fail: \(error.localizedDescription)")
        }
        
        return itemArray
    }

    func setWifiIpAddress(_ ipAddress: String) {
        self.ipAddress = ipAddress
    }

    /// 获取WiFi IP地址
    func getWifiIpAddress(result: @escaping FlutterResult) {
        result(self.ipAddress)
    }
    
    /// 开始OTA更新
    func startOTA(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let path = call.arguments as? [String: Any],
              let filePath = path[MethodChannelConstants.ARG_PATH] as? String else {
            result(FlutterError(code: "INVALID_INDEX", message: "Index must be non-negative", details: nil))
            return
        }
        
        JLBleHandler.share().handleOtaFunc(withFilePath: filePath)
        result(true)
    }
    
    /// 下载文件
    func downloadFile(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let httpUrl = args[MethodChannelConstants.ARG_HTTP_URL] as? String else {
            result(FlutterError(code: "INVALID_ARGUMENT", message: "httpUrl must not be null", details: nil))
            return
        }
        
        sendDownloadStatusEvent(status: EventChannelConstants.STATUS_ON_START)
        downloadAction(url: httpUrl)
        result(nil)
    }
    
    // MARK: - OTA Callback
    func otaProgressOtaResult(_ result: JL_OTAResult, withProgress progress: Float) {
        let eventData = handleOtaResult(result, progress: progress)
        sendEvent(type: EventChannelConstants.TYPE_OTA_STATE, data: eventData)
    }
    
    // MARK: - Private Methods
    /// 删除OTA文件
    private func deleteOtaFile(at pos: Int) {
        let filePath = itemArray[pos]
        let fileManager = FileManager.default
        
        if fileManager.fileExists(atPath: filePath) {
            do {
                try fileManager.removeItem(atPath: filePath)
                JLLogManager.logLevel(.DEBUG, content: "Successfully deleted file at path: \(filePath)")
            } catch {
                JLLogManager.logLevel(.DEBUG, content: "Failed to delete file at path: \(filePath): \(error.localizedDescription)")
            }
        }
        
        itemArray.remove(at: pos)
        sendFileListToFlutter()
    }
    
    /// 发送事件到Flutter
    private func sendEvent(type: String, data: [String: Any]) {
        DispatchQueue.main.async {
            self.eventSink?([
                EventChannelConstants.KEY_TYPE: type,
                EventChannelConstants.KEY_VALUE: data
            ])
        }
    }
    
    /// 发送文件列表到Flutter
    private func sendFileListToFlutter() {
        let filesWithSize = itemArray.map { filePath -> (path: String, size: Double, name: String) in
            var fileSize: Double = 0.0
            do {
                let attributes = try FileManager.default.attributesOfItem(atPath: filePath)
                if let size = attributes[.size] as? NSNumber {
                    fileSize = size.doubleValue
                }
            } catch {
                JLLogManager.logLevel(.DEBUG, content: "Failed to get file size for \(filePath): \(error.localizedDescription)")
            }
            
            let fileName = (filePath as NSString).lastPathComponent
            return (path: filePath, size: fileSize, name: fileName)
        }
        
        let sortedFiles = filesWithSize.sorted { $0.size > $1.size }
        let fileList = sortedFiles.map { fileInfo -> [String: Any] in
            let fileSizeMB = fileInfo.size / OtaConstants.FILE_SIZE_CONVERSION_FACTOR / OtaConstants.FILE_SIZE_CONVERSION_FACTOR
            let formattedSize = String(format: "%.2fMb", fileSizeMB)
            let fileNameWithSize = "\(fileInfo.name)\t\t\(formattedSize)"
            
            return [
                EventChannelConstants.KEY_NAME: fileNameWithSize,
                EventChannelConstants.KEY_PATH: fileInfo.path
            ]
        }
        
        let data: [String: Any] = [EventChannelConstants.KEY_LIST: fileList]
        sendEvent(type: EventChannelConstants.TYPE_OTA_FILE_LIST, data: data)
    }
    
    /// 下载文件操作
    private func downloadAction(url: String) {
        let configuration = URLSessionConfiguration.default
        let manager = AFURLSessionManager(sessionConfiguration: configuration)
        
        guard let URL = URL(string: url) else {
            sendDownloadStatusEvent(status: EventChannelConstants.STATUS_ON_ERROR, errorMsg: "Invalid URL")
            return
        }
        
        let request = URLRequest(url: URL)
        let fileName = (url as NSString).lastPathComponent
        
        let downloadTask = manager.downloadTask(
            with: request,
            progress: { [weak self] downloadProgress in
                let progressValue = Int(downloadProgress.fractionCompleted * Double(OtaConstants.PROGRESS_MAX_PERCENT))
                self?.sendDownloadStatusEvent(
                    status: EventChannelConstants.STATUS_ON_PROGRESS,
                    progress: progressValue
                )
            },
            destination: { targetPath, response in
                let suggestedFilename = response.suggestedFilename ?? fileName
                return ToolsHelper.targetSavePath(suggestedFilename)
            },
            completionHandler: { [weak self] response, filePath, error in
                if let error = error {
                    self?.sendDownloadStatusEvent(
                        status: EventChannelConstants.STATUS_ON_ERROR,
                        errorMsg: error.localizedDescription
                    )
                } else if filePath != nil {
                    self?.scanForUpdateFiles()
                    self?.sendDownloadStatusEvent(status: EventChannelConstants.STATUS_ON_STOP)
                }
            }
        )
        
        downloadTask.resume()
    }
    
    /// 发送下载状态事件
    private func sendDownloadStatusEvent(status: String, progress: Int? = nil, errorMsg: String? = nil) {
        var eventMap: [String: Any] = [EventChannelConstants.KEY_STATUS: status]
        
        if let progress = progress, status == EventChannelConstants.STATUS_ON_PROGRESS {
            eventMap[EventChannelConstants.KEY_PROGRESS] = progress
        }
        
        if let errorMsg = errorMsg, status == EventChannelConstants.STATUS_ON_ERROR {
            eventMap[EventChannelConstants.KEY_MESSAGE] = errorMsg
        }
        
        sendEvent(type: EventChannelConstants.TYPE_DOWNLOAD_STATUS, data: eventMap)
    }
    
    /// 设置屏幕常亮
    private func setKeepScreenOn(_ enable: Bool) {
        UIApplication.shared.isIdleTimerDisabled = enable
    }
    
    /// 处理OTA结果
    private func handleOtaResult(_ result: JL_OTAResult, progress: Float) -> [String: Any] {
        let resultOtaUpgradingDict = [
            EventChannelConstants.KEY_STATE: EventChannelConstants.STATE_WORKING,
            EventChannelConstants.KEY_TYPE: EventChannelConstants.MSG_UPGRADING,
            EventChannelConstants.KEY_PROGRESS: Int(round(progress * Float(OtaConstants.PROGRESS_MAX_PERCENT)))
        ] as [String : Any]

        switch result {
        case .preparing:
            setKeepScreenOn(true)
            return [
                EventChannelConstants.KEY_STATE: EventChannelConstants.STATE_WORKING,
                EventChannelConstants.KEY_TYPE: EventChannelConstants.MSG_CHECKING_FILE,
                EventChannelConstants.KEY_PROGRESS: Int(round(progress * Float(OtaConstants.PROGRESS_MAX_PERCENT)))
            ]
            
        case .reconnect:
            JLBleHandler.share().handleReconnectByUUID()
            return [EventChannelConstants.KEY_STATE: EventChannelConstants.STATE_RECONNECT]
            
        case .reconnectWithMacAddr:
            JLBleHandler.share().handleReconnectByMac()
            return [EventChannelConstants.KEY_STATE: EventChannelConstants.STATE_RECONNECT]
            
        case .prepared:
            return [
                EventChannelConstants.KEY_STATE: EventChannelConstants.STATE_WORKING,
                EventChannelConstants.KEY_TYPE: EventChannelConstants.MSG_CHECKING_FILE,
                EventChannelConstants.KEY_PROGRESS: OtaConstants.PROGRESS_MAX_PERCENT
            ]
            
        case .success, .reboot:
            setKeepScreenOn(false)
            return [
                EventChannelConstants.KEY_STATE: EventChannelConstants.STATE_IDLE,
                EventChannelConstants.KEY_SUCCESS: true,
                EventChannelConstants.KEY_CODE: OtaConstants.OTA_UPGRADE_SUCCESS_CODE,
                EventChannelConstants.KEY_MESSAGE: EventChannelConstants.MSG_SUCCESS
            ]
            
        case .fail, .failCmdTimeout, .dataIsNull, .commandFail, .seekFail, .infoFail,
             .lowPower, .enterFail, .statusIsUpdating, .failedConnectMore, .failSameSN,
             .cancel, .failVerification, .failCompletely, .failKey, .failErrorFile,
             .failUboot, .failLenght, .failFlash, .failSameVersion, .failTWSDisconnect,
             .failNotInBin, .disconnect, .reconnectUpdateSource, .unknown:
            setKeepScreenOn(false)
            let errorReason = ToolsHelper.errorReason(result)
            return [
                EventChannelConstants.KEY_STATE: EventChannelConstants.STATE_IDLE,
                EventChannelConstants.KEY_SUCCESS: false,
                EventChannelConstants.KEY_MESSAGE: errorReason
            ]
            case .upgrading:
                return resultOtaUpgradingDict
            default:
                return resultOtaUpgradingDict
        }
    }
}
