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
- 插件库不声明蓝牙/定位权限，避免通过库 Manifest 影响宿主权限策略。`example` 仅作为演示 App 自行声明所需权限。
- 宿主 App 必须在自己的 Manifest 中声明 BLE 扫描/连接所需权限；插件只通过 `ActivityPluginBinding` 做运行时检查和权限请求。Android 12+ 使用 Nearby devices 权限，Android 11 及以下才需要定位权限和定位服务。

```xml
<uses-permission
    android:name="android.permission.BLUETOOTH"
    android:maxSdkVersion="30" />
<uses-permission
    android:name="android.permission.BLUETOOTH_ADMIN"
    android:maxSdkVersion="30" />
<uses-permission
    android:name="android.permission.ACCESS_FINE_LOCATION"
    android:maxSdkVersion="30" />
<uses-permission
    android:name="android.permission.ACCESS_COARSE_LOCATION"
    android:maxSdkVersion="30" />
<uses-permission
    android:name="android.permission.BLUETOOTH_SCAN" />
<uses-permission
    android:name="android.permission.BLUETOOTH_CONNECT" />
```

- 宿主应用如果接入 `jl_file_transfer_V1.0.0-release.aar`，需要在宿主 Manifest 中移除 `android.permission.MANAGE_EXTERNAL_STORAGE`。该权限属于 Android “所有文件访问”高敏权限，会影响 Google Play 等应用市场上架审核；`jl_ota` 的 OTA 文件选择与升级流程不应依赖该权限。

```xml
<uses-permission
    android:name="android.permission.MANAGE_EXTERNAL_STORAGE"
    tools:node="remove" />
```

### iOS

- 宿主应用**不需要** `rootViewController` 是 `FlutterViewController`
- Channel 注册完全由 `FlutterPluginRegistrar` 驱动，与 ViewController 层级无关
- 蓝牙权限需要在宿主应用的 `Info.plist` 中配置 `NSBluetoothAlwaysUsageDescription`
- 扫描设备的 `address` 字段在无 EDR MAC 时返回 `CBPeripheral.identifier`（UUID 格式），与 Android 的 MAC 地址格式不同

### 自动 OTA 调度注意事项

`example` 是人工流程：用户先连接设备，再选择本地文件并点击 OTA。宿主 App 如果使用自动流程（下载固件 -> 断开业务连接 -> 扫描重连 -> 传入本地路径 -> OTA），需要额外处理以下时序问题：

| 注意点 | 建议 |
|------|------|
| iOS 的 `otaConnection connected` 可能早于 OTA 通道真正可用 | 它可能只代表 BLE 物理连接成功，服务/特征、notify、设备认证、`getDeviceInfo` 还没完全完成。自动流程不要一收到该事件就无条件立刻 `startOTA`；短期可在 iOS 侧加 2~3 秒稳定等待，长期更推荐插件原生侧提供更准确的 `otaReady` 语义。 |
| 不要在调用 `startOTA` 前预设“校验文件” | “校验文件”应来自 `otaStateStream` 的 `KEY_STATE_WORKING + KEY_TYPE == Checking file`，否则 UI 会误导为 SDK 已进入校验阶段，实际可能只是 `startOTA` 还没真正跑起来。 |
| `connectDevice` 和 `startOTA` 应 `await` 并捕获异常 | MethodChannel 可能返回连接失败、文件不存在、路径无效等异常；自动流程必须把这些异常转成失败状态，否则会停在中间态。 |
| 需要防止重复启动 OTA | iOS/Android 都可能多次收到 connected 或状态回放。宿主侧应加一次性标志位，避免重复调用 `startOTA(path)`。 |
| 重新订阅事件流时可能收到上一次缓存状态 | 自动 OTA 处于 downloading/preparing/scanning/connecting 早期阶段时，应谨慎处理历史 `idle/error`，避免刚开始就被上一次失败状态打断。 |
| 扫描匹配要保留原始列表 index | `connectDevice(index)` 需要原生扫描列表的原始 index。如果宿主为了匹配设备把列表转成 map，仍必须保留原始 `List<ScanDevice>`，匹配后用原始 index 连接。 |
| iOS 设备地址格式不一定是 MAC | 宿主用业务设备 ID 匹配扫描结果时，要兼容 iOS `CBPeripheral.identifier` UUID 和 EDR MAC 两种格式；Android 通常是 MAC。 |
| 设备认证默认开启 | `jl_ota` 默认开启杰理设备认证。宿主一般不需要手动设置；如果目标固件未启用认证，需要与固件侧确认后再关闭，否则认证失败会导致连接断开。 |

宿主 App 可以采用的最小规避策略是：Android 保持连接后立即启动 OTA；iOS 收到 `otaConnection connected` 后先显示“正在启动 OTA”，等待约 2~3 秒再 `startOTA`，并且只有收到 SDK 的 `Checking file` 状态后才展示“正在校验文件”。这能接近 `example` 人工流程中的自然等待，但从插件设计上看，更彻底的方案仍是 iOS 原生在 paired/getDeviceInfo 完成后再发送明确的 OTA ready 事件。

---

## 七、Android 16KB page size 兼容问题

### 7.1 问题现象

宿主 App 接入 `jl_ota` 后，Android arm64 包体增大约 5.5MB。对 release APK 做 Google 16KB memory page size 兼容检查时，发现 `libconscrypt_jni.so` 的 ELF `LOAD` 段仍是 4KB 对齐：

```text
libconscrypt_jni.so  min_align=0x1000  FAIL
libjl_ota_auth.so    min_align=0x4000  OK
```

其中 `libjl_ota_auth.so` 来自杰理 OTA SDK，自身已经满足 16KB 对齐；失败项来自 `org.conscrypt:conscrypt-android:2.5.2` 间接引入的 `libconscrypt_jni.so`。

### 7.2 根本原因

`conscrypt-android:2.5.2` 内置的 64 位 so 使用旧的 4KB ELF segment alignment。Google 对 Android 15+ 目标设备的 16KB page size 要求中，64 位 native library 的 `LOAD` 段对齐不能低于 `2**14`，即 16KB。

### 7.3 修复方案

将 Android 侧 Conscrypt 依赖升级到 `2.5.3`：

```diff
- implementation "org.conscrypt:conscrypt-android:2.5.2"
+ implementation "org.conscrypt:conscrypt-android:2.5.3"
```

已单独验证 Maven Central 上的 `conscrypt-android:2.5.3`：

```text
jni/arm64-v8a/libconscrypt_jni.so  LOAD align 0x4000
jni/x86_64/libconscrypt_jni.so     LOAD align 0x4000
```

### 7.4 验证方式

宿主 App 重新打 release APK 后，需要同时验证 ELF 对齐和 APK zip 对齐。

ELF 对齐检查：

```bash
unzip APK_NAME.apk 'lib/arm64-v8a/*.so' -d /tmp/apk_so_check
$ANDROID_HOME/ndk/<ndk-version>/toolchains/llvm/prebuilt/darwin-x86_64/bin/llvm-readelf -l /tmp/apk_so_check/lib/arm64-v8a/libconscrypt_jni.so
```

`LOAD` 行最后一列 `Align` 需要是 `0x4000` 或更大。

APK zip 对齐检查：

```bash
$ANDROID_HOME/build-tools/<build-tools-version>/zipalign -c -P 16 -v 4 APK_NAME.apk
```

最后输出 `Verification successful` 才表示 APK zip 对齐通过。

---

## 八、Android 插件资源污染宿主 app name 问题

### 8.1 问题现象

宿主 App 调试安装后，桌面显示名称变成了 `jl_ota` 示例应用的名称，例如中文简体环境下显示为“杰理OTA升级”。

### 8.2 根本原因

问题不是 `example` 的 `AndroidManifest.xml` 被合入宿主 App。`jl_ota/android/src/main/AndroidManifest.xml` 没有声明 `application android:label`。

真正原因是插件库自身的 Android resources 定义了通用资源名 `app_name`：

```text
android/src/main/res/values/strings.xml
android/src/main/res/values-zh-rCN/strings.xml
android/src/main/res/values-ko-rKR/strings.xml
```

宿主 App 通常会在 Manifest 中使用：

```xml
android:label="@string/app_name"
```

当插件库也导出同名 `app_name`，资源合并后可能按 locale 命中插件侧资源。比如宿主只有默认 `values/app_name`，而插件提供了 `values-zh-rCN/app_name`，中文简体设备上会优先显示插件侧“杰理OTA升级”。

### 8.3 修复方案

插件库不应导出 `app_name` 这种宿主高概率使用的通用资源名。已从 `jl_ota/android/src/main/res` 删除插件库的 `app_name` 资源：

```text
android/src/main/res/values/strings.xml
android/src/main/res/values-zh-rCN/strings.xml
android/src/main/res/values-ko-rKR/strings.xml
```

`example/android/app/src/main/res` 下的 `app_name` 保留，示例应用仍可继续使用自己的显示名称。

### 8.4 验证方式

宿主 App 重新执行依赖解析和构建后，检查合并资源：

```bash
rg -n 'name="app_name"|杰理OTA|Jieli OTA' build/app/intermediates/incremental/<variant>/merge<Variant>Resources/merged.dir/values*
```

预期结果是宿主 variant 的 `app_name` 全部来自宿主 App，不再出现 `jl_ota` 插件库的 `Jieli OTA`、`杰理OTA升级`、`JieLi OTA`。

---

## 九、Android 模板资源污染宿主问题

### 9.1 问题现象

除了 `app_name`，插件库中还残留了从 Flutter example 工程带过来的模板资源。这些资源名称非常通用，宿主 App 也经常会使用同名资源，合并后可能影响宿主启动页、图标、主题等资源解析。

与宿主 App 资源重名的典型项：

```text
drawable/launch_background
mipmap/ic_launcher
style/LaunchTheme
style/NormalTheme
```

### 9.2 根本原因

这些资源属于示例 App 的 UI/启动页资源，不属于 Flutter 插件库的运行依赖。插件库导出这类通用资源名，会扩大宿主资源命名空间污染面。

`jl_ota/android/src/main/AndroidManifest.xml` 没有引用这些资源，插件代码也没有引用以下模板资源：

```text
drawable/launch_background
mipmap/ic_launcher
mipmap/ic_logo
style/LaunchTheme
style/NormalTheme
style/AppTheme
color/colorPrimary
color/colorPrimaryDark
color/colorAccent
color/white
color/main_color
color/blue_398BFF
xml/provider_paths
```

### 9.3 修复方案

已从插件库 `jl_ota/android/src/main/res` 删除上述模板资源。对照 `party_x -> mix_device -> jl_ota` 的实际调用链后，剩余 `strings.xml` 文案也不会作为宿主用户可见文案展示，因此已将源码中的 `R.string.*` 依赖改为 native 常量，并删除插件库剩余的 Android string resources。

不会进入 `party_x` UI 的剩余文案包括：

```text
classic_device_type
ble_device_type
dual_mode
unknown_device
ota_complete
ota_upgrade_cancel
update_file
log_file
connect_wifi_tips
```

未被源码实际引用的权限提示和设备强制升级提示也已删除：

```text
open_gpg_tip
open_bluetooth_tip
grant_bluetooth_permission
grant_location_permission
grant_external_storage_permission
device_must_mandatory_upgrade
```

`example/android/app/src/main/res` 下的同名模板资源和示例 App 文案保留，示例 App 仍然正常使用自己的图标、启动页、主题、provider 配置和多语言资源。

### 9.4 验证方式

检查插件库资源和宿主资源交集：

```bash
# 目标：插件库不再导出 launch_background、ic_launcher、LaunchTheme、NormalTheme 等宿主常用资源名
find jl_ota/android/src/main/res -type f
```

宿主 App 重新解析依赖并构建后，检查合并资源中不应再出现插件库来源的模板资源或 `jl_ota` 插件库 Android string resources。

---

## 十、iOS 插件资源隔离与文案清理

### 10.1 检查结论

iOS 没有发现与 Android `app_name` 相同的宿主显示名称污染问题。`jl_ota` 插件库本身没有提供 `InfoPlist.strings` 或 `CFBundleDisplayName`，这些只存在于 `example/ios/Runner/Sources`，属于示例 App 自己的资源。

原 podspec 使用 `resource_bundles` 打包插件资源：

```ruby
s.resource_bundles = {
  'JlOta' => ['Resources/**/*'],
  'jl_ota_privacy' => ['Resources/PrivacyInfo.xcprivacy']
}
```

`resource_bundles` 会生成独立 bundle，不会像 Android resources 那样直接合并成宿主主资源表。不过 `Resources/**/*` 会把示例 `Localizable.strings` 和 `PrivacyInfo.xcprivacy` 一起打入 `JlOta.bundle`，同时又通过 `jl_ota_privacy` 打一次隐私清单，资源边界不够干净。

### 10.2 修复方案

对照 `party_x -> mix_device -> jl_ota` 的实际 OTA 调用链，用户可见文案由 `party_x` 的 `R.tr.device.device_ota_preparing` 和 `R.tr.device.device_ota_checking_file` 处理，插件原生 `Localizable.strings` 不应参与宿主 UI。

因此 iOS 侧已做以下清理：

```text
ios/Resources/en.lproj/Localizable.strings
ios/Resources/ko.lproj/Localizable.strings
ios/Resources/zh-Hans.lproj/Localizable.strings
```

插件源码中原先读取 `Localizable` 的位置已改为内部英文常量，仅作为 native 错误 message 或 toast fallback，不作为宿主 App 多语言展示来源。`example/ios/Runner/Sources` 下的 `Localizable.strings` 和 `InfoPlist.strings` 保留，示例 App 仍可使用自己的多语言文案和显示名称。

podspec 已调整为只保留 iOS 隐私清单：

```ruby
s.resource_bundles = {
  'jl_ota_privacy' => ['Resources/PrivacyInfo.xcprivacy']
}
```

### 10.3 验证方式

检查插件库不再导出业务多语言资源：

```bash
find jl_ota/ios/Resources -maxdepth 3 -type f
```

预期只剩：

```text
jl_ota/ios/Resources/PrivacyInfo.xcprivacy
```

检查插件库源码不再读取 `Localizable`：

```bash
rg -n 'Localizable|languageText|kJL_TXT|CFBundleDisplayName|InfoPlist.strings' jl_ota/ios/Classes jl_ota/ios/Resources jl_ota/ios/jl_ota.podspec
```

预期不再出现插件业务文案资源读取；`CFBundleDisplayName` 和 `InfoPlist.strings` 只应出现在 `example/ios/Runner`。
