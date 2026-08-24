//
//  JLBleManager.m
//  JL_OTA
//
//  Created by 凌煊峰 on 2021/10/11.
//

#import "JLBleManager.h"
#import "SingleDataSender.h"
#import "ToolsHelper.h"

#define SENDBYSINGLE  0 //1: Send via signal detection 0: Send by directly writing data
#define GATT_OVER_EDR_DEVICE  @"GATT over EDR Device"

@interface JLBleManager() <CBCentralManagerDelegate, CBPeripheralDelegate,JL_OTAManagerDelegate,JLHashHandlerDelegate,SingleSendDelegate>

@property (strong, nonatomic) CBCentralManager *bleManager;
@property (strong, nonatomic) JLHashHandler *pairHash;
@property (assign, nonatomic) BOOL pairStatus;

@property (strong, nonatomic) NSMutableArray<JLBleEntity *> *blePeripheralArr;
@property (strong, nonatomic) CBPeripheral *bleCurrentPeripheral;
@property (strong, nonatomic) CBService * mService;
@property (strong, nonatomic) CBCharacteristic *mRcspWrite;
@property (strong, nonatomic) CBCharacteristic *mRcspRead;

@property (strong, nonatomic) NSString *selectedOtaFilePath;
@property (strong, nonatomic) NSString *connectByUUID;

@property (strong, nonatomic) GET_DEVICE_CALLBACK getCallback;

@property (strong, nonatomic) NSArray *cbuuidArray;


@end

@implementation JLBleManager

+ (instancetype)sharedInstance {
    static JLBleManager *singleton = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        singleton = [[self alloc] init];
    });
    return singleton;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _isPaired = YES;
        _pairStatus = NO;
        
        _bleManager = [[CBCentralManager alloc] initWithDelegate:self queue:nil];
        
        /*--- JLSDK ADD ---*/
        _otaManager = [JL_OTAManager getOTAManager];
        [JL_OTAManager logSDKVersion];
        [JLHashHandler sdkVersion];
        [_otaManager logSendData:false];
        
        _otaManager.delegate = self;
        
        self.pairHash = [[JLHashHandler alloc] init];
        self.pairHash.delegate = self;
        
        _connectByUUID = nil;
        
        _cbuuidArray = @[[CBUUID UUIDWithString:FLT_BLE_SERVICE]];
#if SENDBYSINGLE
        [[SingleDataSender share] addDelegate:self];
#endif
        
    }
    return self;
}

- (void)setIsPaired:(BOOL)isPaired {
    _isPaired = isPaired;
}


#pragma mark - Device Scanning

#pragma mark Start Scanning
- (void)startScanBLE {
    kJLLog(JLLOG_DEBUG, @"BLE ---> startScanBLE.");
    _blePeripheralArr = [NSMutableArray new];
    if (_bleManager) {
        if (_bleManager.state == CBManagerStatePoweredOn) {
            [self scanGattOverEdr];
            [_bleManager scanForPeripheralsWithServices:nil options:nil];
        } else {
            __weak typeof(self) weakSelf = self;
            dispatch_after(0.5, dispatch_get_main_queue(), ^{
                if (weakSelf.bleManager.state == CBManagerStatePoweredOn) {
                    [self scanGattOverEdr];
                    [weakSelf.bleManager scanForPeripheralsWithServices:nil options:nil];
                }
            });
        }
    }
}

- (void)scanGattOverEdr {
    if ([ToolsHelper isGattOverEdr]) {
        [self registerForGattOverEdr];
    } else {
        [self unregisterForGattOverEdr];
    }
}

- (void)registerForGattOverEdr {
    NSArray *uuidStrs = [ToolsHelper getGattServiceUUIDs];
    if (uuidStrs.count == 0) {
        return;
    }
    
    NSArray *cbuuidArray = [self convertToCBUUIDArray:uuidStrs];
    if (cbuuidArray.count == 0) {
        return;
    }
    
    [self registerConnectionEventsWithUUIDs:cbuuidArray];
}

- (void)unregisterForGattOverEdr {
    [self registerConnectionEventsWithUUIDs:nil];
}

- (NSArray *)convertToCBUUIDArray:(NSArray *)uuidStrs {
    NSMutableArray *cbuuidArray = [NSMutableArray array];
    for (NSString *uuidStr in uuidStrs) {
        [cbuuidArray addObject:[CBUUID UUIDWithString:uuidStr]];
    }
    return [cbuuidArray copy];
}

- (void)registerConnectionEventsWithUUIDs:(NSArray *)cbuuidArray {
    if (@available(iOS 13.0, *)) {
        NSDictionary *matchingOptions = nil;
        if (cbuuidArray.count > 0) {
            matchingOptions = @{CBConnectionEventMatchingOptionServiceUUIDs: cbuuidArray};
        }
        [_bleManager registerForConnectionEventsWithOptions:matchingOptions];
    } else {
        kJLLog(JLLOG_WARN, @"BLE ---> registerForConnectionEventsWithOptions is not available before iOS 13.");
    }
}



#pragma mark Stop Scanning
- (void)stopScanBLE {
    if (_bleManager) [_bleManager stopScan];
}



#pragma mark - BLE Device Connection

#pragma mark Disconnect Current BLE Device
- (void)disconnectBLE {
    if (_bleCurrentPeripheral) {
        kJLLog(JLLOG_DEBUG, @"BLE --->To disconnectBLE.");
        [_bleManager cancelPeripheralConnection:_bleCurrentPeripheral];
        self.isConnected = false;
        self.currentEntity = nil;
    }
}

#pragma mark Connect BLE Device

- (void)connectBLE:(CBPeripheral*)peripheral {
    if(_bleCurrentPeripheral){
        [_bleManager cancelPeripheralConnection:_bleCurrentPeripheral];
    }
    _bleCurrentPeripheral = peripheral;
    [_bleCurrentPeripheral setDelegate:self];
    [_bleManager connectPeripheral:_bleCurrentPeripheral options:@{CBConnectPeripheralOptionNotifyOnDisconnectionKey:@(YES)}];
    [_bleManager stopScan];

    kJLLog(JLLOG_DEBUG, @"BLE Connecting... Name ---> %@", peripheral.name);
}

- (void)connectPeripheralWithUUID:(NSString*)uuid {
    _connectByUUID = uuid;
    [self startScanBLE];
}

-(void)findHid:(NSString *)uuid{
    NSUUID *uuidNs = [[NSUUID alloc] initWithUUIDString:uuid];
    NSArray *array = [self.bleManager retrievePeripheralsWithIdentifiers:@[uuidNs]];
    
    for (CBPeripheral *cbp in array) {
        if([cbp.identifier.UUIDString isEqualToString:uuid]){
            kJLLog(JLLOG_DEBUG, @"reconnect:%@",cbp);
            [self connectBLE:cbp];
            break;
        }
    }
}

-(void)connectAction{
    
    if(self.connectByUUID == nil) return;
    
    NSArray *uuidArr = @[[[NSUUID alloc] initWithUUIDString:self.connectByUUID]];
    NSArray *phArr = [_bleManager retrievePeripheralsWithIdentifiers:uuidArr];//serviceUUID is the UUID used during initial pairing

    if (phArr.count == 0) {
        return;
    }
    
    CBPeripheral* peripheral = phArr[0];
    
    if (phArr.firstObject && [phArr.firstObject state] != CBPeripheralStateConnected && [phArr.firstObject state] != CBPeripheralStateConnecting) {
        
        NSString *ble_name = peripheral.name;
        NSString *ble_uuid = peripheral.identifier.UUIDString;
        kJLLog(JLLOG_DEBUG, @"FLT Connecting(Last)... Name ---> %@ UUID:%@",ble_name,ble_uuid);
        
        _bleCurrentPeripheral = peripheral;
        [_bleCurrentPeripheral setDelegate:self];
        
        [_bleManager connectPeripheral:_bleCurrentPeripheral options:@{CBConnectPeripheralOptionNotifyOnDisconnectionKey:@(YES)}];
        _connectByUUID = nil;
    }
}

#pragma mark - CBCentralManagerDelegate

#pragma mark BLE Initialization Callback
- (void)centralManagerDidUpdateState:(CBCentralManager *)central {
    
    _mBleManagerState = central.state;
    
    if (_mBleManagerState != CBManagerStatePoweredOn) {
        self.mBlePeripheral = nil;
        self.blePeripheralArr = [NSMutableArray array];
    }
}

#pragma mark Device Discovery
-(void)centralManager:(CBCentralManager *)central connectionEventDidOccur:(CBConnectionEvent)event forPeripheral:(CBPeripheral *)peripheral {
    if (event == CBConnectionEventPeerConnected) {
        kJLLog(JLLOG_DEBUG, @"BLE ---> connectionEventDidOccur.");
        if ([ToolsHelper isGattOverEdr]) {
            JLBleEntity *bleEntity = [JLBleEntity new];
            bleEntity.mName = peripheral.name?:@"Unknow";
            bleEntity.edrMacAddress = GATT_OVER_EDR_DEVICE;
            bleEntity.mPeripheral = peripheral;
            [_blePeripheralArr addObject:bleEntity];
            if ([peripheral.identifier.UUIDString isEqualToString:_connectByUUID]) {
                [self connectBLE:peripheral];
                _connectByUUID = nil;
            }
        }
    }else if (event == CBConnectionEventPeerDisconnected) {
        kJLLog(JLLOG_DEBUG, @"BLE ---> connectionEventDidOccur disconnect:%@", peripheral);
    }
}

- (void)centralManager:(CBCentralManager *)central didDiscoverPeripheral:(CBPeripheral *)peripheral
     advertisementData:(NSDictionary<NSString *,id> *)advertisementData RSSI:(NSNumber *)RSSI {
    
    NSString *ble_name = advertisementData[@"kCBAdvDataLocalName"];
    NSData *ble_AD   = advertisementData[@"kCBAdvDataManufacturerData"];
    NSDictionary *info = [JLAdvParse bluetoothAdvParse:self.pairKey AdvData:advertisementData];
    if (ble_name.length == 0) return;
    
    kJLLog(JLLOG_DEBUG, @"Found ----> NAME:%@ RSSI:%@ AD:%@", ble_name,RSSI,ble_AD);
    
    [self addPeripheral:peripheral RSSI:RSSI Name:ble_name Info:info];

    [[NSNotificationCenter defaultCenter] postNotificationName:kFLT_BLE_FOUND object:_blePeripheralArr userInfo:nil];
    
    // Reconnection during OTA upgrade process
    if ([JLAdvParse otaBleMacAddress:self.lastBleMacAddress isEqualToCBAdvDataManufacturerData:ble_AD]) {
        [self connectBLE:peripheral];
    }
}

- (void)addPeripheral:(CBPeripheral*)peripheral RSSI:(NSNumber *)rssi Name:(NSString*)name Info:(NSDictionary*)info{
    int flag = 0;
    for (JLBleEntity *bleEntity in _blePeripheralArr) {
        CBPeripheral *info_pl = bleEntity.mPeripheral;
        NSString *info_uuid = info_pl.identifier.UUIDString;
        NSString *ble_uuid  = peripheral.identifier.UUIDString;
        if ([info_uuid isEqualToString:ble_uuid]) {
            bleEntity.mRSSI = rssi;
            flag = 1;
            break;
        }
    }
    if (flag == 0 && name.length > 0) {
        JLBleEntity *bleEntity = [JLBleEntity new];
        bleEntity.mName = name?:@"Unknow";
        bleEntity.mRSSI = rssi;
        bleEntity.mType = [info[@"TYPE"] intValue];
        bleEntity.edrMacAddress = info[@"EDR"];
        kJLLog(JLLOG_DEBUG, @"type:%d,name:%@, uuid:%@",[info[@"TYPE"] intValue],name, peripheral.identifier.UUIDString);
        bleEntity.mPeripheral = peripheral;
        [_blePeripheralArr addObject:bleEntity];
    }
    if(_connectByUUID && [peripheral.identifier.UUIDString isEqualToString:_connectByUUID]){
        [self stopScanBLE];
        [self connectAction];
    }
}

#pragma mark Device Connection Callback
- (void)centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)peripheral {
    kJLLog(JLLOG_DEBUG, @"BLE Connected ---> Device %@", peripheral.name);
    for (JLBleEntity *entity in self.blePeripheralArr) {
        if([entity.mPeripheral.identifier.UUIDString isEqualToString:peripheral.identifier.UUIDString]){
            self.currentEntity = entity;
            break;
        }
    }
    self.isConnected = YES;
    
    _otaManager.mBLE_NAME = peripheral.name;
    _otaManager.mBLE_UUID = peripheral.identifier.UUIDString;
    
    [DFNotice post:kFLT_BLE_CONNECTED Object:peripheral];
    // Discover services after successful connection
    [peripheral discoverServices:nil];
}

- (void)centralManager:(CBCentralManager *)central didFailToConnectPeripheral:(CBPeripheral *)peripheral error:(nullable NSError *)error {
    kJLLog(JLLOG_DEBUG, @"Err:BLE Connect FAIL ---> Device:%@ Error:%@",peripheral.name,[error description]);
}

#pragma mark Device Disconnection
- (void)centralManager:(CBCentralManager *)central didDisconnectPeripheral:(CBPeripheral *)peripheral error:(nullable NSError *)error {
    kJLLog(JLLOG_DEBUG, @"BLE Disconnect ---> Device %@ error:%d", peripheral.name, (int)error.code);
    
    [_otaManager noteEntityDisconnected];
    self.isConnected = NO;
    self.pairStatus = NO;
    /*--- UI refresh, device disconnected ---*/
    [[NSNotificationCenter defaultCenter] postNotificationName:kFLT_BLE_DISCONNECTED object:peripheral];
}

#pragma mark - CBPeripheralDelegate

#pragma mark Device Services Callback
- (void)peripheral:(CBPeripheral *)peripheral didDiscoverServices:(nullable NSError *)error {
    if (error) { kJLLog(JLLOG_DEBUG, @"Err: Discovered services fail."); return; }
    _mBlePeripheral = peripheral;
    for (CBService *service in peripheral.services) {
        // If we know the CBUUID of the characteristic to query, we can pass it in the first parameter.
        //if ([service.UUID.UUIDString isEqual:FLT_BLE_SERVICE]) {
            kJLLog(JLLOG_DEBUG, @"BLE Service ---> %@", service.UUID.UUIDString);
            [peripheral discoverCharacteristics:nil forService:service];
            //break;
        //}
    }
}

#pragma mark Device Characteristics Callback
- (void)peripheral:(CBPeripheral *)peripheral didDiscoverCharacteristicsForService:(CBService *)service error:(nullable NSError *)error {
    if (error) { kJLLog(JLLOG_DEBUG, @"Err: Discovered Characteristics fail."); return; }
    
    if ([service.UUID.UUIDString isEqual:FLT_BLE_SERVICE]) {
        
        for (CBCharacteristic *character in service.characteristics) {
            /*--- RCSP ---*/
            if ([character.UUID.UUIDString isEqual:FLT_BLE_RCSP_W]) {
                kJLLog(JLLOG_DEBUG, @"BLE Get Rcsp(Write) Channel ---> %@",character.UUID.UUIDString);
                self.mRcspWrite = character;
            }
            
            if ([character.UUID.UUIDString isEqual:FLT_BLE_RCSP_R]) {
                kJLLog(JLLOG_DEBUG, @"BLE Get Rcsp(Read) Channel ---> %@",character.UUID.UUIDString);
                self.mRcspRead = character;
                [peripheral setNotifyValue:YES forCharacteristic:character];
                
                if(self.mRcspRead.properties == CBCharacteristicPropertyRead){
                    [peripheral readValueForCharacteristic:character];
                    kJLLog(JLLOG_DEBUG, @"BLE  Rcsp(Read) Read Value For Characteristic.");
                }
            }
        }
    }
}

#pragma mark Update Notification State for Characteristic
- (void)peripheral:(CBPeripheral *)peripheral didUpdateNotificationStateForCharacteristic:(nonnull CBCharacteristic *)characteristic error:(nullable NSError *)error {
    
    if (error) { kJLLog(JLLOG_DEBUG, @"Err: Update NotificationState For Characteristic fail."); return; }
    
    if ([characteristic.service.UUID.UUIDString isEqual:FLT_BLE_SERVICE] &&
        [characteristic.UUID.UUIDString isEqual:FLT_BLE_RCSP_R]          &&
        characteristic.isNotifying == YES)
    {
        
        __weak typeof(self) weakSelf = self;
        self.bleMtu = [peripheral maximumWriteValueLengthForType:CBCharacteristicWriteWithoutResponse];
        kJLLog(JLLOG_DEBUG, @"BLE ---> MTU:%lu",(unsigned long)self.bleMtu);
        if (self.isPaired == YES) {
            [_pairHash hashResetPair];
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                // Device authentication
                [self->_pairHash bluetoothPairingKey:self.pairKey Result:^(BOOL ret) {
                    if(ret){
                        if (weakSelf.lastBleMacAddress == nil) {
                            weakSelf.lastUUID = peripheral.identifier.UUIDString;
                        }
                        kJLLog(JLLOG_DEBUG, @"bluetooth pairing success. UUID:%@", weakSelf.lastUUID);
                        weakSelf.lastBleMacAddress = nil;
                        [[NSNotificationCenter defaultCenter] postNotificationName:kFLT_BLE_PAIRED object:peripheral];
                        [weakSelf.otaManager noteEntityConnected];
                        weakSelf.pairStatus = YES;
                    }else{
                        kJLLog(JLLOG_DEBUG, @"JL_Assist Err: bluetooth pairing fail.");
                        [weakSelf.bleManager cancelPeripheralConnection:peripheral];
                    }
                }];
            });
        }else{
            if (weakSelf.lastBleMacAddress == nil) {
                self.lastUUID = peripheral.identifier.UUIDString;
            }
            kJLLog(JLLOG_DEBUG, @"bluetooth pairing success. UUID:%@", weakSelf.lastUUID);
            self.lastBleMacAddress = nil;
            [[NSNotificationCenter defaultCenter] postNotificationName:kFLT_BLE_PAIRED object:peripheral];
            [self.otaManager noteEntityConnected];
        }
    }
    self.isConnected = YES;
}

#pragma mark Device Data Received (GET)
- (void)peripheral:(CBPeripheral *)peripheral didUpdateValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error {
    if (error) { kJLLog(JLLOG_DEBUG, @"Err: receive data fail."); return; }

    if(_isPaired == YES && _pairStatus == NO){
        // Receive authentication handshake data from device
        [_pairHash inputPairData:characteristic.value];
    }else{
        // Received device data for normal communication
        [_otaManager cmdOtaDataReceive:characteristic.value];
    }

}

- (void)peripheralIsReadyToSendWriteWithoutResponse:(CBPeripheral *)peripheral{
    
#if SENDBYSINGLE
    [[SingleDataSender share] sendSingle];
#endif
    
}


#pragma mark - Jieli Bluetooth Library OTA Process Related Business

/**
 *  Get connected BLE device information. If the last device upgrade was unsuccessful, it will trigger otaFuncWithFilePath: for forced upgrade.
 *  @param callback Callback block
 */
- (void)getDeviceInfo:(GET_DEVICE_CALLBACK _Nonnull)callback {
    /*--- Get device info ---*/
    _getCallback = callback;
    [_otaManager cmdTargetFeature];
}

/**
 *  Perform OTA upgrade
 *  @param otaFilePath Path to the OTA upgrade file
 */
- (void)otaFuncWithFilePath:(NSString *)otaFilePath {
    kJLLog(JLLOG_DEBUG, @"current otaFilePath ---> %@", otaFilePath);
    self.selectedOtaFilePath = otaFilePath;
    NSData *otaData = [[NSData alloc] initWithContentsOfFile:otaFilePath];
    
    [_otaManager cmdOTAData:otaData Result:^(JL_OTAResult result, float progress) {
        for (id<JLBleManagerOtaDelegate> objc in self.delegates) {
            if([objc respondsToSelector:@selector(otaProgressWithOtaResult:withProgress:)]){
                [objc otaProgressWithOtaResult:result withProgress:progress];
            }
        }
        
    }];
}

/**
 *  Perform OTA upgrade (with SDK built-in reconnection)
 *  @param otaFilePath Path to the OTA upgrade file
 */
- (void)otaFuncWithFilePathInner:(NSString *)otaFilePath {
    kJLLog(JLLOG_DEBUG, @"current otaFilePath Inner ---> %@", otaFilePath);
    self.selectedOtaFilePath = otaFilePath;
    NSData *otaData = [[NSData alloc] initWithContentsOfFile:otaFilePath];
    
    JLOtaReConnectOption *option = [JLOtaReConnectOption defaultOption];
    // If service UUID or other characteristics need adjustment, configure the option accordingly
    option.serviceUUID = @"AE00";
    [_otaManager cmdUpgrade:otaData Option:option Result:^(JL_OTAResult result, float progress) {
        for (id<JLBleManagerOtaDelegate> objc in self.delegates) {
            if([objc respondsToSelector:@selector(otaProgressWithOtaResult:withProgress:)]){
                [objc otaProgressWithOtaResult:result withProgress:progress];
            }
        }
    }];
}


- (void)otaFuncCancel:(CANCEL_CALLBACK _Nonnull)result{
    
    [_otaManager cmdOTACancelResult:^(uint8_t status, uint8_t sn, NSData * _Nullable data) {
        result(status);
    }];
}



//MARK: - OTA Manager Delegate Callback
-(void)otaCancel{
    //TODO: OTA upgrade cancellation callback
}
-(void)otaUpgradeResult:(JL_OTAResult)result Progress:(float)progress{
    //TODO: Device upgrade process callback, including progress status
}

-(void)otaDataSend:(NSData *)data{
    [self writeDataByCbp:data];
}

-(void)otaFeatureResult:(JL_OTAManager *)manager{
    
    kJLLog(JLLOG_DEBUG, @"getDeviceInfo:%d",__LINE__);
    if (manager.otaStatus == JL_OtaStatusForce) {
        if (manager.isSupportReuseSpaceOTA) {
            if (manager.otaSourceMode  == JLSourcesExtendModeNormal
                || manager.otaSourceMode == JLSourcesExtendModeDisable) {
                if (manager.bootloaderType == JL_BootLoaderYES) {
                    kJLLog(JLLOG_DEBUG, @"---> Entering Loader upgrade.");
                }else{
                    kJLLog(JLLOG_DEBUG, @"---> Entering resource upgrade.");
                }
            }
            kJLLog(JLLOG_DEBUG, @"---> Current mode is: otaSourceMode: %d, bootloaderType: %d", manager.otaSourceMode, manager.bootloaderType);
        }
        if (self.selectedOtaFilePath) {
            [self otaFuncWithFilePath:self.selectedOtaFilePath];
        } else {
            if (_getCallback) {
                _getCallback(true);
                _getCallback = nil;
            }
        }
        return;
    } else {
        if (manager.otaHeadset == JL_OtaHeadsetYES) {
            if (self.selectedOtaFilePath) {
                [self otaFuncWithFilePath:self.selectedOtaFilePath];
            } else {
                if (_getCallback) {
                    _getCallback(true);
                    _getCallback = nil;
                }
            }
            return;
        }
        if (manager.otaSourceMode == JLSourcesExtendModeFirmwareOnly) {
            if (self.selectedOtaFilePath) {
                [self otaFuncWithFilePath:self.selectedOtaFilePath];
            } else {
                if (_getCallback) {
                    _getCallback(true);
                    _getCallback = nil;
                }
            }
            return;
        }
    }
    dispatch_async(dispatch_get_main_queue(), ^{
        /*--- Get common information ---*/
        [self->_otaManager cmdSystemFunction];
        if (self->_getCallback) {
            self->_getCallback(false);
            self->_getCallback = nil;
        }
    });

}

//MARK: - Hash Pair Delegate Callback

-(void)hashOnPairOutputData:(NSData *)data{
    [self writeDataByCbp:data];
}


//MARK: - Data Send Manager

/// Send data with packetization
/// - Parameter data: Data to be sent
-(void)writeDataByCbp:(NSData *)data{
    //    kJLLog(JLLOG_DEBUG, @"%s:data:%@",__func__,data);
        if (_mBlePeripheral && self.mRcspWrite) {
            if (data.length > 0 ) {
                NSInteger len = data.length;
                while (len>0) {
                    if (len <= _bleMtu) {
                        NSData *mtuData = [data subdataWithRange:NSMakeRange(0, data.length)];
                        [self selectSendAction:mtuData];
                        len -= data.length;
                    }else{
                        NSData *mtuData = [data subdataWithRange:NSMakeRange(0, _bleMtu)];
                        [self selectSendAction:mtuData];
                        len -= _bleMtu;
                        data = [data subdataWithRange:NSMakeRange(_bleMtu, len)];
                    }
                }
            }
        }else{
            // Need to set the write characteristic first
            kJLLog(JLLOG_DEBUG, @"need to init");
        }
}

-(void)selectSendAction:(NSData *)data{
    
#if SENDBYSINGLE
    [[SingleDataSender share] appendSend:data];
#else
    [_mBlePeripheral writeValue:data
      forCharacteristic:self.mRcspWrite
                   type:CBCharacteristicWriteWithoutResponse];
#endif
    
}


//MARK: - Send via Signal Detection
- (void)singleDidSendData:(NSData *)data{
    [_mBlePeripheral writeValue:data
      forCharacteristic:self.mRcspWrite
                   type:CBCharacteristicWriteWithoutResponse];
}


@end
