import Flutter
import JLLogHelper
import UIKit
import jl_ota

class SceneDelegate: FlutterSceneDelegate {
    override func scene(
        _ scene: UIScene,
        openURLContexts URLContexts: Set<UIOpenURLContext>
    ) {
        for context in URLContexts {
            let url = context.url
            handleOpenURL(url)
        }
        super.scene(scene, openURLContexts: URLContexts)
    }

    private func handleOpenURL(_ url: URL) {
        var data = Data()

        // 尝试从文件URL读取数据
        if url.isFileURL {
            do {
                data = try Data(contentsOf: url)
            } catch {
                JLLogManager.logLevel(.DEBUG, content: "Failed to read data from file URL: \(error)")
            }
        }

        // 如果是安全范围的资源，请求访问权限
        if url.startAccessingSecurityScopedResource() {
            do {
                data = try Data(contentsOf: url)
            } catch {
                JLLogManager.logLevel(.DEBUG, content: "Failed to read secured data: \(error)")
            }
            url.stopAccessingSecurityScopedResource()
        }

        // 检查数据有效性
        guard !data.isEmpty else {
            JLLogManager.logLevel(.DEBUG, content: "Open URL Failed. \(url.absoluteString)")
            return
        }

        let fileName = url.lastPathComponent
        let fileManager = FileManager.default

        // 获取文档目录路径
        guard let documentsDir = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            JLLogManager.logLevel(.DEBUG, content: "Failed to get documents directory")
            return
        }

        let upgradeDir = documentsDir.appendingPathComponent("upgrade")
        var isDirectory: ObjCBool = false
        let dirExists = fileManager.fileExists(atPath: upgradeDir.path, isDirectory: &isDirectory)

        // 检查目录是否存在，不存在则创建
        if !(dirExists && isDirectory.boolValue) {
            do {
                try fileManager.createDirectory(at: upgradeDir, withIntermediateDirectories: true, attributes: nil)
            } catch {
                JLLogManager.logLevel(.DEBUG, content: "Create upgrade Directory Failed: \(error)")
            }
        }

        var targetPath = upgradeDir.appendingPathComponent(fileName)

        // 如果文件已存在，添加时间戳重命名
        if fileManager.fileExists(atPath: targetPath.path) {
            let components = fileName.split(separator: ".")
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyyMMddHHmmss"
            let timestamp = dateFormatter.string(from: Date())

            let newFileName: String
            if components.count > 1 {
                let fileExtension = String(components.last!)
                let nameWithoutExtension = components.dropLast().joined(separator: ".")
                newFileName = "\(nameWithoutExtension)_\(timestamp).\(fileExtension)"
            } else {
                newFileName = "\(fileName)_\(timestamp)"
            }

            targetPath = upgradeDir.appendingPathComponent(newFileName)
        }

        // 创建文件
        fileManager.createFile(atPath: targetPath.path, contents: data, attributes: nil)

        // 发送通知给Flutter层
        let otaPlugin = JlOtaPlugin()
        otaPlugin.scanOtaList()
    }
}
