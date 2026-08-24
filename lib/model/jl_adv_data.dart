/// 杰理设备广播数据模型类
///
/// 包含杰理 BLE 广播包中解析出的厂商自定义数据、设备状态、UID/PID 及校验信息。
/// 字段均设计为可空类型（Nullable），以精确区分「设备未上报/不支持该属性」与「具体属性值」。
class JlAdvData {
  /// 厂商自定义广播原始数据（Manufacturer Data 十六进制字符串）
  final String? manufacturerData;

  /// 适配 mix_device 协议的结构化厂商数据 (若不足10字节或校验失败则为 null)
  final JlMixManufacture? mixManufacture;

  /// 客户/厂商唯一标识 UID (例如 2512)
  final int? uid;

  /// 产品型号 PID (若未配置或未上报则为 null)
  final String? pid;

  /// 设备类型 (-1 传统/通用OTA, 0 AI音箱, 1 充电仓, 2 TWS耳机, 3 普通耳机, 4 声卡, 5 手表；未上报则为 null)
  final int? type;

  /// 广播数据是否完整且通过杰理协议校验 (未校验或未知则为 null)
  final bool? isOk;

  /// 设备是否已绑定/配对 (未上报则为 null)
  final bool? isBound;

  /// 设备是否处于充电状态 (未上报则为 null)
  final bool? isCharging;

  /// 经典蓝牙链路 (EDR/A2DP/HFP) 是否已连接 (未上报则为 null)
  final bool? isLinked;

  /// 设备电量百分比 (0 ~ 100，未上报则为 null)
  final int? power;

  /// 经典蓝牙 MAC 地址 (未携带则为 null)
  final String? edr;

  /// 广播设备名称 (未携带则为 null)
  final String? bleName;

  const JlAdvData({
    this.manufacturerData,
    this.mixManufacture,
    this.uid,
    this.pid,
    this.type,
    this.isOk,
    this.isBound,
    this.isCharging,
    this.isLinked,
    this.power,
    this.edr,
    this.bleName,
  });

  /// 从 Map 安全解析广播数据，若 map 无效或异常则返回 null
  static JlAdvData? fromMap(dynamic map) {
    if (map == null || map is! Map) {
      return null;
    }

    try {
      final manufacturerData = _parseNullableString(
        map['manufacturer_data'] ?? map['manufacturerData'] ?? map['ADVDATA'] ?? map['raw_data'] ?? map['rawData'],
      );

      final mixManufacture = _parseMixManufacture(manufacturerData);

      final uid = _parseNullableInt(map['uid'] ?? map['UID']);

      final pid = _parseNullableString(map['pid'] ?? map['PID']);

      final type = _parseNullableInt(map['type'] ?? map['TYPE']);

      final isOk = _parseNullableBool(map['is_ok'] ?? map['isOk'] ?? map['ISOK']);

      final isBound = _parseNullableBool(map['is_bound'] ?? map['isBound'] ?? map['ISBOUND']);

      final isCharging = _parseNullableBool(map['is_charging'] ?? map['isCharging'] ?? map['ISCHARGING']);

      final isLinked = _parseNullableBool(map['is_linked'] ?? map['isLinked'] ?? map['ISLINKED']);

      final power = _parseNullableInt(map['power'] ?? map['POWER']);

      final edr = _parseNullableString(map['edr'] ?? map['EDR']);

      final bleName = _parseNullableString(map['ble_name'] ?? map['bleName'] ?? map['BLE_NAME']);

      return JlAdvData(
        manufacturerData: manufacturerData,
        mixManufacture: mixManufacture,
        uid: uid,
        pid: pid,
        type: type,
        isOk: isOk,
        isBound: isBound,
        isCharging: isCharging,
        isLinked: isLinked,
        power: power,
        edr: edr,
        bleName: bleName,
      );
    } catch (_) {
      return null;
    }
  }

  /// 转换为 Map 便于序列化或调试打印
  Map<String, dynamic> toMap() => {
    if (manufacturerData != null) 'manufacturer_data': manufacturerData,
    if (mixManufacture != null) 'mix_manufacture': mixManufacture!.toMap(),
    if (uid != null) 'uid': uid,
    if (pid != null) 'pid': pid,
    if (type != null) 'type': type,
    if (isOk != null) 'is_ok': isOk,
    if (isBound != null) 'is_bound': isBound,
    if (isCharging != null) 'is_charging': isCharging,
    if (isLinked != null) 'is_linked': isLinked,
    if (power != null) 'power': power,
    if (edr != null) 'edr': edr,
    if (bleName != null) 'ble_name': bleName,
  };

  @override
  String toString() =>
      'JlAdvData(manufacturerData: $manufacturerData, mixManufacture: $mixManufacture, uid: $uid, pid: $pid, type: $type, isOk: $isOk, isBound: $isBound, isCharging: $isCharging, isLinked: $isLinked, power: $power, edr: $edr, bleName: $bleName)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is JlAdvData &&
          runtimeType == other.runtimeType &&
          manufacturerData == other.manufacturerData &&
          mixManufacture == other.mixManufacture &&
          uid == other.uid &&
          pid == other.pid &&
          type == other.type &&
          isOk == other.isOk &&
          isBound == other.isBound &&
          isCharging == other.isCharging &&
          isLinked == other.isLinked &&
          power == other.power &&
          edr == other.edr &&
          bleName == other.bleName;

  @override
  int get hashCode => Object.hash(manufacturerData, mixManufacture, uid, pid, type, isOk, isBound, isCharging, isLinked, power, edr, bleName);

  // =================== mix_device 厂商数据解析与校验 ===================

  /// 解析 mix_device 格式的厂商数据
  ///
  /// 校验规则：
  /// 1. 长度 < 10 字节：打印日志记录原始数据，返回 null；
  /// 2. 长度 >= 10 字节：校验 version >= 1 且 connApp in (0, 1)；
  ///    - 校验失败：打印告警日志，返回 null；
  ///    - 校验通过：按小端序 (Little Endian) 提取 10 字节完整结构。
  static JlMixManufacture? _parseMixManufacture(String? rawHex) {
    if (rawHex == null || rawHex.isEmpty) return null;

    final bytes = _hexToBytes(rawHex);
    if (bytes == null || bytes.isEmpty) return null;

    // 确定 payload 起始偏移量 offset：
    // 情况 A：包含 2 字节 CompanyID/UID 头部（如 1225... 开头，bytes[2] 为 version，bytes[3] 为 connApp）
    // 情况 B：纯 payload（bytes[0] 为 version，bytes[1] 为 connApp）
    int offset = 0;
    if (bytes.length >= 12 && bytes[2] >= 1 && (bytes[3] == JlMixManufacture.connFemaleApp || bytes[3] == JlMixManufacture.connMaleApp)) {
      offset = 2; // 跳过前 2 字节 Company ID
    } else if (bytes.length >= 10 && bytes[0] >= 1 && (bytes[1] == JlMixManufacture.connFemaleApp || bytes[1] == JlMixManufacture.connMaleApp)) {
      offset = 0;
    } else {
      // 头部校验不符合 mix 协议规范
      return null;
    }

    if (bytes.length - offset < 10) return null;

    final int version = bytes[offset];
    final int connApp = bytes[offset + 1];
    final int productID = bytes[offset + 2] | (bytes[offset + 3] << 8);
    final int variantID = bytes[offset + 4] | (bytes[offset + 5] << 8);
    final int groupProductID = bytes[offset + 6] | (bytes[offset + 7] << 8);
    final int groupVariantID = bytes[offset + 8] | (bytes[offset + 9] << 8);

    return JlMixManufacture(
      protocolVersion: version,
      connApp: connApp,
      productID: productID,
      variantID: variantID,
      hardwareID: 0,
      groupProductID: groupProductID,
      groupVariantID: groupVariantID,
    );
  }

  static List<int>? _hexToBytes(String hex) {
    final cleaned = hex.replaceAll(' ', '').trim();
    if (cleaned.length.isOdd) return null;
    try {
      final list = <int>[];
      for (var i = 0; i < cleaned.length; i += 2) {
        list.add(int.parse(cleaned.substring(i, i + 2), radix: 16));
      }
      return list;
    } catch (_) {
      return null;
    }
  }

  // =================== 内部类型安全转换工具方法 ===================

  static String? _parseNullableString(dynamic value) {
    if (value == null) return null;
    final str = value.toString().trim();
    return str.isEmpty ? null : str;
  }

  static int? _parseNullableInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) {
      final trimmed = value.trim();
      if (trimmed.isEmpty) return null;
      return int.tryParse(trimmed);
    }
    return null;
  }

  static bool? _parseNullableBool(dynamic value) {
    if (value == null) return null;
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final lower = value.trim().toLowerCase();
      if (lower == '1' || lower == 'true') return true;
      if (lower == '0' || lower == 'false') return false;
    }
    return null;
  }
}

/// 适配 mix_device 厂商数据模型
class JlMixManufacture {
  final int protocolVersion;
  final int connApp;
  final int productID;
  final int variantID;
  final int hardwareID;
  final int groupProductID;
  final int groupVariantID;

  static const int connFemaleApp = 0;
  static const int connMaleApp = 1;
  static const int connUnknownApp = -1;

  const JlMixManufacture({
    required this.protocolVersion,
    required this.connApp,
    required this.productID,
    required this.variantID,
    this.hardwareID = 0,
    required this.groupProductID,
    required this.groupVariantID,
  });

  Map<String, dynamic> toMap() => {
    'protocolVersion': protocolVersion,
    'connApp': connApp,
    'productID': productID,
    'variantID': variantID,
    'hardwareID': hardwareID,
    'groupProductID': groupProductID,
    'groupVariantID': groupVariantID,
  };

  @override
  String toString() =>
      'JlMixManufacture(v: $protocolVersion, app: $connApp, pid: $productID, vid: $variantID, hid: $hardwareID, g_pid: $groupProductID, g_vid: $groupVariantID)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is JlMixManufacture &&
          runtimeType == other.runtimeType &&
          protocolVersion == other.protocolVersion &&
          connApp == other.connApp &&
          productID == other.productID &&
          variantID == other.variantID &&
          hardwareID == other.hardwareID &&
          groupProductID == other.groupProductID &&
          groupVariantID == other.groupVariantID;

  @override
  int get hashCode => Object.hash(protocolVersion, connApp, productID, variantID, hardwareID, groupProductID, groupVariantID);
}
