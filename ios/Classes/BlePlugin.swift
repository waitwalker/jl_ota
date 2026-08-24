//
//  BlePlugin.swift
//  Runner
//
//  Created by 李放 on 2025/9/1.
//

import Foundation
import Flutter

/// Main class for the BLE plugin.
public class BlePlugin: NSObject, FlutterPlugin {
    // MARK: - Constants
    private enum Constants {
        static let METHOD_CHANNEL = "com.jieli.ble_plugin/methods"
        static let EVENT_CHANNEL = "com.jieli.ble_plugin/events"
    }

    // MARK: - Properties
    private var methodChannel: FlutterMethodChannel?
    private var eventChannel: FlutterEventChannel?
    private var methodChannelHandler: MethodChannelHandler?
    private var eventChannelHandler: EventChannelHandler?

    // MARK: - FlutterPlugin Implementation

    public static func register(with registrar: FlutterPluginRegistrar) {
        let instance = BlePlugin()

        // Initialize method channel
        instance.methodChannel = FlutterMethodChannel(
            name: Constants.METHOD_CHANNEL,
            binaryMessenger: registrar.messenger()
        )

        // Initialize event channel
        instance.eventChannel = FlutterEventChannel(
            name: Constants.EVENT_CHANNEL,
            binaryMessenger: registrar.messenger()
        )

        guard UIApplication.shared.delegate?.window != nil else {
            JLLogManager.logLevel(.ERROR, content: "Failed to obtain FlutterViewController for BLE Plugin")
            return
        }

        // Setup handlers
        instance.setupHandlers()

        // Register this instance as the plugin
        registrar.addMethodCallDelegate(instance, channel: instance.methodChannel!)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        // Forward all method calls to the MethodChannelHandler
        methodChannelHandler?.handle(call, result: result)
    }

    /// Creates and configures the channel handlers
    private func setupHandlers() {
        // Create handlers
        eventChannelHandler = EventChannelHandler()
        methodChannelHandler = MethodChannelHandler(eventChannelHandler: eventChannelHandler)

        // Setup handlers
        methodChannel?.setMethodCallHandler(methodChannelHandler?.handle)
        eventChannel?.setStreamHandler(eventChannelHandler)
    }

    // MARK: - Cleanup

    /// Cleans up plugin resources
    public func dispose() {
        methodChannel?.setMethodCallHandler(nil)
        eventChannel?.setStreamHandler(nil)
        methodChannel = nil
        eventChannel = nil
        methodChannelHandler = nil
        eventChannelHandler = nil
    }

    deinit {
        dispose()
    }
}
