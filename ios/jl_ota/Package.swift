// swift-tools-version: 5.9

import PackageDescription

let vendorTargets: [Target.Dependency] = [
  "DFUnits",
  "JLLogHelper",
  "JL_AdvParse",
  "JL_BLEKit",
  "JL_HashPair",
  "JL_OTALib",
]

let package = Package(
  name: "jl_ota",
  platforms: [
    .iOS("13.0")
  ],
  products: [
    .library(name: "jl-ota", targets: ["jl_ota"])
  ],
  dependencies: [
    .package(name: "FlutterFramework", path: "../FlutterFramework")
  ],
  targets: [
    .target(
      name: "jl_ota",
      dependencies: [
        .product(name: "FlutterFramework", package: "FlutterFramework"),
      ] + vendorTargets,
      path: "Sources/jl_ota",
      sources: [
        "SPMExports.swift",
        "SimulatorJlOtaPlugin.swift",
        "Classes/BleByAssist/JLBleAssistManager.swift",
        "Classes/BleHandle/JLBleHandler.swift",
        "Classes/BleManager/HandleBroadcastPtl.swift",
        "Classes/BleManager/JLBleEntity.swift",
        "Classes/BleManager/JLBleManager.swift",
        "Classes/BleManager/SingleDataSender.swift",
        "Classes/BlePlugin.swift",
        "Classes/Constant/DeviceTypeConstants.swift",
        "Classes/Constant/EventChannelConstants.swift",
        "Classes/Constant/MethodChannelConstants.swift",
        "Classes/CustomCmd/CustomCmdManager.swift",
        "Classes/EventChannelHandler.swift",
        "Classes/JlOtaPlugin.swift",
        "Classes/MethodChannelHandler.swift",
        "Classes/Ota/OtaManager.swift",
        "Classes/SDKBleManager/JL_RunSDK.swift",
        "Classes/Settings/SettingsManager.swift",
        "Classes/Tools/LanguageManager.swift",
        "Classes/Tools/ToolsHelper.swift",
      ],
      resources: [
        .process("PrivacyInfo.xcprivacy")
      ],
      linkerSettings: [
        .linkedFramework("CoreBluetooth"),
        .linkedFramework("UIKit"),
        .unsafeFlags(["-ObjC"]),
      ]
    ),
    .binaryTarget(name: "DFUnits", path: "Frameworks/DFUnits.xcframework"),
    .binaryTarget(name: "JLLogHelper", path: "Frameworks/JLLogHelper.xcframework"),
    .binaryTarget(name: "JL_AdvParse", path: "Frameworks/JL_AdvParse.xcframework"),
    .binaryTarget(name: "JL_BLEKit", path: "Frameworks/JL_BLEKit.xcframework"),
    .binaryTarget(name: "JL_HashPair", path: "Frameworks/JL_HashPair.xcframework"),
    .binaryTarget(name: "JL_OTALib", path: "Frameworks/JL_OTALib.xcframework"),
  ]
)
