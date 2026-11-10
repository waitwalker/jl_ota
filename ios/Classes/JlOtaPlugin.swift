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
        
        initLog()
    }
    
    /// Initializes the logging system for OTA plugin
    private static func initLog() {
        // Configure logging system
        JLLogManager.setLog(true, isMore: false, level: JLLOG_LEVEL(rawValue: 0)!)
        JLLogManager.saveLog(asFile: true)
        JLLogManager.log(withTimestamp: true)
        JLLogManager.clearLog()
    }
    
}

#endif
