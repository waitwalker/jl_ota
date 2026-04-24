# jl_ota 插件解耦文档

## 问题背景

`jl_ota` 插件最初是从杰理 SDK 示例应用中提取的，代码直接依赖宿主应用的特定类（`MainActivity`、`MyApplication`、`FlutterViewController`）。当集成到 `party_x` 等第三方宿主应用时，会触发 `MissingPluginException`，导致插件完全不可用。

---

## 一、Android 侧问题与修复

### 1.1 问题现象

```
MissingPluginException(No implementation found for method xxx on channel com.jieli.ble_plugin/methods)
```

### 1.2 根本原因

`JlOtaPlugin.initializeBlePlugin()` 中对 Activity 做了强制类型检查：

```kotlin
// ❌ 原代码：只有宿主的 Activity 是 MainActivity 时才初始化
if (activity is MainActivity) {
    blePlugin = BlePlugin(binaryMessenger!!, activity as MainActivity)
}
```

宿主应用 `party_x` 的 Activity 不是 `MainActivity`，条件永远为 `false`，`BlePlugin` 不会被创建，所有 MethodChannel/EventChannel 都不会注册。

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
// ❌ 原代码：rootViewController 不是 FlutterViewController 时，整个 if 块跳过
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

当 `party_x` 使用 `UINavigationController` 或其他 VC 作为 `rootViewController` 时，条件不满足 → `setStreamHandler` 不执行 → Flutter 侧 `EventChannel.receiveBroadcastStream()` 调用 `listen` 时找不到实现。

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

## 三、问题本质总结

Android 和 iOS 的问题**本质完全相同**：

> 插件代码从 SDK 示例应用中迁移时，保留了对宿主应用特定类的硬编码依赖。
> 当集成到不同宿主应用时，类型匹配失败，导致 MethodChannel / EventChannel 未注册。

| 平台 | 硬依赖 | 失败条件 |
|------|--------|----------|
| Android | `activity is MainActivity` | 宿主 Activity 不是 `MainActivity` |
| iOS | `rootViewController as? FlutterViewController` | 宿主 rootVC 不是 `FlutterViewController` |

**通用解决原则**：Flutter 插件不应依赖宿主应用的具体类型，应使用框架提供的通用接口（`Activity`、`FlutterPluginRegistrar`）完成初始化和注册。

---

## 四、宿主应用集成注意事项

### Android

- 宿主应用**不需要**继承 `MyApplication`，插件会自动通过 `initWith(context)` 完成 SDK 初始化
- 宿主应用**不需要**特定的 Activity 名称或类型
- 蓝牙权限会由插件通过 `ActivityPluginBinding` 自行请求

### iOS

- 宿主应用**不需要** `rootViewController` 是 `FlutterViewController`
- Channel 注册完全由 `FlutterPluginRegistrar` 驱动，与 ViewController 层级无关
- 蓝牙权限需要在宿主应用的 `Info.plist` 中配置 `NSBluetoothAlwaysUsageDescription`
