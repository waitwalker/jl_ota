//
//  Untitled.swift
//  Runner
//
//  Created by 李放 on 2025/9/2.
//

import Foundation

/// Defines constants related to the Log, including logging, file operations, and sharing constants.
struct LogConstants {
    /// Tag used for logging.
    static let TAG = "LogHelper"
    
    /// Error message template when file path is null.
    static let ERROR_FILE_PATH_NULL = "File path is null for index: %d"
    
    /// Maximum length limit when reading log content.
    static let MAX_CONTENT_LENGTH = 40000
    
    /// Interval time (in milliseconds) when reading log files.
    static let READ_INTERVAL_MS: UInt64 = 1000
    
    // Event types
    /// Event type representing log file list.
    static let TYPE_LOG_FILES = "logFiles"
    
    /// Event type representing log file details.
    static let TYPE_LOG_DETAIL_FILES = "logDetailFiles"
    
    // Payload keys
    /// Key used to identify event type.
    static let KEY_TYPE = "type"
    
    /// Key used to identify file list.
    static let KEY_FILES = "files"
    
    /// Key used to identify file name.
    static let KEY_NAME = "name"
    
    // Error codes and messages
    /// Event code for log helper errors.
    static let ERROR_CODE_LOG_HELPER_ERROR = "error"
    
    /// Error message when log directory is not found.
    static let ERROR_MESSAGE_LOG_DIRECTORY_NOT_FOUND = "Log directory not found"
    
    /// Error message when no log files are found.
    static let ERROR_MESSAGE_NO_LOG_FILES_FOUND = "No log files found"
    
    /// Error message template when file path is null.
    static let ERROR_MESSAGE_FILE_PATH_NULL = "File path is null for index: %d"
    
    /// Error message when an error occurs while reading log file.
    static let ERROR_MESSAGE_ERROR_READING_LOG_FILE = "Error reading log file"
    
    /// Error message template when log file index is invalid.
    static let ERROR_MESSAGE_INVALID_LOG_FILE_INDEX = "Invalid log file index: %d"
    
    /// Error message when an error occurs while sharing log file.
    static let ERROR_MESSAGE_ERROR_SHARING_LOG_FILE = "Error sharing log file"
    
    // iOS-specific constants (not in original Android version)
    /// File extension for log files.
    static let LOG_FILE_EXTENSION = "txt"
    
    /// Directory where log files are stored.
    static let LOG_DIRECTORY = "Documents"
}
