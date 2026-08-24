// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Japanese (`ja`).
class AppLocalizationsJa extends AppLocalizations {
  AppLocalizationsJa([String locale = 'ja']) : super(locale);

  @override
  String get appName => 'JieLi OTA';

  @override
  String get devices => 'デバイス';

  @override
  String get update => 'アップグレード';

  @override
  String get settings => '設定';

  @override
  String currentLanguage(String language) {
    return '現在の言語は $language です';
  }

  @override
  String get connect => '接続';

  @override
  String get disconnect => '切断';

  @override
  String get filter => 'フィルター';

  @override
  String get deviceList => 'デバイスリスト';

  @override
  String get cancel => 'キャンセル';

  @override
  String get confirm => '確認';

  @override
  String get pleaseSetFilter => 'フィルターを設定してください';

  @override
  String get copyRight => '©2021–2025 Zhuhai Jieli Technology co., LTD すべての権利を保有します';

  @override
  String get companyName => '珠海ジェリーテクノロジー株式会社';

  @override
  String get privacyPolicyDialogTitle => '利用規約とプライバシーポリシー';

  @override
  String get welcomeMessage => '　ジェリーOTAアップデートへようこそ！\n　私たちはあなたのプライバシーと個人情報保護を非常に重視しています。\"ジェリーOTAアップデート\"サービスをご利用になる前に、必ずお読みください';

  @override
  String get userAgreement => '《利用規約》';

  @override
  String get and => 'および';

  @override
  String get privacyPolicy => '《プライバシーポリシー》';

  @override
  String get agreementText => 'を理解し、同意してください。\n　本通知および関連する規約内容に同意される場合は、「同意する」をクリックしてサービスをご利用ください。';

  @override
  String get agreeButton => '同意する';

  @override
  String get disagreeButton => '同意せず終了';

  @override
  String get btConnecting => '接続中...';

  @override
  String get save => '保存する';

  @override
  String get logLocation => 'ログ位置：';

  @override
  String get deviceAuthentication => 'デバイス認証';

  @override
  String get hidDevice => 'HIDデバイス';

  @override
  String get customReconnectMethod => 'カスタム再接続方法';

  @override
  String get currentCommunicationMethod => '現在の通信方法';

  @override
  String get communicationWayBle => 'BLE';

  @override
  String get communicationWaySpp => 'SPP';

  @override
  String get communicationWayGatt => 'GATT Over BR/EDR';

  @override
  String get adjustMtu => 'MTUを調整';

  @override
  String get logFile => 'ログファイル';

  @override
  String get sdkVersion => 'SDKバージョン';

  @override
  String get aboutApp => 'アプリについて';

  @override
  String get saveAndRestartMessage => '設定を保存しました。アプリを再起動して変更を適用しますか？';

  @override
  String get restart => '再起動';

  @override
  String get failedToSaveSettings => '設定の保存に失敗しました';

  @override
  String get connectUsingSdkBluetooth => 'SDKのBluetoothを使用して接続';

  @override
  String get currentAppVersion => '現在のバージョン';

  @override
  String get icpInfo => 'ICP登録情報';

  @override
  String get isDeleteAllLogFiles => 'すべてのログファイルを削除してもよろしいですか?';

  @override
  String get deviceStatus => 'デバイス状態';

  @override
  String get connected => '接続済み';

  @override
  String get disconnected => 'Disconnected';

  @override
  String get deviceType => 'Device Type';

  @override
  String get unknownType => '不明なタイプ';

  @override
  String get classicBluetooth => 'クラシックBluetooth';

  @override
  String get bleDevice => 'BLEデバイス';

  @override
  String get dualModeBluetooth => 'デュアルモードBluetooth';

  @override
  String get fileSelection => 'ファイル選択';

  @override
  String get delete => '削除（さくじょ）';

  @override
  String get localAdd => 'ローカル追加';

  @override
  String get computerTransfer => 'PC転送';

  @override
  String get scanDownload => 'QRコードダウンロード';

  @override
  String get saveFile => 'ファイルを保存';

  @override
  String get serviceStarted => 'サービスが開始されました';

  @override
  String get ensureConnection => '接続デバイスが同じWi-Fiに接続されているか、このデバイスのホットスポットに接続されていることを確認してください';

  @override
  String get copySuccess => 'コピー成功、接続デバイスのブラウザで開いてください';

  @override
  String get collapse => '折りたたむ';

  @override
  String get copyAddress => 'アドレスをコピー';

  @override
  String get selectUpgradeFile => 'アップグレードファイルを選択してください';

  @override
  String get upgradeProcessTip => '(アップグレード中はBluetoothとネットワークを有効にしたままにしてください)';

  @override
  String get fileVerificationComplete => 'ファイルの検証が完了しました。デバイスに再接続中…';

  @override
  String get reason => '原因: %s';

  @override
  String get otaComplete => 'アップグレード完了';

  @override
  String get otaFinish => 'アップグレード終了';

  @override
  String get otaUpgrading => 'アップグレード中';

  @override
  String get otaUpgradeCancel => 'アップグレードがキャンセルされました';

  @override
  String get otaUpgradeNotStarted => 'アップグレードが開始されていません';

  @override
  String get otaCheckingUpgradeFile => 'アップグレードファイルを確認中';

  @override
  String get otaUpgradeFailed => 'アップグレード失敗: %s';

  @override
  String get otaCheckFile => 'ファイルを検証中';

  @override
  String get updateFailed => 'アップデート失敗';

  @override
  String get unknownError => '不明なエラー';

  @override
  String get scanQrcode => 'QRコードをスキャン';

  @override
  String get photos => 'アルバム';

  @override
  String get qrcodeIntoBox => 'QRコード/バーコードを枠内に配置してください';

  @override
  String get failPhotosSystemReason => 'システムの理由により、アルバムにアクセスできません';

  @override
  String get accessCameraReason => 'リソースをダウンロードするためのQRコードをスキャンするには、カメラへのアクセスが必要です';

  @override
  String get accessPhotosReason => 'リソースをダウンロードするためのQRコードをスキャンするには、アルバムへのアクセスが必要です';

  @override
  String get systemSetCamera => 'この機能にはカメラの使用が必要です。システム設定で権限を付与してください';

  @override
  String get systemSetExternalStorage => 'この機能には電話のストレージの使用が必要です。システム設定で権限を付与してください';

  @override
  String get downloadSavePending => 'ファイルを保存中。しばらくお待ちください…';

  @override
  String get downloadingFile => 'ファイルをダウンロード中';

  @override
  String get downloadSuccessful => 'ダウンロード成功';

  @override
  String get downloadCompleted => 'ダウンロード完了';

  @override
  String get pleaseRefreshWeb => 'アップロード成功。ウェブページを更新してください';

  @override
  String get pressAgainToExit => 'もう一度タップで終了します';

  @override
  String get notFoundQRCode => 'QRコードが見つかりません';

  @override
  String get fileShare => 'ファイル共有';

  @override
  String get shareUfwFile => 'ufwファイルを共有';

  @override
  String get shareUfwFileTips => 'サードパーティ製アプリ（WeChat/DingTalk）から「他のアプリで開く」＞ ufwファイルを開き、現在のOTAアップグレードに共有します';

  @override
  String get deviceMustMandatoryUpgrade => 'デバイスは強制アップデートが必要です';

  @override
  String get bluetoothDisconnected => 'Bluetoothが切断されました';

  @override
  String get gattUuidPlaceholder => 'UUIDを1つ以上入力してください。コンマまたは改行で区切ってください';

  @override
  String get gattServiceUuid => 'GATTサービスUUID';

  @override
  String get gattUuidTips => '例：180A, 0000180D-0000-1000-8000-00805F9B34FB';

  @override
  String get gattUuidErrorEmpty => '少なくとも1つのUUIDを入力してください';

  @override
  String get gattUuidErrorInvalidFmt => '無効なUUID形式:\n%s';

  @override
  String get customCommand => 'カスタムコマンド';

  @override
  String get sendCustomCmd => 'カスタムコマンドを送信する';

  @override
  String get receivedData => '受信データ';

  @override
  String get inputData => '入力されたデータ';
}
