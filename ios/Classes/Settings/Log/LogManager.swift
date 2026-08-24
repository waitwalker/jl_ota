//
//  LogManager.swift
//  Runner
//
//  Created by 李放 on 2025/9/2.
//

import Foundation
import Flutter

// MARK: - LogManager Constants
struct LogManagerConstants {
    static let logFileExtension = ".txt"
    static let documentsDirectory = FileManager.SearchPathDirectory.documentDirectory
    static let domainMask = FileManager.SearchPathDomainMask.userDomainMask
    
    static let errorCodeLogDirectoryNotFound = "LOG_DIRECTORY_NOT_FOUND"
    static let errorCodeLogDirectoryReadError = "LOG_DIRECTORY_READ_ERROR"
    static let errorCodeAlreadyReading = "ALREADY_READING"
    static let errorCodeInvalidIndex = "INVALID_INDEX"
    static let errorCodeFileReadError = "FILE_READ_ERROR"
    
    static let errorMessageLogDirectoryNotFound = "Not find document directory"
    static let errorMessageAlreadyReading = "Already reading a file, please wait"
    static let errorMessageInvalidIndex = "Invalid file index: %d"
    static let errorMessageFileReadError = "Error reading log file: %@"
    static let errorMessageFileShareError = "Error reading log file for sharing: %@"
    static let errorMessageDirectoryReadError = "Read log directory error: %@"
    static let errorMessageDeleteFilesError = "Error deleting files: %@"
    static let errorMessageShareActivityFailed = "Share activity failed: %@"
    static let errorMessageFileEncodingError = "Failed to decode file content as UTF-8"
    
    static let logAlreadyReading = "Already reading a file, please wait"
    static let logFileReadError = "Error reading log file: %@"
    static let logFileShareError = "Error reading log file for sharing: %@"
    static let logDeleteFilesError = "Error deleting files: %@"
    static let logShareActivityFailed = "Share activity failed: %@"
    static let logFileEncodingError = "Failed to decode file content as UTF-8"
    
    static let encodingErrorDomain = "EncodingError"
    static let encodingErrorCode = -1
    static let fileEncoding = String.Encoding.utf8
    
    static let distantPast = Date.distantPast
    
    static let backgroundQoS = DispatchQoS.background
}

/// A singleton manager class for handling log file operations.
class LogManager {
    static let shared = LogManager()
    
    private var itemArray = NSMutableArray()
    private var eventSink: FlutterEventSink?
    private var isReading = false
    
    func setEventSink(sink: FlutterEventSink?) {
        eventSink = sink
    }
    
    func loadLogFiles() {
        itemArray.removeAllObjects()
        
        guard let documentsPath = getDocumentsDirectoryPath() else {
            sendErrorToFlutter(
                errorCode: LogManagerConstants.errorCodeLogDirectoryNotFound,
                errorMessage: LogManagerConstants.errorMessageLogDirectoryNotFound,
                errorDetails: nil
            )
            return
        }
        
        let fileManager = FileManager.default
        
        do {
            let files = try fileManager.contentsOfDirectory(atPath: documentsPath)
            
            for file in files {
                if file.hasSuffix(LogManagerConstants.logFileExtension) {
                    let fullPath = "\(documentsPath)/\(file)"
                    itemArray.add(fullPath)
                }
            }
            
            sortFilesByModificationDate()
            
            sendFilesToFlutter()
        } catch {
            sendErrorToFlutter(
                errorCode: LogManagerConstants.errorCodeLogDirectoryReadError,
                errorMessage: String(format: LogManagerConstants.errorMessageDirectoryReadError, error.localizedDescription),
                errorDetails: nil
            )
        }
    }
    
    func deleteAllLogs() {
        guard let documentsPath = getDocumentsDirectoryPath() else {
            return
        }

        let fileManager = FileManager.default
        do {
            let files = try fileManager.contentsOfDirectory(atPath: documentsPath)
            for path in files {
                if path.hasSuffix(LogManagerConstants.logFileExtension) {
                    let newPath = "\(documentsPath)/\(path)"
                    try fileManager.removeItem(atPath: newPath)
                }
            }
        } catch {
            JLLogManager.logLevel(.DEBUG, content: String(format: LogManagerConstants.logDeleteFilesError, error.localizedDescription))
        }
    }
    
    /// Handles reading and sending log file content to Flutter based on index
    /// - Parameter index: The index of the log file in the itemArray
    func handleLogFileIndex(_ index: Int) {
        // Check if already reading a file
        if isReading {
            JLLogManager.logLevel(.DEBUG, content: LogManagerConstants.logAlreadyReading)
            sendErrorToFlutter(
                errorCode: LogManagerConstants.errorCodeAlreadyReading,
                errorMessage: LogManagerConstants.errorMessageAlreadyReading,
                errorDetails: nil
            )
            return
        }
        
        // Validate index
        guard let filePath = getFilePath(at: index) else {
            sendErrorToFlutter(
                errorCode: LogManagerConstants.errorCodeInvalidIndex,
                errorMessage: String(format: LogManagerConstants.errorMessageInvalidIndex, index),
                errorDetails: nil
            )
            return
        }
        
        isReading = true
        
        DispatchQueue.global(qos: LogManagerConstants.backgroundQoS.qosClass).async {
            do {
                // Read file content
                let content = try self.readFileContent(at: filePath)
                
                // Send content to Flutter
                self.sendContentToFlutter(content)
            } catch {
                JLLogManager.logLevel(.DEBUG, content: String(format: LogManagerConstants.logFileReadError, error.localizedDescription))
                self.sendErrorToFlutter(
                    errorCode: LogManagerConstants.errorCodeFileReadError,
                    errorMessage: String(format: LogManagerConstants.errorMessageFileReadError, error.localizedDescription),
                    errorDetails: nil
                )
            }
            
            self.isReading = false
        }
    }
    
    /// Shares the log file at the specified index
    /// - Parameters:
    ///   - index: The index of the log file to share
    ///   - viewController: The view controller from which to present the share sheet
    func shareLogFile(index: Int, from viewController: UIViewController) {
        // Validate index
        guard let filePath = getFilePath(at: index) else {
            sendErrorToFlutter(
                errorCode: LogManagerConstants.errorCodeInvalidIndex,
                errorMessage: String(format: LogManagerConstants.errorMessageInvalidIndex, index),
                errorDetails: nil
            )
            return
        }
        
        do {
            // Read file content
            let content = try readFileContent(at: filePath)
            
            // Create activity view controller with the content
            let activityViewController = UIActivityViewController(
                activityItems: [content],
                applicationActivities: nil
            )
            
            // Present the share sheet
            viewController.present(activityViewController, animated: true, completion: nil)
            
            // Set completion handler (optional)
            activityViewController.completionWithItemsHandler = { activityType, completed, returnedItems, error in
                // Handle completion if needed
                if let error = error {
                    JLLogManager.logLevel(.DEBUG, content: String(format: LogManagerConstants.logShareActivityFailed, error.localizedDescription))
                }
            }
        } catch {
            JLLogManager.logLevel(.DEBUG, content: String(format: LogManagerConstants.logFileShareError, error.localizedDescription))
            sendErrorToFlutter(
                errorCode: LogManagerConstants.errorCodeFileReadError,
                errorMessage: String(format: LogManagerConstants.errorMessageFileShareError, error.localizedDescription),
                errorDetails: nil
            )
        }
    }
        
    private func getDocumentsDirectoryPath() -> String? {
        return NSSearchPathForDirectoriesInDomains(
            LogManagerConstants.documentsDirectory,
            LogManagerConstants.domainMask,
            true
        ).last
    }
    
    private func sortFilesByModificationDate() {
        let fileManager = FileManager.default
        
        itemArray.sort { (obj1, obj2) -> ComparisonResult in
            guard let path1 = obj1 as? String, let path2 = obj2 as? String else {
                return .orderedSame
            }
            
            do {
                let attr1 = try fileManager.attributesOfItem(atPath: path1)
                let attr2 = try fileManager.attributesOfItem(atPath: path2)
                
                let date1 = attr1[.modificationDate] as? Date ?? LogManagerConstants.distantPast
                let date2 = attr2[.modificationDate] as? Date ?? LogManagerConstants.distantPast
                
                return date2.compare(date1) // 最新的在前
            } catch {
                return .orderedSame
            }
        }
    }
    
    private func getFilePath(at index: Int) -> String? {
        guard index >= 0, index < itemArray.count, let filePath = itemArray[index] as? String else {
            return nil
        }
        return filePath
    }
    
    private func readFileContent(at path: String) throws -> String {
        let data = try Data(contentsOf: URL(fileURLWithPath: path))
        guard let content = String(data: data, encoding: LogManagerConstants.fileEncoding) else {
            throw NSError(
                domain: LogManagerConstants.encodingErrorDomain,
                code: LogManagerConstants.encodingErrorCode,
                userInfo: [NSLocalizedDescriptionKey: LogManagerConstants.errorMessageFileEncodingError]
            )
        }
        return content
    }
    
    /// Sends file content to Flutter
    /// - Parameter content: The content of the file to send
    private func sendContentToFlutter(_ content: String) {
        DispatchQueue.main.async {
            self.eventSink?([
                LogConstants.KEY_TYPE: LogConstants.TYPE_LOG_DETAIL_FILES,
                LogConstants.KEY_FILES: [content]
            ])
        }
    }
    
    private func sendFilesToFlutter() {
        var fileList: [[String: Any]] = []
        
        for case let filePath as String in itemArray {
            let fileName = URL(fileURLWithPath: filePath).lastPathComponent
            fileList.append([LogConstants.KEY_NAME: fileName]) // 文件名
        }
        
        eventSink?([
            LogConstants.KEY_TYPE: LogConstants.TYPE_LOG_FILES,
            LogConstants.KEY_FILES: fileList
        ])
    }
    
    private func sendErrorToFlutter(errorCode: String, errorMessage: String, errorDetails: Any?) {
        eventSink?(FlutterError(
            code: errorCode,
            message: errorMessage,
            details: errorDetails
        ))
    }
    
    func cleanUp() {
        // Clear event sink to prevent further callbacks
        eventSink = nil
        
        // Clear the file array
        itemArray.removeAllObjects()
        
        // Reset reading flag
        isReading = false
    }
}
