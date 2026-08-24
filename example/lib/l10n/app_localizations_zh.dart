// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appName => '杰理OTA升级';

  @override
  String get devices => '设备';

  @override
  String get update => '升级';

  @override
  String get settings => '设置';

  @override
  String currentLanguage(String language) {
    return '当前语言：$language';
  }

  @override
  String get connect => '连接';

  @override
  String get disconnect => '断开连接';

  @override
  String get filter => '设备过滤条件';

  @override
  String get deviceList => '设备列表';

  @override
  String get cancel => '取消';

  @override
  String get confirm => '确定';

  @override
  String get pleaseSetFilter => '请设置过滤条件';

  @override
  String get copyRight => '©2021–2025 珠海杰理科技有限公司 保留所有权利';

  @override
  String get companyName => '珠海杰理科技有限公司';

  @override
  String get privacyPolicyDialogTitle => '用户协议和隐私政策';

  @override
  String get welcomeMessage => '　欢迎使用杰理OTA升级！\n　我们非常重视您的隐私保护和个人信息保护，在您使用“杰理OTA升级”服务之前，请务必认真阅读';

  @override
  String get userAgreement => '《用户协议》';

  @override
  String get and => '及';

  @override
  String get privacyPolicy => '《隐私政策》';

  @override
  String get agreementText => '，并充分理解协议条款内容。\n　如您同意并接受本提示及相关协议内容，请点击同意，开始接受我们的服务。';

  @override
  String get agreeButton => '同意';

  @override
  String get disagreeButton => '不同意并退出';

  @override
  String get btConnecting => '连接中...';

  @override
  String get save => '保存';

  @override
  String get logLocation => '打印日志位置：';

  @override
  String get deviceAuthentication => '设备认证';

  @override
  String get hidDevice => 'HID设备';

  @override
  String get customReconnectMethod => '自定义回连方式';

  @override
  String get currentCommunicationMethod => '当前通讯方式';

  @override
  String get communicationWayBle => 'BLE';

  @override
  String get communicationWaySpp => 'SPP';

  @override
  String get communicationWayGatt => 'GATT Over BR/EDR';

  @override
  String get adjustMtu => '调整MTU';

  @override
  String get logFile => 'Log文件';

  @override
  String get sdkVersion => 'SDK版本号';

  @override
  String get aboutApp => '关于APP';

  @override
  String get saveAndRestartMessage => '保存设置，需重启App生效，确定重启？';

  @override
  String get restart => '重启';

  @override
  String get failedToSaveSettings => '保存设置失败';

  @override
  String get connectUsingSdkBluetooth => '使用SDK蓝牙连接';

  @override
  String get currentAppVersion => '当前版本';

  @override
  String get icpInfo => 'ICP备案信息';

  @override
  String get isDeleteAllLogFiles => '是否删除所有Log文件?';

  @override
  String get deviceStatus => '设备状态';

  @override
  String get connected => '已连接';

  @override
  String get disconnected => '未连接';

  @override
  String get deviceType => '设备类型';

  @override
  String get unknownType => '未知类型';

  @override
  String get classicBluetooth => '经典蓝牙';

  @override
  String get bleDevice => 'BLE设备';

  @override
  String get dualModeBluetooth => '双模蓝牙设备';

  @override
  String get fileSelection => '文件选择';

  @override
  String get delete => '删除';

  @override
  String get localAdd => '本地添加';

  @override
  String get computerTransfer => '电脑传输';

  @override
  String get scanDownload => '扫码下载';

  @override
  String get saveFile => '保存文件';

  @override
  String get serviceStarted => '服务已开启';

  @override
  String get ensureConnection => '请确保连接设备在同一个Wi-Fi下，或连到此设备的热点上';

  @override
  String get copySuccess => '复制成功，请在连接设备的浏览器中打开';

  @override
  String get collapse => '收起';

  @override
  String get copyAddress => '复制地址';

  @override
  String get selectUpgradeFile => '请选择升级文件';

  @override
  String get upgradeProcessTip => '(升级过程中，请保持蓝牙和网络打开状态)';

  @override
  String get fileVerificationComplete => '校验文件完成，正在回连设备…';

  @override
  String get reason => '原因: %s';

  @override
  String get otaComplete => '升级完成';

  @override
  String get otaFinish => '升级结束';

  @override
  String get otaUpgrading => '正在升级';

  @override
  String get otaUpgradeCancel => '升级已取消';

  @override
  String get otaUpgradeNotStarted => '升级未开始';

  @override
  String get otaCheckingUpgradeFile => '正在检验升级文件';

  @override
  String get otaUpgradeFailed => '升级失败: %s';

  @override
  String get otaCheckFile => '校验文件中';

  @override
  String get updateFailed => '升级失败';

  @override
  String get unknownError => '未知错误';

  @override
  String get scanQrcode => '扫一扫';

  @override
  String get photos => '相册';

  @override
  String get qrcodeIntoBox => '将二维码/条码放入框内';

  @override
  String get failPhotosSystemReason => '由于系统原因, 无法访问相册';

  @override
  String get accessCameraReason => '需要访问相机，用于扫描二维码进行下载资源';

  @override
  String get accessPhotosReason => '需要访问相册，用于扫描二维码进行下载资源';

  @override
  String get systemSetCamera => '此功能需要使用到你的相机,请前往系统设置权限';

  @override
  String get systemSetExternalStorage => '此功能需要使用到你的手机存储,请前往系统设置权限';

  @override
  String get downloadSavePending => '存储文件。请有点耐心…';

  @override
  String get downloadingFile => '下载文件中';

  @override
  String get downloadSuccessful => '下载成功';

  @override
  String get downloadCompleted => '下载完成';

  @override
  String get pleaseRefreshWeb => '上传成功，请刷新网页端';

  @override
  String get pressAgainToExit => '再按一次退出应用';

  @override
  String get notFoundQRCode => '未发现二维码';

  @override
  String get fileShare => '文件共享';

  @override
  String get shareUfwFile => '共享ufw文件';

  @override
  String get shareUfwFileTips => '从第三方APP（微信/钉钉）通过\"其他应用打开\">打开ufw文件，共享到当前OTA升级中';

  @override
  String get deviceMustMandatoryUpgrade => '设备需要强制升级';

  @override
  String get bluetoothDisconnected => '蓝牙已断开';

  @override
  String get gattUuidPlaceholder => '请输入一个或多个 UUID，使用逗号或换行分隔';

  @override
  String get gattServiceUuid => 'GATT Service UUID';

  @override
  String get gattUuidTips => '示例: 180A, 0000180D-0000-1000-8000-00805F9B34FB';

  @override
  String get gattUuidErrorEmpty => '请输入至少一个 UUID';

  @override
  String get gattUuidErrorInvalidFmt => '以下 UUID 格式无效:\n%s';

  @override
  String get customCommand => '自定义命令';

  @override
  String get sendCustomCmd => '发送自定义命令';

  @override
  String get receivedData => '接收的数据';

  @override
  String get inputData => '输入的数据';
}
