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
    private var isCleanedUp = false
    
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
    }
    
    /// Delete OTA file by index
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
    
    /// Scan for OTA update files in the documents directory
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

    /// Get the WiFi IP address
    func getWifiIpAddress(result: @escaping FlutterResult) {
        result(self.ipAddress)
    }
    
    /// Start the OTA update process with the specified file
    func startOTA(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let path = call.arguments as? [String: Any],
              let filePath = path[MethodChannelConstants.ARG_PATH] as? String else {
            result(FlutterError(code: "INVALID_INDEX", message: "Index must be non-negative", details: nil))
            return
        }
        
        JLBleHandler.share().handleOtaFunc(withFilePath: filePath)
        result(true)
    }
    
    /// Download a file from the specified HTTP URL
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
    
    @objc func cleanUp() {
        guard !isCleanedUp else {
            return
        }
        
        isCleanedUp = true
        
        // Clear event sink to prevent further callbacks
        eventSink = nil
        
        // Clear file array
        itemArray.removeAll()
        
        // Clear IP address
        ipAddress = nil
        
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
        
        let eventData = handleOtaResult(result, progress: progress)
        sendEvent(type: EventChannelConstants.TYPE_OTA_STATE, data: eventData)
    }
    
    // MARK: - Private Methods
    /// Delete OTA file at the specified index
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
    
    /// Send the list of OTA files to Flutter with their sizes
    private func sendFileListToFlutter() {
        // Don't send events if cleaned up
        guard !isCleanedUp else { return }
        
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
    
    /// Perform the file download action
    private func downloadAction(url: String) {
        // 1. Validate URL
        guard let url = URL(string: url) else {
            sendDownloadStatusEvent(status: EventChannelConstants.STATUS_ON_ERROR,
                                   errorMsg: "Invalid URL")
            return
        }
        
        // 2. Create download task
        let downloadTask = createDownloadTask(for: url)
        
        // 3. Start download
        downloadTask.resume()
    }

    // MARK: - Private Download Helpers
    private func createDownloadTask(for url: URL) -> URLSessionDownloadTask {
        let manager = createSessionManager()
        let request = URLRequest(url: url)
        let fileName = extractFileName(from: url)
        
        return manager.downloadTask(
            with: request,
            progress: createProgressHandler(),
            destination: createDestinationHandler(fileName: fileName),
            completionHandler: createCompletionHandler()
        )
    }

    /// Create the URLSession manager for handling downloads
    private func createSessionManager() -> AFURLSessionManager {
        let configuration = URLSessionConfiguration.default
        return AFURLSessionManager(sessionConfiguration: configuration)
    }

    /// Extract the file name from a URL
    private func extractFileName(from url: URL) -> String {
        return url.lastPathComponent
    }

    /// Create the progress handler closure for tracking download progress
    private func createProgressHandler() -> (Progress) -> Void {
        return { [weak self] downloadProgress in
            guard let self = self, !self.isCleanedUp else { return }
            
            let progress = Int(downloadProgress.fractionCompleted * Double(OtaConstants.PROGRESS_MAX_PERCENT))
            self.sendDownloadStatusEvent(
                status: EventChannelConstants.STATUS_ON_PROGRESS,
                progress: progress
            )
        }
    }

    /// Create the destination handler closure for determining where to save the file
    private func createDestinationHandler(fileName: String) -> (URL, URLResponse) -> URL {
        return { targetPath, response in
            let suggestedFilename = response.suggestedFilename ?? fileName
            return ToolsHelper.targetSavePath(suggestedFilename)
        }
    }

    /// Create the completion handler closure for handling download results
    private func createCompletionHandler() -> (URLResponse, URL?, Error?) -> Void {
        return { [weak self] response, filePath, error in
            guard let self = self, !self.isCleanedUp else { return }
            
            if let error = error {
                self.handleDownloadError(error)
            } else if filePath != nil {
                self.handleDownloadSuccess()
            }
        }
    }

    /// Handle successful download completion
    private func handleDownloadSuccess() {
        scanForUpdateFiles()
        sendDownloadStatusEvent(status: EventChannelConstants.STATUS_ON_STOP)
    }

    /// Handle download error
    private func handleDownloadError(_ error: Error) {
        sendDownloadStatusEvent(
            status: EventChannelConstants.STATUS_ON_ERROR,
            errorMsg: error.localizedDescription
        )
    }
    
    /// Send download status event to Flutter
    private func sendDownloadStatusEvent(status: String, progress: Int? = nil, errorMsg: String? = nil) {
        // Don't send events if cleaned up
        guard !isCleanedUp else { return }
        
        var eventMap: [String: Any] = [EventChannelConstants.KEY_STATUS: status]
        
        if let progress = progress, status == EventChannelConstants.STATUS_ON_PROGRESS {
            eventMap[EventChannelConstants.KEY_PROGRESS] = progress
        }
        
        if let errorMsg = errorMsg, status == EventChannelConstants.STATUS_ON_ERROR {
            eventMap[EventChannelConstants.KEY_MESSAGE] = errorMsg
        }
        
        sendEvent(type: EventChannelConstants.TYPE_DOWNLOAD_STATUS, data: eventMap)
    }
    
    /// Set the screen keep-on state to prevent auto-lock during OTA
    private func setKeepScreenOn(_ enable: Bool) {
        UIApplication.shared.isIdleTimerDisabled = enable
    }
    
    /// Handle OTA result and return appropriate event data
    private func handleOtaResult(_ result: JL_OTAResult, progress: Float) -> [String: Any] {
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

    private func handleSuccess() -> [String: Any] {
        setKeepScreenOn(false)
        return [
            EventChannelConstants.KEY_STATE: EventChannelConstants.STATE_IDLE,
            EventChannelConstants.KEY_SUCCESS: true,
            EventChannelConstants.KEY_CODE: OtaConstants.OTA_UPGRADE_SUCCESS_CODE,
            EventChannelConstants.KEY_MESSAGE: EventChannelConstants.MSG_SUCCESS
        ]
    }

    private func handleFailure(_ result: JL_OTAResult) -> [String: Any] {
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
