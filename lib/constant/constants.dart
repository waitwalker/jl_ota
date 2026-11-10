/// 全局通用常量与配置参数定义类
class AppConstants {
  /// 用户服务协议在线文档地址
  static const String userAgreementUrl = 'https://cam.jieliapp.com/app/app.user.service.protocol.html';

  /// 隐私保护政策在线文档地址
  static const String privacyPolicyUrl = 'https://cam.jieliapp.com/app/JL_OTA_app_privacy_policy.html';

  /// 蓝牙通信方式：低功耗蓝牙（BLE, Bluetooth Low Energy）
  static const int communicationWayBle = 0;

  /// 蓝牙通信方式：经典蓝牙串口协议（SPP, Serial Port Profile）
  static const int communicationWaySpp = 1;

  /// 蓝牙通信方式：基于经典蓝牙 BR/EDR 物理链路的 GATT 协议
  static const int communicationWayGattOverBrEdr = 2;

  /// 工信部 ICP 备案号文本
  static const String icpNumber = '粤ICP备18069041号-15A';

  /// 工信部 ICP 备案查询官方网址
  static const String icpUrl = 'https://beian.miit.gov.cn/';

  /// 本地存储 Key：记录用户是否已同意隐私协议与服务条款
  static const String agreePolicy = 'agreePolicy';

  /// 本地存储 Key：设备扫描过滤条件配置内容
  static const String filterContent = 'filterContent';

  /// 本地存储 Key：OTA 升级固件包存储目录路径
  static const String otaPath = 'otaPath';

  /// 杰理默认固件升级文件名（ufw 格式）
  static const String updateFileName = 'upgrade.ufw';

  /// 固件升级目标标识：SDK 固件
  static const String sdkName = 'sdk';

  /// 固件升级目标标识：App 资源
  static const String appName = 'app';

  /// 蓝牙连接状态：已断开连接
  static const int connectionDisconnect = 0;

  /// 蓝牙连接状态：连接成功
  static const int connectionOK = 1;

  /// 蓝牙连接状态：连接失败
  static const int connectionFailed = 2;

  /// 蓝牙连接状态：正在建立连接中
  static const int connectionConnecting = 3;

  /// Android 13 操作系统版本代码（API 33，对应 Tiramisu）
  static const int TIRAMISU = 33;

  /// 通用弹窗底部操作按钮的标准高度（逻辑像素）
  static const double dialogButtonHeight = 45.0;

  /// 顶部应用栏返回按钮图标的标准尺寸（逻辑像素）
  static const double returnIconSizeValue = 28.0;
}
