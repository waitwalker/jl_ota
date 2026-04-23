//
//  LogManager.swift
//  Runner
//
//  Created by 李放 on 2025/9/2.
//

import Foundation
import Flutter

/// A singleton manager class for handling log file operations.
class LogManager {
    static let shared = LogManager()
    
    private var itemArray = NSMutableArray()
    private var eventSink: FlutterEventSink?
    private var isReading = false
    
    /// 设置事件通道的 sink
    func setEventSink(sink: FlutterEventSink?) {
        eventSink = sink
    }
    
    /// 加载日志文件列表
    func loadLogFiles() {
        // 清空现有数组
        itemArray.removeAllObjects()
        
        // 获取 Documents 目录路径
        guard let documentsPath = getDocumentsDirectoryPath() else {
            sendErrorToFlutter(
                errorCode: "LOG_DIRECTORY_NOT_FOUND",
                errorMessage: "Not find document directory",
                errorDetails: nil
            )
            return
        }
        
        let fileManager = FileManager.default
        
        do {
            // 获取目录中的所有文件
            let files = try fileManager.contentsOfDirectory(atPath: documentsPath)
            
            // 过滤出.txt文件并添加到数组
            for file in files {
                if file.hasSuffix(".txt") {
                    let fullPath = "\(documentsPath)/\(file)"
                    itemArray.add(fullPath)
                }
            }
            
            // 按修改时间排序（最新的在前）
            sortFilesByModificationDate()
            
            // 发送文件列表到 Flutter
            sendFilesToFlutter()
        } catch {
            sendErrorToFlutter(
                errorCode: "LOG_DIRECTORY_READ_ERROR",
                errorMessage: "Read log directory error: \(error.localizedDescription)",
                errorDetails: nil
            )
        }
    }
    
    ///  删除所有日志文件
    func deleteAllLogs() {
        guard let documentsPath = getDocumentsDirectoryPath() else {
            return
        }

        let fileManager = FileManager.default
        do {
            let files = try fileManager.contentsOfDirectory(atPath: documentsPath)
            for path in files {
                if path.hasSuffix(".txt") {
                    let newPath = "\(documentsPath)/\(path)"
                    try fileManager.removeItem(atPath: newPath)
                }
            }
        } catch {
            JLLogManager.logLevel(.DEBUG, content: "Error deleting files: \(error.localizedDescription)")
        }
    }
    
    /// Handles reading and sending log file content to Flutter based on index
    /// - Parameter index: The index of the log file in the itemArray
    func handleLogFileIndex(_ index: Int) {
        // Check if already reading a file
        if isReading {
            JLLogManager.logLevel(.DEBUG, content: "Already reading a file, please wait")
            sendErrorToFlutter(
                errorCode: "ALREADY_READING",
                errorMessage: "Already reading a file, please wait",
                errorDetails: nil
            )
            return
        }
        
        // Validate index
        guard let filePath = getFilePath(at: index) else {
            sendErrorToFlutter(
                errorCode: "INVALID_INDEX",
                errorMessage: "Invalid file index: \(index)",
                errorDetails: nil
            )
            return
        }
        
        isReading = true
        
        DispatchQueue.global(qos: .background).async {
            do {
                // Read file content
                let content = try self.readFileContent(at: filePath)
                
                // Send content to Flutter
                self.sendContentToFlutter(content)
            } catch {
                JLLogManager.logLevel(.DEBUG, content: "Error reading log file: \(error.localizedDescription)")
                self.sendErrorToFlutter(
                    errorCode: "FILE_READ_ERROR",
                    errorMessage: "Error reading log file: \(error.localizedDescription)",
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
                errorCode: "INVALID_INDEX",
                errorMessage: "Invalid file index: \(index)",
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
                    JLLogManager.logLevel(.DEBUG, content: "Share activity failed: \(error.localizedDescription)")
                }
            }
        } catch {
            JLLogManager.logLevel(.DEBUG, content: "Error reading log file for sharing: \(error.localizedDescription)")
            sendErrorToFlutter(
                errorCode: "FILE_READ_ERROR",
                errorMessage: "Error reading log file for sharing: \(error.localizedDescription)",
                errorDetails: nil
            )
        }
    }
    
    // MARK: - Helper Methods
    
    /// 获取Documents目录路径
    private func getDocumentsDirectoryPath() -> String? {
        return NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).last
    }
    
    /// 按修改时间排序文件（最新的在前）
    private func sortFilesByModificationDate() {
        let fileManager = FileManager.default
        
        itemArray.sort { (obj1, obj2) -> ComparisonResult in
            guard let path1 = obj1 as? String, let path2 = obj2 as? String else {
                return .orderedSame
            }
            
            do {
                let attr1 = try fileManager.attributesOfItem(atPath: path1)
                let attr2 = try fileManager.attributesOfItem(atPath: path2)
                
                let date1 = attr1[.modificationDate] as? Date ?? Date.distantPast
                let date2 = attr2[.modificationDate] as? Date ?? Date.distantPast
                
                return date2.compare(date1) // 最新的在前
            } catch {
                return .orderedSame
            }
        }
    }
    
    /// 获取指定索引的文件路径
    private func getFilePath(at index: Int) -> String? {
        guard index >= 0, index < itemArray.count, let filePath = itemArray[index] as? String else {
            return nil
        }
        return filePath
    }
    
    /// 读取文件内容
    private func readFileContent(at path: String) throws -> String {
        let data = try Data(contentsOf: URL(fileURLWithPath: path))
        guard let content = String(data: data, encoding: .utf8) else {
            throw NSError(domain: "EncodingError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to decode file content as UTF-8"])
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
    
    /// 发送文件列表到 Flutter
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
    
    /// 发送错误到 Flutter
    private func sendErrorToFlutter(errorCode: String, errorMessage: String, errorDetails: Any?) {
        eventSink?(FlutterError(
            code: errorCode,
            message: errorMessage,
            details: errorDetails
        ))
    }
}
