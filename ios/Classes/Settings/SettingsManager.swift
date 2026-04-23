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
    private static let DELAY_EXIT_TIME: Double = 0.5 // 延迟退出时间500毫秒
    
    // MARK: - Public Methods
    /// 获取日志文件目录路径
    public static func getLogFileDirPath(result: @escaping FlutterResult) {
        result(LOG_FILE_DIR_PATH)
    }
    
    /// 获取设备认证使用状态
    public static func getUseDeviceAuth(result: @escaping FlutterResult) {
        result(ToolsHelper.isSupportPair())
    }
    
    /// 设置设备认证使用状态
    public static func setUseDeviceAuth(call: FlutterMethodCall, result: @escaping FlutterResult) {
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
    
    /// 获取SDK蓝牙使用状态
    public static func getUseSDKBluetooth(result: @escaping FlutterResult) {
        result(ToolsHelper.isConnectBySDK())
    }
    
    /// 设置SDK蓝牙使用状态
    public static func setUseSDKBluetooth(call: FlutterMethodCall, result: @escaping FlutterResult) {
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
    
    /// 获取SDK版本信息
    public static func getSDKVersion(result: @escaping FlutterResult) {
        let sdkVersion = JL_OTAManager.logSDKVersion().replacingOccurrences(of: SMALL_V, with: BIG_V)
        result(sdkVersion)
    }
    
    /// 获取应用版本信息
    public static func getAppVersion(result: @escaping FlutterResult) {
        guard let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String else {
            result(FlutterError(code: "VERSION_NOT_FOUND",
                               message: "Could not retrieve app version",
                               details: nil))
            return
        }
        
        result(appVersion)
    }
    
    // MARK: - Private Methods
    /// 处理设置变更后的通用操作
    private static func handleSettingChange(result: @escaping FlutterResult) {
        result(true)
        exitApplicationAfterDelay()
    }
    
    /// 延迟退出应用程序
    private static func exitApplicationAfterDelay() {
        DispatchQueue.main.asyncAfter(deadline: .now() + DELAY_EXIT_TIME) {
            exit(0)
        }
    }
}
