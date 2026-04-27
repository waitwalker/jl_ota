# jl_ota 插件解耦文档

## 问题背景

`jl_ota` 插件最初是从杰理 SDK 示例应用中提取的，代码直接依赖示例工程中的特定类（`MainActivity`、`MyApplication`、`FlutterViewController`）。当作为依赖集成到第三方宿主应用时，会触发 `MissingPluginException`，导致插件完全不可用。

---

## 一、Android 侧问题与修复

### 1.1 问题现象

```
MissingPluginException(No implementation found for method xxx on channel com.jieli.ble_plugin/methods)
```

### 1.2 根本原因

`JlOtaPlugin.initializeBlePlugin()` 中对 Activity 做了强制类型检查：

```kotlin
// ❌ 原代码：只有当宿主的 Activity 是杰理 SDK 示例工程中定义的 MainActivity 类时才初始化
// 这里的 MainActivity 是 jl_ota 插件 example 工程里的类（com.jieli.otasdk.MainActivity），
// 而非通用的 Activity。任何第三方宿主应用的 Activity 都不可能是这个类，因此条件永远为 false。
if (activity is MainActivity) {
    blePlugin = BlePlugin(binaryMessenger!!, activity as MainActivity)
}
```

第三方宿主应用的 Activity 不是杰理示例工程中的 `MainActivity`，条件永远为 `false`，`BlePlugin` 不会被创建，所有 MethodChannel/EventChannel 都不会注册。

此外：
- `MethodChannelHandler` 构造参数类型为 `MainActivity`，强依赖宿主类
- `MyApplication` 要求宿主 Application 必须继承它，否则 SDK 初始化失败
- 文件选择（`pickFile`）和权限请求逻辑写死在 `MainActivity` 中

### 1.3 修复方案

#### JlOtaPlugin.kt — 承接 Activity 职责

| 改动 | 说明 |
|------|------|
| 实现 `ActivityResultListener` | 接管文件选择回调，不再依赖 `MainActivity.onActivityResult` |
| 实现 `RequestPermissionsResultListener` | 接管权限请求回调，不再依赖 `MainActivity.onRequestPermissionsResult` |
| `initializeBlePlugin()` 移除类型检查 | 使用通用 `Activity` 类型，任何宿主都能初始化 |
| `onAttachedToEngine` 中调用 `MyApplication.initWith(context)` | 用宿主的 applicationContext 初始化 SDK 单例 |

```kotlin
// ✅ 修复后：不再检查 Activity 类型
private fun initializeBlePlugin() {
    val act = activity
    val messenger = binaryMessenger
    if (act != null && messenger != null) {
        blePlugin = BlePlugin(messenger, act, this)
    }
}
```

#### BlePlugin.kt — 使用通用 Activity

```diff
- class BlePlugin(messenger: BinaryMessenger, private val activity: MainActivity) {
+ class BlePlugin(messenger: BinaryMessenger, private val activity: Activity, private val plugin: JlOtaPlugin) {
```

#### MethodChannelHandler.kt — 解耦 MainActivity

```diff
- class MethodChannelHandler(private val activity: MainActivity) : MethodChannel.MethodCallHandler {
+ class MethodChannelHandler(private val activity: Activity, private val plugin: JlOtaPlugin) : MethodChannel.MethodCallHandler {
```

权限请求和文件选择改为通过 `plugin` 实例调用：

```diff
- activity.requestMissingPermissions(permissions) { granted -> ... }
+ plugin.requestMissingPermissions(permissions) { granted -> ... }

- activity.pickFile()
+ plugin.pickFile()

- MainActivity.selectedUri?.let { ... }
+ JlOtaPlugin.selectedUri?.let { ... }
```

#### MyApplication.kt — 支持外部初始化

新增静态方法 `initWith(context)`，允许在不继承 `MyApplication` 的情况下初始化 SDK 环境：

```kotlin
companion object {
    fun initWith(context: Context) {
        if (instance != null) return
        synchronized(this) {
            if (instance == null) {
                val wrapper = MyApplication()
                instance = wrapper
                wrapper.initFromContext(context.applicationContext)
            }
        }
    }
}
```

`initFromContext` 内部完成：
- `attachBaseContext` 赋予 wrapper 完整的 Context 能力
- 初始化 OTA 文件目录、日志目录
- 初始化 `ActivityManager`、`ToastUtil`、`CommonUtil` 等第三方组件

### 1.4 涉及文件

| 文件 | 改动类型 |
|------|----------|
| `android/.../JlOtaPlugin.kt` | 重构 |
| `android/.../BlePlugin.kt` | 重构 |
| `android/.../MethodChannelHandler.kt` | 重构 |
| `android/.../MyApplication.kt` | 新增 `initWith` |

### 1.5 对应 Commit

```
2de7800 refactor: 重构插件以解耦 MainActivity 和 MyApplication 依赖
```

---

## 二、iOS 侧问题与修复

### 2.1 问题现象

```
MissingPluginException(No implementation found for method listen on channel com.jieli.ble_plugin/events)
```

### 2.2 根本原因

`BlePlugin.register(with:)` 中强制要求 `rootViewController` 必须是 `FlutterViewController`：

```swift
// ❌ 原代码：强制将 rootViewController 转换为 FlutterViewController 类型
// 这在杰理 SDK 示例工程中可以正常工作，因为示例工程的 rootViewController 就是 FlutterViewController。
// 但第三方宿主应用可能使用 UINavigationController、UITabBarController 等作为 rootViewController，
// 此时 as? FlutterViewController 转换失败，整个 if 块被跳过，导致 channel 未注册。
if let window = UIApplication.shared.delegate?.window,
   let flutterViewController = window?.rootViewController as? FlutterViewController {

    instance.eventChannelHandler = EventChannelHandler(flutterViewController: flutterViewController)
    instance.methodChannelHandler = MethodChannelHandler(
        flutterViewController: flutterViewController,
        eventChannelHandler: instance.eventChannelHandler
    )

    instance.methodChannel?.setMethodCallHandler(...)
    instance.eventChannel?.setStreamHandler(...)  // ← 只在这里注册
}
```

当第三方宿主应用使用 `UINavigationController` 或其他 VC 作为 `rootViewController` 时，条件不满足 → `setStreamHandler` 不执行 → Flutter 侧 `EventChannel.receiveBroadcastStream()` 调用 `listen` 时找不到实现。

### 2.3 修复方案

#### BlePlugin.swift — 无条件注册 Channel

移除 `FlutterViewController` 的获取和条件判断，**无条件**创建 handler 并注册：

```swift
// ✅ 修复后：不再依赖 FlutterViewController
public static func register(with registrar: FlutterPluginRegistrar) {
    let instance = BlePlugin()

    instance.methodChannel = FlutterMethodChannel(
        name: Constants.METHOD_CHANNEL,
        binaryMessenger: registrar.messenger()
    )
    instance.eventChannel = FlutterEventChannel(
        name: Constants.EVENT_CHANNEL,
        binaryMessenger: registrar.messenger()
    )

    // 无条件创建和注册
    instance.eventChannelHandler = EventChannelHandler()
    instance.methodChannelHandler = MethodChannelHandler(
        eventChannelHandler: instance.eventChannelHandler
    )

    instance.methodChannel?.setMethodCallHandler(instance.methodChannelHandler?.handle)
    instance.eventChannel?.setStreamHandler(instance.eventChannelHandler)

    registrar.addMethodCallDelegate(instance, channel: instance.methodChannel!)
}
```

#### EventChannelHandler.swift — 移除 FlutterViewController 参数

```diff
- private weak var flutterViewController: FlutterViewController?
-
- init(flutterViewController: FlutterViewController?) {
-     self.flutterViewController = flutterViewController
-     super.init()
-     initData()
- }
+ override init() {
+     super.init()
+     initData()
+ }
```

`flutterViewController` 属性在实际代码中**从未被使用**（所有引用都在已注释的代码块中），移除无副作用。

#### MethodChannelHandler.swift — 移除 FlutterViewController 参数

```diff
- private weak var flutterViewController: FlutterViewController?
-
- init(flutterViewController: FlutterViewController?, eventChannelHandler: EventChannelHandler?) {
-     self.flutterViewController = flutterViewController
-     self.eventChannelHandler = eventChannelHandler
- }
+ init(eventChannelHandler: EventChannelHandler?) {
+     self.eventChannelHandler = eventChannelHandler
+ }
```

`connectDevice` 中展示蓝牙未开启提示改用通用 `rootViewController`：

```diff
- if let flutterViewController = UIApplication.shared.keyWindow?.rootViewController as? FlutterViewController {
-     DFUITools.showText(localizedText, on: flutterViewController.view, delay: 1.0)
+ if let rootVC = UIApplication.shared.keyWindow?.rootViewController {
+     DFUITools.showText(localizedText, on: rootVC.view, delay: 1.0)
```

### 2.4 涉及文件

| 文件 | 改动类型 |
|------|----------|
| `ios/Classes/BlePlugin.swift` | 重构 |
| `ios/Classes/EventChannelHandler.swift` | 移除无用参数 |
| `ios/Classes/MethodChannelHandler.swift` | 移除无用参数，修复 Toast 展示 |

### 2.5 对应 Commit

```
77cb4cc fix: 修复 iOS 侧 MissingPluginException 异常
```

---

## 三、iOS 侧 OTA 升级成功后立即提示断开失败

### 3.1 问题现象

在 iOS 侧进行 OTA 升级时，进度达到 100% 后会先弹出“升级成功”，但紧接着瞬间变为“升级失败：设备断开”。

### 3.2 根本原因

在固件升级成功后，设备通常会自动重启以应用新固件，这必然会导致当前的蓝牙连接物理断开。
在原有逻辑中：
1. 底层 OTA SDK 首先回调 `.success` 或 `.reboot` 状态。
2. `OtaManager` 接收到成功状态，向 Flutter 端发送 `KEY_SUCCESS: true`，触发界面弹出 **“升级成功”**。
3. 紧接着设备重启导致蓝牙断开，底层 OTA SDK 又抛出 `.disconnect` 错误回调。
4. `OtaManager` 盲目处理了 `.disconnect`，将其误认为一次升级失败，立即向 Flutter 发送了 `KEY_SUCCESS: false` 和“设备断开”的错误信息。

由于 Flutter 端的弹窗始终监听同一个事件流，导致 UI 在刚显示成功后马上被错误状态覆盖。而 Android 侧由于在底层有相应拦截，没有暴露此问题。

### 3.3 修复方案

在 `ios/Classes/Ota/OtaManager.swift` 中引入状态拦截机制：

#### OtaManager.swift — 拦截已完成的 OTA 状态

新增 `isOtaFinished` 标志位。在每次启动 OTA 时重置，在成功后标记，以此拦截随后的无效错误回调。

```swift
// 1. 新增标志位
private var isOtaFinished: Bool = false

// 2. 在 startOTA 中重置
func startOTA(...) {
    isOtaFinished = false
    ...
}

// 3. 在处理结果时进行拦截
private func handleOtaResult(_ result: JL_OTAResult, progress: Float) -> [String: Any]? {
    switch result {
    case .success, .reboot:
        isOtaFinished = true // 标记升级已成功结束
        ...
        return [...]
        
    case .fail, ..., .disconnect:
        if isOtaFinished {
            return nil // 如果已经成功结束，忽略随后的断开等错误事件
        }
        isOtaFinished = true
        ...
        return [...]
    }
}
```

### 3.4 涉及文件

| 文件 | 改动类型 |
|------|----------|
| `ios/Classes/Ota/OtaManager.swift` | 逻辑修复，增加状态拦截 |

---

## 四、iOS 扫描设备 address 字段为空

### 4.1 问题现象

通过 `BleEventStream.scanDeviceListStream` 获取扫描设备列表时，iOS 侧返回的 `ScanDevice.description` 中 `address` 字段为空：

```
rssi: -65, address:       ← address 为空
```

而 Android 侧正常返回：

```
rssi: -65, address: AA:BB:CC:DD:EE:FF
```

### 4.2 根本原因

两个平台获取设备地址的方式不同：

| 平台 | 地址来源 | 是否始终可用 |
|------|----------|:---:|
| Android | `BluetoothDevice.address`（系统 API 直接提供 MAC 地址） | ✅ |
| iOS（修复前） | `entity.edrMacAddress` / `entity.mEdr`（依赖设备固件广播 EDR 地址） | ❌ |

iOS 侧原代码只使用了杰理 SDK 解析出的 EDR MAC 地址：

```swift
// ❌ 原代码：只使用 edrMacAddress，如果设备未广播 EDR 地址则为空
let formattedMac = formatMacAddress(entity.edrMacAddress)  // JLBleEntity
let formattedMac = formatMacAddress(entity.mEdr)           // JL_EntityM
```

`edrMacAddress` 和 `mEdr` 是杰理设备通过 BLE 广播数据自行解析出的 EDR MAC 地址，需要设备固件主动在广播包中携带该信息。如果设备未广播 EDR 地址，这两个属性就是空字符串。

而 iOS 系统出于隐私保护**不暴露 BLE 设备的真实 MAC 地址**，但每个设备都有一个 `CBPeripheral.identifier`（UUID 格式），在同一台 iPhone 上对同一设备保持不变，可作为设备唯一标识。

### 4.3 修复方案

新增 `getDeviceAddress` 方法，优先使用 EDR MAC 地址，为空时回退到 `CBPeripheral.identifier`：

```swift
// ✅ 修复后：优先 EDR MAC，为空时回退 peripheral UUID
private func getDeviceAddress(edrMac: String, peripheral: CBPeripheral) -> String {
    let formatted = formatMacAddress(edrMac)
    if !formatted.isEmpty {
        return formatted
    }
    // iOS 不暴露真实 MAC 地址，使用 CBPeripheral.identifier 作为设备唯一标识
    return peripheral.identifier.uuidString
}
```

修复后 iOS 侧返回示例：

```
rssi: -65, address: 12345678-ABCD-1234-ABCD-1234567890AB
```

### 4.4 涉及文件

| 文件 | 改动类型 |
|------|----------|
| `ios/Classes/EventChannelHandler.swift` | 新增 `getDeviceAddress` 方法，修改 `getDeviceDesc` 调用 |

### 4.5 对应 Commit

```
232798f fix: 修复 iOS 侧扫描设备 address 字段为空的问题
```

---

## 五、问题本质总结

Android 和 iOS 的 MissingPluginException 问题**本质完全相同**：

> 插件代码从 SDK 示例应用中迁移时，保留了对宿主应用特定类的硬编码依赖。
> 当集成到不同宿主应用时，类型匹配失败，导致 MethodChannel / EventChannel 未注册。

| 平台 | 硬依赖 | 失败条件 |
|------|--------|----------|
| Android | `activity is MainActivity` | 宿主 Activity 不是 `MainActivity` |
| iOS | `rootViewController as? FlutterViewController` | 宿主 rootVC 不是 `FlutterViewController` |

**通用解决原则**：Flutter 插件不应依赖宿主应用的具体类型，应使用框架提供的通用接口（`Activity`、`FlutterPluginRegistrar`）完成初始化和注册。

---

## 六、宿主应用集成注意事项

### Android

- 宿主应用**不需要**继承 `MyApplication`，插件会自动通过 `initWith(context)` 完成 SDK 初始化
- 宿主应用**不需要**特定的 Activity 名称或类型
- 蓝牙权限会由插件通过 `ActivityPluginBinding` 自行请求

### iOS

- 宿主应用**不需要** `rootViewController` 是 `FlutterViewController`
- Channel 注册完全由 `FlutterPluginRegistrar` 驱动，与 ViewController 层级无关
- 蓝牙权限需要在宿主应用的 `Info.plist` 中配置 `NSBluetoothAlwaysUsageDescription`
- 扫描设备的 `address` 字段在无 EDR MAC 时返回 `CBPeripheral.identifier`（UUID 格式），与 Android 的 MAC 地址格式不同

