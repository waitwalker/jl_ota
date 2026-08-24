//
//  SettingsManager.swift
//  Runner
//
//  Created by 李放 on 2025/9/2.
//

import Flutter

/// A manager class for handling application settings and related operations.
class SettingsManager {
    // MARK: - Constants
    private static let LOG_FILE_DIR_PATH = ".../Document/JL_LOG.txt"
    private static let DELAY_EXIT_TIME: Double = 0.5 // Exit delay of 500 milliseconds
    
    // MARK: - Properties
    private static var isCleanedUp = false
    private static var pendingAsyncOperations: [DispatchWorkItem] = []
    
    // MARK: - Public Methods
    /// Get the log file directory path
    public static func getLogFileDirPath(result: @escaping FlutterResult) {
        guard !isCleanedUp else {
            result(FlutterError(code: "MANAGER_CLEANED_UP",
                               message: "SettingsManager has been cleaned up",
                               details: nil))
            return
        }
        result(LOG_FILE_DIR_PATH)
    }
    
    /// Get the device authentication usage status
    public static func getUseDeviceAuth(result: @escaping FlutterResult) {
        guard !isCleanedUp else {
            result(FlutterError(code: "MANAGER_CLEANED_UP",
                               message: "SettingsManager has been cleaned up",
                               details: nil))
            return
        }
        result(ToolsHelper.isSupportPair())
    }
    
    /// Set the device authentication usage status
    public static func setUseDeviceAuth(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard !isCleanedUp else {
            result(FlutterError(code: "MANAGER_CLEANED_UP",
                               message: "SettingsManager has been cleaned up",
                               details: nil))
            return
        }
        
        guard let arguments = call.arguments as? [String: Any],
              let isAuth = arguments[MethodChannelConstants.ARG_IS_AUTH] as? Bool else {
            result(FlutterError(code: "INVALID_ARGUMENTS",
                               message: "Missing or invalid arguments",
                               details: nil))
            return
        }
        
        ToolsHelper.setSupportPair(isAuth)
        handleSettingChange(result: result)
    }
    
    /// Get the SDK Bluetooth usage status
    public static func getUseSDKBluetooth(result: @escaping FlutterResult) {
        guard !isCleanedUp else {
            result(FlutterError(code: "MANAGER_CLEANED_UP",
                               message: "SettingsManager has been cleaned up",
                               details: nil))
            return
        }
        result(ToolsHelper.isConnectBySDK())
    }
    
    /// Set the SDK Bluetooth usage status
    public static func setUseSDKBluetooth(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard !isCleanedUp else {
            result(FlutterError(code: "MANAGER_CLEANED_UP",
                               message: "SettingsManager has been cleaned up",
                               details: nil))
            return
        }
        
        guard let arguments = call.arguments as? [String: Any],
              let isUsingSDKBluetooth = arguments[MethodChannelConstants.ARG_IS_USING_SDK_BLUETOOTH] as? Bool else {
            result(FlutterError(code: "INVALID_ARGUMENTS",
                               message: "Missing or invalid arguments",
                               details: nil))
            return
        }
        
        ToolsHelper.setConnectBySDK(isUsingSDKBluetooth)
        handleSettingChange(result: result)
    }
    
    /// Get the GATT Over EDR state
    public static func getGattOverEdrState(result: @escaping FlutterResult) {
        guard !isCleanedUp else {
            result(FlutterError(code: "MANAGER_CLEANED_UP",
                               message: "SettingsManager has been cleaned up",
                               details: nil))
            return
        }
        
        let isGattOverEdr = ToolsHelper.isGattOverEdr()
        result(isGattOverEdr)
    }
    
    /// Set the GATT Over EDR state
    public static func setGattOverEdrState(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard !isCleanedUp else {
            result(FlutterError(code: "MANAGER_CLEANED_UP",
                               message: "SettingsManager has been cleaned up",
                               details: nil))
            return
        }
        
        guard let arguments = call.arguments as? [String: Any],
              let isUsingGattOverEdr = arguments[MethodChannelConstants.ARG_IS_USING_GATT_OVER_EDR] as? Bool else {
            result(FlutterError(code: "INVALID_ARGUMENTS",
                               message: "Missing or invalid arguments",
                               details: nil))
            return
        }
        
        ToolsHelper.setGattOverEdr(isUsingGattOverEdr)
        handleSettingChange(result: result)
    }
    
    /// Get the GATT service UUIDs
    public static func getGattServiceUuids(result: @escaping FlutterResult) {
        guard !isCleanedUp else {
            result(FlutterError(
                code: "MANAGER_CLEANED_UP",
                message: "SettingsManager has been cleaned up",
                details: nil
            ))
            return
        }
        
        let gattServiceUUIDs = ToolsHelper.getGattServiceUUIDs()
        result(gattServiceUUIDs)
    }
    
    /// Set the GATT service UUIDs
    public static func setGattServiceUuids(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard !isCleanedUp else {
            result(FlutterError(code: "MANAGER_CLEANED_UP",
                               message: "SettingsManager has been cleaned up",
                               details: nil))
            return
        }
        
        guard let arguments = call.arguments as? [String: Any],
              let gattServiceUuids = arguments[MethodChannelConstants.ARG_GATT_SERVICE_UUIDS] as? [String] else {
            result(FlutterError(code: "INVALID_ARGUMENTS",
                               message: "Missing or invalid arguments",
                               details: nil))
            return
        }
        
        ToolsHelper.setGattServiceUUIDs(gattServiceUuids)
        handleSettingChange(result: result)
    }
    
    /// Get the SDK version information
    public static func getSDKVersion(result: @escaping FlutterResult) {
        guard !isCleanedUp else {
            result(FlutterError(code: "MANAGER_CLEANED_UP",
                               message: "SettingsManager has been cleaned up",
                               details: nil))
            return
        }
        let sdkVersion = JL_OTAManager.logSDKVersion().replacingOccurrences(of: SMALL_V, with: BIG_V)
        result(sdkVersion)
    }
    
    /// Get the application version information
    public static func getAppVersion(result: @escaping FlutterResult) {
        guard !isCleanedUp else {
            result(FlutterError(code: "MANAGER_CLEANED_UP",
                               message: "SettingsManager has been cleaned up",
                               details: nil))
            return
        }
        
        guard let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String else {
            result(FlutterError(code: "VERSION_NOT_FOUND",
                               message: "Could not retrieve app version",
                               details: nil))
            return
        }
        
        result(appVersion)
    }
    
    /// Clean up resources to prevent memory leaks and unwanted behavior
    public static func cleanUp() {
        guard !isCleanedUp else {
            return
        }
        
        isCleanedUp = true
        
        // Cancel all pending async operations
        for operation in pendingAsyncOperations {
            operation.cancel()
        }
        pendingAsyncOperations.removeAll()
    }
    
    /// Check if the manager has been cleaned up
    public static var isCleanedUpFlag: Bool {
        return isCleanedUp
    }
    
    private static func handleSettingChange(result: @escaping FlutterResult) {
        guard !isCleanedUp else {
            result(FlutterError(code: "MANAGER_CLEANED_UP",
                               message: "SettingsManager has been cleaned up",
                               details: nil))
            return
        }
        
        result(true)
        
        // Create and store the delayed operation for potential cancellation
        let workItem = DispatchWorkItem {
            guard !isCleanedUp else { return }
            exitApplication()
        }
        
        pendingAsyncOperations.append(workItem)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + DELAY_EXIT_TIME, execute: workItem)
    }
    
    /// Exit the application safely
    private static func exitApplication() {
        guard !isCleanedUp else {
            JLLogManager.logLevel(.DEBUG, content: "Exit prevented - SettingsManager cleaned up")
            return
        }
        
        JLLogManager.logLevel(.DEBUG, content: "Exiting application due to settings change")
        exit(0)
    }
    
    /// Reset the manager state (useful for testing or reinitialization)
    public static func reset() {
        // Cancel all pending operations
        for operation in pendingAsyncOperations {
            operation.cancel()
        }
        pendingAsyncOperations.removeAll()
        
        // Reset cleanup flag
        isCleanedUp = false
    }
}
