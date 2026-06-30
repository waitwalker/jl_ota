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
      name: "JlOtaObjC",
      dependencies: vendorTargets,
      path: "Sources/JlOtaObjC",
      sources: [
        "BleByAssist/JLBleAssistManager.m",
        "BleHandle/JLBleHandler.m",
        "BleManager/HandleBroadcastPtl.m",
        "BleManager/JLBleEntity.m",
        "BleManager/JLBleManager.m",
        "BleManager/SingleDataSender.m",
        "BroadcastSpeakers/BroadcastBle/DeviceManager.m",
        "Constant/DeviceTypeConstants.m",
        "SDKBleManager/JL_RunSDK.m",
        "Tools/ToolsHelper.m",
      ],
      publicHeadersPath: ".",
      cSettings: [
        .headerSearchPath("."),
        .headerSearchPath("BleByAssist"),
        .headerSearchPath("BleHandle"),
        .headerSearchPath("BleManager"),
        .headerSearchPath("BroadcastSpeakers/BroadcastBle"),
        .headerSearchPath("Constant"),
        .headerSearchPath("SDKBleManager"),
        .headerSearchPath("Tools"),
      ],
      linkerSettings: [
        .linkedFramework("CoreBluetooth"),
        .linkedFramework("UIKit"),
        .unsafeFlags(["-ObjC"]),
      ]
    ),
    .target(
      name: "jl_ota",
      dependencies: [
        .product(name: "FlutterFramework", package: "FlutterFramework"),
        "JlOtaObjC",
      ] + vendorTargets,
      path: "Sources/jl_ota",
      sources: [
        "SPMExports.swift",
        "Classes/BlePlugin.swift",
        "Classes/Constant/EventChannelConstants.swift",
        "Classes/Constant/LogConstants.swift",
        "Classes/Constant/MethodChannelConstants.swift",
        "Classes/EventChannelHandler.swift",
        "Classes/JlOtaPlugin.swift",
        "Classes/MethodChannelHandler.swift",
        "Classes/Ota/OtaManager.swift",
        "Classes/Settings/Log/LogManager.swift",
        "Classes/Settings/SettingsManager.swift",
        "Classes/Tools/LanguageManager.swift",
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
