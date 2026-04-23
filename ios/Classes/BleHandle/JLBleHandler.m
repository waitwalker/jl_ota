//
//  JLBleHandler.m
//  JL_OTA
//
//  Created by EzioChan on 2022/10/12.
//  Copyright © 2022 Zhuhia Jieli Technology. All rights reserved.
//

#import "JLBleHandler.h"
#import "ToolsHelper.h"
#import "DeviceTypeConstants.h"

NSString *const kFLT_BLE_OTA_CALLBACK = @"kFLT_BLE_OTA_CALLBACK";     // BLE断开连接

@interface JLBleHandler()<JLBleManagerOtaDelegate, JL_RunSDKOtaDelegate>

@property (nonatomic, strong) JL_BLEMultiple *sdkManager;
@property (nonatomic, strong) JLBleManager *userManager;

@end

@implementation JLBleHandler

#pragma mark - Singleton
+ (instancetype)share {
    static JLBleHandler *handler;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        handler = [[JLBleHandler alloc] init];
    });
    return handler;
}

#pragma mark - Initialization
- (instancetype)init {
    self = [super init];
    if (self) {
        _sdkManager = [JL_RunSDK sharedInstance].mBleMultiple;
        [JL_RunSDK sharedInstance].otaDelegate = self;
        _sdkManager.BLE_FILTER_ENABLE = NO;
        
        _userManager = [JLBleManager sharedInstance];
        [_userManager addDelegate:self];
    }
    return self;
}

#pragma mark - Properties
- (void)setDelegate:(id<JLBleHandlDelegate>)delegate {
    _delegate = delegate;
    [JL_RunSDK sharedInstance].otaDelegate = self;
}

#pragma mark - Connection Status
- (BOOL)isConnected {
    if ([ToolsHelper isConnectBySDK]) {
        return [JL_RunSDK sharedInstance].mBleEntityM.mBLE_IS_PAIRED;
    } else {
        return self.userManager.isConnected;
    }
}

- (BOOL)handleWeatherNeedUpdate {
    JL_OtaStatus upSt = JL_OtaStatusNormal;
    if ([ToolsHelper isConnectBySDK]) {
        JLModel_Device *model = [[JL_RunSDK sharedInstance].mBleEntityM.mCmdManager outputDeviceModel];
        upSt = model.otaStatus;
    } else {
        upSt = self.userManager.otaManager.otaStatus;
    }
    
    return (upSt == JL_OtaStatusForce);
}

- (NSString *)handleDeviceNowUUID {
    if ([ToolsHelper isConnectBySDK]) {
        return [JL_RunSDK sharedInstance].mBleEntityM.mPeripheral.identifier.UUIDString;
    } else {
        return self.userManager.mBlePeripheral.identifier.UUIDString;
    }
}

- (BOOL)handleGetBleStatus {
    if ([ToolsHelper isConnectBySDK]) {
        return (self.sdkManager.bleManagerState == CBManagerStatePoweredOn);
    } else {
        return (self.userManager.mBleManagerState == CBManagerStatePoweredOn);
    }
}

#pragma mark - Scan Control
- (void)handleScanDevice {
    if ([ToolsHelper isConnectBySDK]) {
        [self.sdkManager scanStart];
    } else {
        [self.userManager startScanBLE];
    }
}

- (void)handleStopScanDevice {
    if ([ToolsHelper isConnectBySDK]) {
        [self.sdkManager scanStop];
    } else {
        [self.userManager stopScanBLE];
    }
}

#pragma mark - Connection Control
- (void)handleDisconnect {
    JL_EntityM *entity = [JL_RunSDK sharedInstance].mBleEntityM;
    [self.sdkManager disconnectEntity:entity Result:^(JL_EntityM_Status status) {
        // 断开连接完成回调
    }];
    
    [self.userManager disconnectBLE];
}

- (void)handleReconnectByMac {
    if ([ToolsHelper isConnectBySDK]) {
        kJLLog(JLLOG_DEBUG, @"---> OTA SDK attempt to reconnect to the device using its MAC address... %@", [JL_RunSDK sharedInstance].mBleEntityM.mBleAddr);
        [self.sdkManager scanStart];
    } else {
        kJLLog(JLLOG_DEBUG, @"---> OTA reconnecting via MAC... %@", self.userManager.otaManager.bleAddr);
        self.userManager.lastBleMacAddress = self.userManager.otaManager.bleAddr;
        [self.userManager startScanBLE];
    }
}

- (void)handleReconnectByUUID {
    if ([ToolsHelper isConnectBySDK]) {
        self.sdkManager.BLE_PAIR_ENABLE = [ToolsHelper isSupportPair];
        kJLLog(JLLOG_DEBUG, @"---> OTA SDK reconnecting device... %@", [JL_RunSDK sharedInstance].mBleEntityM.mItem);
        [self.sdkManager connectEntityForMac:[JL_RunSDK sharedInstance].mBleEntityM.mEdr Result:^(JL_EntityM_Status status) {
            // 连接结果回调
        }];
    } else {
        kJLLog(JLLOG_DEBUG, @"---> OTA SDK reconnecting device by custom ... %@,%@", self.userManager.mBlePeripheral.name, self.userManager.lastUUID);
        [self.userManager connectPeripheralWithUUID:self.userManager.lastUUID];
    }
}

- (void)handleConnectWithUUID:(NSString *)uuid {
    if ([ToolsHelper isConnectBySDK]) {
        [[JL_RunSDK sharedInstance] startLoopConnect:uuid];
    } else {
        [self.userManager connectPeripheralWithUUID:uuid];
    }
}

#pragma mark - Device Type
+ (NSString *)deviceType {
    JL_DeviceType type = JL_DeviceTypeTradition;
    if ([ToolsHelper isConnectBySDK]) {
        type = [JL_RunSDK sharedInstance].mBleEntityM.mType;
    } else {
        type = [JLBleManager sharedInstance].currentEntity.mType;
    }
    
    switch (type) {
        case JL_DeviceTypeSoundBox:
            return DeviceTypeSoundBox;
        case JL_DeviceTypeChargingBin:
            return DeviceTypeChargingBin;
        case JL_DeviceTypeTWS:
            return DeviceTypeTWS;
        case JL_DeviceTypeHeadset:
            return DeviceTypeHeadset;
        case JL_DeviceTypeSoundCard:
            return DeviceTypeSoundCard;
        case JL_DeviceTypeWatch:
            return DeviceTypeWatch;
        case JL_DeviceTypeTradition:
            return DeviceTypeTradition;
        default:
            return kJL_TXT("unknown_type");
    }
}

#pragma mark - OTA Functions
- (void)handleOtaFuncWithFilePath:(NSString *)otaFilePath {
    if ([ToolsHelper isConnectBySDK]) {
        [[JL_RunSDK sharedInstance] otaFuncWithFilePath:otaFilePath];
    } else {
        [self.userManager otaFuncWithFilePath:otaFilePath];
    }
}

- (void)handleOtaCancelUpdate:(void(^)(JL_CMDStatus status))block {
    if ([ToolsHelper isConnectBySDK]) {
        JL_EntityM *entity = [JL_RunSDK sharedInstance].mBleEntityM;
        if (entity) {
            [entity.mCmdManager.mOTAManager cmdOTACancelResult:^(JL_CMDStatus status, uint8_t sn, NSData * _Nullable data) {
                if (block) block(status);
            }];
        } else {
            if (block) block(JL_CMDStatusFail);
        }
    } else {
        JLBleEntity *entity = self.userManager.currentEntity;
        if (entity) {
            [self.userManager otaFuncCancel:^(uint8_t status) {
                if (block) block(status);
            }];
        } else {
            if (block) block(JL_CMDStatusFail);
        }
    }
}

#pragma mark - JL_RunSDKOtaDelegate
- (void)otaProgressWithOtaResult:(JL_OTAResult)result withProgress:(float)progress {
    if ([self.delegate respondsToSelector:@selector(otaProgressOtaResult:withProgress:)]) {
        [self.delegate otaProgressOtaResult:result withProgress:progress];
    }
}

@end
