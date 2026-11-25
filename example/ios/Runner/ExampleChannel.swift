import Flutter
import JLLogHelper
import jl_ota

private let methodChannelName = "com.jieli.otasdk.example/methods"
private let eventChannelName = "com.jieli.otasdk.example/events"

/// Example-only channel for logs, local upgrade files, download and exit.
final class ExampleChannel: NSObject, FlutterStreamHandler {
    private var eventSink: FlutterEventSink?

    static func register(messenger: FlutterBinaryMessenger) {
        let channel = ExampleChannel()
        let methods = FlutterMethodChannel(name: methodChannelName, binaryMessenger: messenger)
        methods.setMethodCallHandler(channel.handle)
        let events = FlutterEventChannel(name: eventChannelName, binaryMessenger: messenger)
        events.setStreamHandler(channel)
    }

    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        eventSink = events
        LogManager.shared.setEventSink(sink: events)
        CustomCmdManager.shared.setEventSink(sink: events)
        ExampleUpgradeFiles.shared.sink = { [weak self] event in
            self?.eventSink?(event)
        }
        ExampleUpgradeFiles.shared.publish()
        return nil
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        LogManager.shared.cleanUp()
        CustomCmdManager.shared.cleanUp()
        eventSink = nil
        return nil
    }

    private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "getAppVersion":
            let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
            if let version {
                result(version)
            } else {
                result(FlutterError(code: "VERSION_NOT_FOUND", message: "Could not retrieve app version", details: nil))
            }
        case "getLogFileDirPath":
            result(".../Document/JL_LOG.txt")
        case "getLogFiles":
            LogManager.shared.setEventSink(sink: eventSink)
            LogManager.shared.loadLogFiles()
            result(true)
        case "deleteAllLogFile":
            LogManager.shared.deleteAllLogs()
            result(true)
        case "logFileIndex":
            let index = (call.arguments as? [String: Any])?["logFileIndex"] as? Int ?? -1
            LogManager.shared.setEventSink(sink: eventSink)
            LogManager.shared.handleLogFileIndex(index)
            result(true)
        case "shareLogFile":
            shareLog(call: call, result: result)
        case "readFileList":
            ExampleUpgradeFiles.shared.publish()
            result(nil)
        case "deleteOtaFileIndex":
            ExampleUpgradeFiles.shared.delete(call: call, result: result)
        case "downloadFile":
            ExampleUpgradeFiles.shared.download(call: call, result: result)
        case "getWifiIpAddress":
            result(nil)
        case "popAllActivity", "exitApp":
            result(true)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                exit(0)
            }
        case "sendCustomCommand":
            sendCustom(call: call, result: result)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func shareLog(call: FlutterMethodCall, result: @escaping FlutterResult) {
        let index = (call.arguments as? [String: Any])?["logFileIndex"] as? Int ?? -1
        guard let controller = Self.topController() else {
            result(FlutterError(code: "NO_VIEW_CONTROLLER", message: "No view controller available to present share sheet", details: nil))
            return
        }
        LogManager.shared.shareLogFile(index: index, from: controller)
        result(true)
    }

    private func sendCustom(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let arguments = call.arguments as? [String: Any],
              let data = arguments["customData"] as? FlutterStandardTypedData else {
            result(FlutterError(code: "INVALID_DATA_TYPE", message: "Custom data should be a byte array", details: nil))
            return
        }
        CustomCmdManager.shared.setEventSink(sink: eventSink)
        CustomCmdManager.shared.send(data: data.data, result: result)
    }

    private static func topController() -> UIViewController? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }?
            .rootViewController
    }
}

/// Local upgrade-file cabinet used by the example upgrade page.
final class ExampleUpgradeFiles {
    static let shared = ExampleUpgradeFiles()
    var sink: ((Any) -> Void)?
    private var paths: [String] = []

    func publish() {
        let fileManager = FileManager.default
        guard let documents = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return
        }
        let upgrade = documents.appendingPathComponent("upgrade")
        do {
            try fileManager.createDirectory(at: upgrade, withIntermediateDirectories: true)
            paths = try fileManager.contentsOfDirectory(atPath: upgrade.path).map {
                upgrade.appendingPathComponent($0).path
            }
        } catch {
            JLLogManager.logLevel(.DEBUG, content: "Get ota upgrade file fail: \(error.localizedDescription)")
        }
        sendList()
    }

    func delete(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let pos = args["pos"] as? Int,
              pos >= 0, pos < paths.count else {
            result(FlutterError(code: "INVALID_INDEX", message: "Index must be non-negative and within bounds", details: nil))
            return
        }
        let path = paths[pos]
        if FileManager.default.fileExists(atPath: path) {
            try? FileManager.default.removeItem(atPath: path)
        }
        paths.remove(at: pos)
        sendList()
        result(nil)
    }

    func download(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let httpUrl = args["httpUrl"] as? String,
              let downloadUrl = URL(string: httpUrl) else {
            result(FlutterError(code: "INVALID_ARGUMENT", message: "httpUrl must not be null", details: nil))
            return
        }
        sendDownload(status: "onStart")
        let target = targetPath(for: downloadUrl.lastPathComponent)
        URLSession.shared.downloadTask(with: downloadUrl) { [weak self] tempUrl, _, error in
            guard let self else { return }
            if let error {
                self.sendDownload(status: "onError", message: error.localizedDescription)
                return
            }
            guard let tempUrl else {
                self.sendDownload(status: "onError", message: "Downloaded file is null")
                return
            }
            do {
                if FileManager.default.fileExists(atPath: target.path) {
                    try FileManager.default.removeItem(at: target)
                }
                try FileManager.default.moveItem(at: tempUrl, to: target)
                self.publish()
                self.sendDownload(status: "onStop")
            } catch {
                self.sendDownload(status: "onError", message: error.localizedDescription)
            }
        }.resume()
        result(nil)
    }

    private func targetPath(for fileName: String) -> URL {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let upgrade = documents.appendingPathComponent("upgrade")
        try? FileManager.default.createDirectory(at: upgrade, withIntermediateDirectories: true)
        var name = fileName
        var destination = upgrade.appendingPathComponent(name)
        if FileManager.default.fileExists(atPath: destination.path) {
            let parts = fileName.split(separator: ".")
            let stamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "")
            if parts.count > 1 {
                let ext = parts.last!
                let base = parts.dropLast().joined(separator: ".")
                name = "\(base)_\(stamp).\(ext)"
            } else {
                name = "\(fileName)_\(stamp)"
            }
            destination = upgrade.appendingPathComponent(name)
        }
        return destination
    }

    private func sendList() {
        let listed: [[String: Any]] = paths.map { path in
            var size = 0.0
            if let attributes = try? FileManager.default.attributesOfItem(atPath: path),
               let bytes = attributes[.size] as? NSNumber {
                size = bytes.doubleValue
            }
            let name = (path as NSString).lastPathComponent
            let megabytes = size / 1024.0 / 1024.0
            let item: [String: Any] = ["name": String(format: "%@\t\t%.2fMb", name, megabytes), "path": path]
            return (size, item)
        }.sorted { lhs, rhs in
            lhs.0 > rhs.0
        }.map { $0.1 }
        sink?(["type": "otaFileList", "value": ["list": listed]])
    }

    private func sendDownload(status: String, message: String? = nil) {
        var value: [String: Any] = ["status": status]
        if let message, status == "onError" {
            value["message"] = message
        }
        sink?(["type": "downloadStatus", "value": value])
    }
}
