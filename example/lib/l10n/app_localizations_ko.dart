// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Korean (`ko`).
class AppLocalizationsKo extends AppLocalizations {
  AppLocalizationsKo([String locale = 'ko']) : super(locale);

  @override
  String get appName => 'JieLi OTA';

  @override
  String get devices => '장치';

  @override
  String get update => '업데이트';

  @override
  String get settings => '설정';

  @override
  String currentLanguage(String language) {
    return '현재 언어는 $language입니다';
  }

  @override
  String get connect => '연결';

  @override
  String get disconnect => '연결 끊기';

  @override
  String get filter => '필터';

  @override
  String get deviceList => '장치 목록';

  @override
  String get cancel => '취소';

  @override
  String get confirm => '확인';

  @override
  String get pleaseSetFilter => '필터를 설정해 주세요';

  @override
  String get copyRight => '©2021–2025 Zhuhai Jieli Technology co., LTD 모든 권리 보유';

  @override
  String get companyName => '주해 제리 기술 유한회사';

  @override
  String get privacyPolicyDialogTitle => '이용약관 및 개인정보 처리방침';

  @override
  String get welcomeMessage => '　Jieli OTA 업데이트에 오신 것을 환영합니다!\n　저희는 귀하의 개인정보 보호를 매우 중요하게 생각합니다. \"Jieli OTA 업데이트\" 서비스를 사용하기 전에 반드시';

  @override
  String get userAgreement => '《이용 약관》';

  @override
  String get and => '및';

  @override
  String get privacyPolicy => '《개인정보 처리방침》';

  @override
  String get agreementText => '을(를) 주의 깊게 읽어보시기 바랍니다.\n　본 안내 및 관련 약관 내용에 동의하시면 \'동의\'를 클릭하여 서비스를 시작하세요.';

  @override
  String get agreeButton => '동의';

  @override
  String get disagreeButton => '동의하지 않고 종료';

  @override
  String get btConnecting => '연결 중...';

  @override
  String get save => '저장';

  @override
  String get logLocation => '로그 위치：';

  @override
  String get deviceAuthentication => '장치 인증';

  @override
  String get hidDevice => 'HID 장치';

  @override
  String get customReconnectMethod => '사용자 정의 재연결 방식';

  @override
  String get currentCommunicationMethod => '현재 통신 방식';

  @override
  String get communicationWayBle => 'BLE';

  @override
  String get communicationWaySpp => 'SPP';

  @override
  String get communicationWayGatt => 'GATT Over BR/EDR';

  @override
  String get adjustMtu => 'MTU 조정';

  @override
  String get logFile => '로그 파일';

  @override
  String get sdkVersion => 'SDK 버전';

  @override
  String get aboutApp => '앱 정보';

  @override
  String get saveAndRestartMessage => '설정이 저장되었습니다. 앱을 재시작하여 변경 사항을 적용하시겠습니까?';

  @override
  String get restart => '재시작';

  @override
  String get failedToSaveSettings => '설정 저장 실패';

  @override
  String get connectUsingSdkBluetooth => 'SDK 블루투스로 연결';

  @override
  String get currentAppVersion => '현재 버전';

  @override
  String get icpInfo => 'ICP 등록 정보';

  @override
  String get isDeleteAllLogFiles => '모든 로그 파일을 삭제하시겠습니까?';

  @override
  String get deviceStatus => '장치 상태';

  @override
  String get connected => '연결됨';

  @override
  String get disconnected => 'Disconnected';

  @override
  String get deviceType => 'Device Type';

  @override
  String get unknownType => '알 수 없는 유형';

  @override
  String get classicBluetooth => '클래식 블루투스';

  @override
  String get bleDevice => 'BLE 장치';

  @override
  String get dualModeBluetooth => '듀얼 모드 블루투스';

  @override
  String get fileSelection => '파일 선택';

  @override
  String get delete => '삭제';

  @override
  String get localAdd => '로컬 추가';

  @override
  String get computerTransfer => '컴퓨터 전송';

  @override
  String get scanDownload => 'QR 코드 다운로드';

  @override
  String get saveFile => '파일 저장';

  @override
  String get serviceStarted => '서비스가 시작되었습니다';

  @override
  String get ensureConnection => '연결 장치가 동일한 Wi-Fi에 연결되어 있거나 이 장치의 핫스팟에 연결되어 있는지 확인하세요';

  @override
  String get copySuccess => '복사 성공, 연결된 장치의 브라우저에서 열어주세요';

  @override
  String get collapse => '접기';

  @override
  String get copyAddress => '주소 복사';

  @override
  String get selectUpgradeFile => '업그레이드 파일을 선택해 주세요';

  @override
  String get upgradeProcessTip => '(업그레이드 과정 중에는 블루투스와 네트워크를 켜진 상태로 유지해 주세요)';

  @override
  String get fileVerificationComplete => '파일 검증 완료, 장치에 재연결 중…';

  @override
  String get reason => '원인: %s';

  @override
  String get otaComplete => '업그레이드 완료';

  @override
  String get otaFinish => '업그레이드 종료';

  @override
  String get otaUpgrading => '업그레이드 중';

  @override
  String get otaUpgradeCancel => '업그레이드 취소됨';

  @override
  String get otaUpgradeNotStarted => '업그레이드 시작되지 않음';

  @override
  String get otaCheckingUpgradeFile => '업그레이드 파일 확인 중';

  @override
  String get otaUpgradeFailed => '업그레이드 실패: %s';

  @override
  String get otaCheckFile => '파일 검증 중';

  @override
  String get updateFailed => '업데이트 실패';

  @override
  String get unknownError => '알 수 없는 오류';

  @override
  String get scanQrcode => 'QR 코드 스캔';

  @override
  String get photos => '앨범';

  @override
  String get qrcodeIntoBox => 'QR 코드/바코드를 프레임 안에 배치하세요';

  @override
  String get failPhotosSystemReason => '시스템 문제로 앨범에 접근할 수 없습니다';

  @override
  String get accessCameraReason => '리소스 다운로드를 위해 QR 코드를 스캔하려면 카메라 접근 권한이 필요합니다';

  @override
  String get accessPhotosReason => '리소스 다운로드를 위해 QR 코드를 스캔하려면 앨범 접근 권한이 필요합니다';

  @override
  String get systemSetCamera => '이 기능은 카메라 사용이 필요합니다. 시스템 설정에서 권한을 부여해 주세요';

  @override
  String get systemSetExternalStorage => '이 기능은 휴대폰 저장공간 사용이 필요합니다. 시스템 설정에서 권한을 부여해 주세요';

  @override
  String get downloadSavePending => '파일 저장 중. 잠시만 기다려 주세요…';

  @override
  String get downloadingFile => '파일 다운로드 중';

  @override
  String get downloadSuccessful => 'Download successful';

  @override
  String get downloadCompleted => '다운로드 완료';

  @override
  String get pleaseRefreshWeb => '업로드에 성공했습니다. 웹 페이지를 새로 고치십시오';

  @override
  String get pressAgainToExit => '한 번 더 누르면 종료됩니다';

  @override
  String get notFoundQRCode => 'QR 코드를 찾을 수 없습니다';

  @override
  String get fileShare => '파일 공유';

  @override
  String get shareUfwFile => 'ufw 파일 공유';

  @override
  String get shareUfwFileTips => '제3자 앱(WeChat/DingTalk)에서 \'다른 앱으로 열기\'를 통해 ufw 파일을 열고 현재 OTA 업그레이드로 공유합니다';

  @override
  String get deviceMustMandatoryUpgrade => '디바이스 강제 업그레이드 필요';

  @override
  String get bluetoothDisconnected => '블루투스 연결이 끊어졌습니다';

  @override
  String get gattUuidPlaceholder => '하나 이상의 UUID를 입력하세요. 쉼표나 줄바꿈으로 구분하세요';

  @override
  String get gattServiceUuid => 'GATT 서비스 UUID';

  @override
  String get gattUuidTips => '예시: 180A, 0000180D-0000-1000-8000-00805F9B34FB';

  @override
  String get gattUuidErrorEmpty => '하나 이상의 UUID를 입력하세요';

  @override
  String get gattUuidErrorInvalidFmt => '잘못된 UUID 형식:\n%s';

  @override
  String get customCommand => '사용자 지정 명령';

  @override
  String get sendCustomCmd => '사용자 지정 명령 보내기';

  @override
  String get receivedData => '수신된 데이터';

  @override
  String get inputData => '입력된 데이터';
}
