#if !SWIFT_PACKAGE || !targetEnvironment(simulator)
//
//  MethodChannelHandler.swift
//  Runner
//
//  Created by 李放 on 2025/9/20
//

import Flutter
import UIKit
import JLLogHelper

/// Main plugin class for handling OTA (Over-The-Air) update functionality
/// Provides methods for scanning OTA files and managing WiFi connections
/// Integrates with BLE (Bluetooth Low Energy) for device communication
public class JlOtaPlugin: NSObject, FlutterPlugin {
    private var blePlugin: BlePlugin?
    
    public static func register(with registrar: FlutterPluginRegistrar) {
        // Register BLE plugin
        BlePlugin.register(with: registrar)
                
        // Set application language
        LanguageManager.setupAppLanguage()
        
        setLogEnabled(false)
    }

    /// SDK 日志默认关闭。宿主通过 setLogEnabled 打开或关闭。
    static func setLogEnabled(_ enabled: Bool) {
        JLLogManager.setLog(enabled, isMore: false, level: JLLOG_LEVEL(rawValue: 0)!)
        JLLogManager.saveLog(asFile: enabled)
        if enabled {
            JLLogManager.log(withTimestamp: true)
        }
    }
    
}

#endif
