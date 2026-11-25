# Flutter 3.50 原生互操作与 jl_ota 迁移方案

> 调研日期：2026-11-17。本文是迁移设计，不代表项目已经迁移或预览方案已经通过真机验证。版本和工具能力可能变化，实施时应重新核对官方文档。

## 1. 技术介绍

### 1.1 当前的消息通道

Flutter 的 `MethodChannel` 将方法名、参数和结果编码为消息，由 Flutter Engine 和原生侧的消息处理器传递；`EventChannel` 用于持续的原生事件。Dart 侧一般以 `Future` 或 `Stream` 接收结果。优点是与 Flutter Engine 的生命周期结合明确、跨平台支持成熟；缺点是手写字符串和动态 `Map` 容易出现拼写或类型不一致。

平台通道在 Flutter 3.50 仍受支持，没有要求现有插件必须迁移。事件频率和有效载荷决定优化收益，不能只凭“少一次消息往返”断言 OTA 更快。[平台通道文档](https://docs.flutter.dev/platform-integration/platform-channels)

### 1.2 FFIgen 与 JNIgen

- **FFIgen** 从 C 或 Objective-C 头文件生成 Dart 绑定，通过 `dart:ffi` 调用原生 API。Swift 只能通过 Objective-C 可见的接口间接接入，例如兼容 Objective-C 的 `@objc` 接口；纯 Swift 的泛型、结构体等不能直接按 Objective-C API 处理。直接 Swift 互操作仍属于实验性能力。[FFIgen 文档](https://docs.flutter.dev/interop/ffigen)
- **JNIgen** 从 Java/Kotlin 编译产物等生成 Dart 绑定，通过 JNI 调用 JVM 中的类；`package:jni` 提供运行时支持。Kotlin 的协程、属性和默认参数应以生成器实际支持的 Java/JVM 接口为准，不能假设所有 Kotlin 语义原样映射。[JNIgen 文档](https://docs.flutter.dev/interop/jnigen)
- 它们是**自底向上**的绑定：Dart 看见的是平台各自的 API。调用可以同步发生在发起线程，因而必须自己处理线程、对象引用、回调及资源释放，也要继续处理 Android 权限与 Activity、iOS 主线程等约束。

### 1.3 Pigeon：统一契约，两种传输方式

Pigeon 以 Dart schema 的 `@HostApi`（Dart → 原生）和 `@FlutterApi`（原生 → Dart）生成类型化接口。它提供两种后端：

| 方案 | 实现 | 适合本项目的场景 |
| --- | --- | --- |
| 平台通道 | 生成类型安全的消息通道代码 | 当前 BLE/OTA 命令和状态事件，优先用于生产迁移 |
| Native Interop | Android 通过 JNIgen/JNI，iOS 通过 FFIgen 和生成的 Objective-C 桥接 | 性能敏感路径的受控验证，当前为预览 |

**重要边界**：Pigeon 29 已加入实验性 FFI/JNI；截至调研日的 30.0.x 文档仍明确将 Native Interop 标为 **preview，不适合直接用于生产**。底层 FFIgen/JNIgen 可用，不等于 Pigeon 的直连后端已稳定。默认生成的 Pigeon 接口仍走平台通道；只有显式启用 `useJni` / `useFfi` 并使用对应创建方式，才走直接互操作。[Pigeon 官方指南](https://docs.flutter.dev/interop/pigeon)、[30.0.1 文档](https://pub.dev/packages/pigeon/versions/30.0.1)、[版本记录](https://pub.dev/packages/pigeon/changelog)

直连也不等于所有数据零拷贝：标量、字符串、枚举、部分 typed data 直接跨边界，而数据类、列表和 Map 等可能编码到缓冲区。同步调用会阻塞当前 isolate；`@async` 并不自动把业务放到后台线程。线程调度及复制成本应以实际实现和测量为准。[Native Interop 指南](https://github.com/flutter/packages/blob/main/packages/pigeon/native_interop_guide.md)

## 2. 本插件现状

| 层 | 文件与职责 |
| --- | --- |
| Dart 命令 | `lib/ble_method.dart` 使用 `com.jieli.ble_plugin/methods`，方法及参数名集中在 `lib/constant/ble_method_constants.dart`。 |
| Dart 事件 | `lib/ble_event_stream.dart` 从 `com.jieli.ble_plugin/events` 获取广播流，按 `type`/`value` 解析蓝牙、扫描、连接和 OTA 等事件。 |
| Android | `android/src/main/kotlin/com/jieli/otasdk/JlOtaPlugin.kt` 管理 Engine、Activity、权限和 `BlePlugin` 生命周期；`MethodChannelHandler`、`EventChannelHandler` 负责命令和事件。`OtaRuntime` 是进程级对象。 |
| iOS | `ios/Classes/BlePlugin.swift` 注册通道；`MethodChannelHandler.swift` 和 `EventChannelHandler.swift` 分发调用与事件，底层包含 `OtaManager.shared` 和杰理 SDK 单例。 |
| 打包 | Android 使用本地 AAR；iOS 有 CocoaPods 和 `ios/jl_ota/Package.swift` / XCFramework 路径，不能只验证其中一种。 |

当前公开 API 的语义必须先冻结：例如 `startScan`、`connectDevice(index)`、`startOTA(path)` 的完成结果与后续连接或 OTA 完成事件不是同一件事；保留原有 `Future`、广播流、错误、事件顺序和无监听者时的行为。`index` 对应的扫描列表可能变化，迁移时先保持旧契约；如改为设备标识，应另行设计版本化 API，而非悄悄改变含义。

Android 与 iOS 的已实现方法并不完全一致：例如 iOS 的 `MethodChannelHandler.swift` 当前未处理 BLE MTU 相关 case。应逐项核对两端实际 switch 和行为，记录不支持项，不能根据 Dart 常量假定两端都有实现。

## 3. 建议的迁移路线

**先用 Pigeon 平台通道建立统一契约；直连作为独立实验后端，不替换生产默认路径。** OTA 真正的数据写入主要发生在原生 SDK 和蓝牙栈之间；当前 Dart 通道主要用于控制与状态通知，因此先测量再判断是否值得切换传输层。不要直接用 JNIgen/FFIgen 把两套厂商 SDK 暴露给应用，否则 Dart 会承担两套平台 API、引用管理和厂商升级成本。

### 阶段 A：建立类型化契约，保持行为

1. 梳理 `BleMethodConstants`、两个原生 `MethodChannelHandler` 的实际 case，以及 `BleEventConstants` 的事件与数据字段；记录每端返回值、错误码、线程和触发时序。针对 iOS/Android 差异保留兼容行为，不把缺失功能伪装成成功。
2. 新建 `pigeons/jl_ota_api.dart`，定义 `@HostApi` 命令和 `@FlutterApi` 回调；先覆盖 `getSdkVersion` 等低风险查询，再覆盖扫描、连接和 OTA。使用类型化 DTO 承载扫描设备、连接状态和 OTA 进度；保留原有字段与空值语义。示例仅表示设计，不是可直接投入生产的完整 schema：

   ```dart
   import 'package:pigeon/pigeon.dart';

   @HostApi()
   abstract class OtaHostApi {
     String getSdkVersion();
     @async
     bool startScan();
     @async
     bool connectDevice(int index);
     @async
     bool startOta(String path);
   }

   @FlutterApi()
   abstract class OtaFlutterApi {
     void onOtaProgress(int progress);
   }
   ```

   具体 `@async`、错误和返回类型必须以现有实现为准；不能把同步获取状态改为等待整个升级完成，也不能从上例推断现有返回值已是 `bool`。
3. 在插件根目录添加并固定经过验证的 Pigeon 版本，配置 Dart/Kotlin/Swift 输出路径，使用 `fvm dart run pigeon --input pigeons/jl_ota_api.dart` 生成；依赖及生成代码纳入版本管理。默认不启用 `useFfi`/`useJni`。生成代码版本与两端代码必须来自同一 schema，避免宿主与 Dart 接口错配。
4. 在 Android/iOS 写薄适配器调用现有业务管理器，避免同时重写蓝牙/OTA 状态机。`JlOtaPlugin` 的 Engine/Activity 附加、旋转重绑、权限结果和解绑释放仍须保留；iOS 在 registrar 的 Engine 范围注册并在销毁时解除。
5. 在 Dart 内部以适配层调用生成 API，将原生回调转为广播 `Stream`，继续暴露现有 `BleMethod`/`BleEventStream` 接口。明确注册、首次订阅、最后取消、dispose、热重启以及回调到已销毁 isolate 时的处理；不要同时从旧、新两条路径重复派发同一事件。迁移初期可逐方法保留旧通道回退，但一项调用只能选择一个后端。

### 阶段 B：小范围试验 Native Interop

1. 选择单个只读、无 Activity 依赖的查询（如 SDK 版本；先核对两端实际实现和错误语义），保持现有通道作基线。先在独立实验分支固定 Pigeon 版本，记录 Flutter/Dart、Xcode、JDK、Android SDK 与 AGP 版本。
2. 在 schema 的 `PigeonOptions` 中设置 `appDirectory: 'example/'`，Android 配 `KotlinOptions(useJni: true)`，iOS 配 `SwiftOptions(useFfi: true, ffiModuleName: ...)`。`ffiModuleName` 必须按实际生成 Swift 所属模块确定，不能照搬示例应用的 `Runner`。具体输出路径和生成器选项以所固定版本的官方指南及生成结果为准。
3. 依照官方指南在**插件根** `pubspec.yaml` 声明 `pigeon`、`jnigen`、`ffigen`、`jni`、`objective_c`、`ffi` 等生成器、运行时和配置脚本所需依赖。JNIgen 需 Android SDK，官方指南要求 JNIgen 1.0.0+ 才能解析较新 Kotlin metadata；FFIgen 需 Xcode/LLVM。生成器依赖清单会随版本变化，不要把上述列表视为完整且永久固定。[官方端到端步骤](https://github.com/flutter/packages/blob/main/packages/pigeon/native_interop_guide.md)
4. JNIgen 需要可解析的已编译类及正确 classpath。按官方指南先完成必要的原生编译，再运行生成器；这是构建，必须先获得用户明确授权。生成入口仍使用 `fvm dart run pigeon --input pigeons/jl_ota_api.dart`。检查生成日志与产物，避免 Android SDK 未配置时跳过 JNIgen 却误以为成功。
5. Swift FFI 中间层可能生成 `.h` 和 `.m`：CocoaPods 的 source files 必须包含实际生成的 Swift/Objective-C 文件；SwiftPM 需根据产物设置独立 Objective-C target 和依赖，仅存在头文件时不能创建没有可编译源文件的 target。不能提交生成过程产生的临时 `.o`。本项目须分别验证 CocoaPods、SwiftPM 及实际设备架构和符号可见性。
6. 根据固定版本的生成 API，原生注册实例、Dart 通过 `createWithNativeInteropApi()` 获取；在 Engine detach 和 Dart 取消注册时对称释放。先只对试验接口启用；无有效实例、插件尚未注册或生成物不可用时应明确报错/走指定回退，不能静默返回成功。
7. 真机验证扫描、断连、重连、OTA、后台与前台切换，测量延迟、事件速率、CPU、内存和卡帧，并与同版本平台通道对照。只有官方稳定性、兼容性、性能数据和回滚方案均满足发布要求后，才考虑扩展范围。

### 阶段 C：发布和回滚

保持旧 Dart 公共 API，先发布带双后端能力但默认平台通道的版本；性能实验需明确配置并留有关闭开关。稳定后按独立版本说明发布迁移，包括最低 Flutter/Dart 版本、生成代码和宿主配置变化。只有在消费者迁移完成且支持策略明确后才移除旧 MethodChannel/EventChannel；回滚时应能恢复旧注册与 Dart 适配器，不改变设备连接和 OTA 业务语义。

## 4. 生命周期、线程与风险

- **线程**：JNI/FFI 调用在调用线程同步执行；不要把耗时工作放在 UI isolate。涉及 Android Activity、权限弹窗、UIKit 的操作必须切换到原生主线程。异步回调应保证目标 isolate 仍存活，并避免原生线程等待 Dart、Dart 又同步等待原生造成死锁。
- **事件与释放**：扫描、连接、OTA 回调是持续流，不会因为绑定生成而自动拥有 `EventChannel` 的订阅语义。保留事件顺序、错误及取消规则；关闭回调引用，Android JNI 对象按 API 使用 `.release()` / `.using()`，Objective-C 对象注意引用环和线程。不要假定 GC 会及时释放 SDK、Activity 或回调。
- **多 Engine / isolate**：Pigeon 30 已改进按 Engine 注册和路由，但不是所有 Flutter 版本的 registrar/binding 都暴露精确 Engine ID，后台 isolate 也可能无法精确识别；回退到最近注册实例可能串 Engine。对于持有 Activity、UIViewController 或其他 Engine 专属状态的接口，应按官方建议使用独立 `messageChannelSuffix`，或保留 Engine 范围的平台通道；逐一验证注册、detach、热重启及 `unregistered-instance`。`OtaRuntime`、`OtaManager.shared` 等现有进程级单例也需要单独设计并发、所有权和事件分发，Pigeon 不会自动隔离它们。[多 Engine 限制](https://pub.dev/packages/pigeon/versions/30.0.1)
- **平台生命周期**：Android 无 Activity、权限拒绝、配置变更和 headless Engine 要有明确结果；自建 headless Engine 使用 JNI 时需按官方指南初始化 `JniPlugin`。iOS 注意插件注册、前台界面和 Engine 解绑。
- **打包和设备**：JNI 类混淆/R8、AAR 依赖、ABI；iOS 的 CocoaPods/SwiftPM、Objective-C 桥、framework 链接和架构均需验证。仓库已有模拟器占位实现及已知限制，见 `docs/ios-simulator.md`；它不能证明真机蓝牙和 OTA 功能。
- **安全与兼容**：文件路径校验、蓝牙权限、设备认证、错误码和调用方兼容性不能因换传输层而弱化；发布前应核对固定生成器版本与插件最低 SDK 约束。

## 5. 验收清单

1. 对照旧接口逐项验证两平台：参数、返回值、异常、无 Activity、权限拒绝、扫描、连接、断连、回连、OTA 进度与完成/失败事件；不支持能力返回清晰结果。
2. 测试订阅/取消/重订阅、重复初始化、热重启、Engine 销毁、双 Engine 与后台 isolate；确认没有旧回调、跨 Engine 串事件或引用泄漏。
3. 构建并验证 Android debug/release 与 iOS 真机，以及需要支持的模拟器、SwiftPM/CocoaPods 宿主；涉及构建时先取得用户明确许可。用真实设备执行 BLE/SPP 与 OTA 回归。
4. 对相同设备、固件、事件频率和测试时长对照两种后端的延迟、CPU、内存、卡帧；确认收益后再决定是否继续。生成代码需可重现，检查 `fvm flutter analyze` 与项目已有测试，禁止为本次验证擅自新增测试文件。

## 参考资料

- [Flutter Native interop 总览](https://docs.flutter.dev/interop)
- [Pigeon 指南与预览状态](https://docs.flutter.dev/interop/pigeon)
- [Pigeon Native Interop 完整配置及线程/多 Engine 指南](https://github.com/flutter/packages/blob/main/packages/pigeon/native_interop_guide.md)
- [Pigeon 30.0.1 文档](https://pub.dev/packages/pigeon/versions/30.0.1)及[版本记录](https://pub.dev/packages/pigeon/changelog)
- [FFIgen](https://docs.flutter.dev/interop/ffigen)、[JNIgen](https://docs.flutter.dev/interop/jnigen)、[JNIgen 包文档](https://pub.dev/packages/jnigen)
- [Dart FFI 与 code assets](https://docs.flutter.dev/interop/bind-native-code)
