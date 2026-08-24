//
//  JLBleHandler.m
//  JL_OTA
//
//  Created by EzioChan on 2022/10/12.
//  Copyright © 2022 Zhuhia Jieli Technology. All rights reserved.
//

#import "JLBleHandler.h"
#import "ToolsHelper.h"

NSString *kFLT_BLE_OTA_CALLBACK = @"kFLT_BLE_OTA_CALLBACK";

static NSString * const kDeviceTypeSoundBox = @"sound box";
static NSString * const kDeviceTypeChargingBin = @"charging box";
static NSString * const kDeviceTypeTWS = @"TWS";
static NSString * const kDeviceTypeHeadset = @"headset";
static NSString * const kDeviceTypeSoundCard = @"sound card";
static NSString * const kDeviceTypeWatch = @"watch";
static NSString * const kDeviceTypeTradition = @"tradition";
static NSString * const kDeviceTypeUnknown = @"unKnow";

static NSString * const kLogTagReconnectByMac = @"---> OTA SDK attempt to reconnect to the device using its MAC address... %@";
static NSString * const kLogTagReconnectByMacCustom = @"---> OTA reconnecting via MAC... %@";
static NSString * const kLogTagReconnectByUUID = @"---> OTA SDK reconnecting device... %@";
static NSString * const kLogTagReconnectByUUIDCustom = @"---> OTA SDK reconnecting device by custom ... %@,%@";

@interface JLBleHandler() <JLBleManagerOtaDelegate, JL_RunSDKOtaDelegate> {
    JL_BLEMultiple  *sdkManager;
    JLBleManager    *userManager;
}
@end

@implementation JLBleHandler

+(instancetype)share {
    static JLBleHandler *handler;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        handler = [[JLBleHandler alloc] init];
    });
    return handler;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        [self setupManagers];
    }
    return self;
}

- (void)setupManagers {
    sdkManager = [JL_RunSDK sharedInstance].mBleMultiple;
    [JL_RunSDK sharedInstance].otaDelegate = self;
    sdkManager.BLE_FILTER_ENABLE = YES;
    
    userManager = [JLBleManager sharedInstance];
    [userManager addDelegate:self];
}

- (void)setDelegate:(id<JLBleHandlDelegate>)delegate {
    _delegate = delegate;
    [JL_RunSDK sharedInstance].otaDelegate = self;
}

- (BOOL)isConnected {
    if ([ToolsHelper isConnectBySDK]) {
        JL_EntityM *entity = [JL_RunSDK sharedInstance].mBleEntityM;
        return entity.mIsAuth;
    } else {
        return [[JLBleManager sharedInstance] isConnected];
    }
}

- (BOOL)handleWeatherNeedUpdate {
    JL_OtaStatus otaStatus = [self getCurrentOtaStatus];
    return (otaStatus == JL_OtaStatusForce);
}

- (JL_OtaStatus)getCurrentOtaStatus {
    if ([ToolsHelper isConnectBySDK]) {
        JLModel_Device *model = [[[JL_RunSDK sharedInstance] mBleEntityM].mCmdManager outputDeviceModel];
        return model.otaStatus;
    } else {
        return userManager.otaManager.otaStatus;
    }
}

- (NSString *)handleDeviceNowUUID {
    if ([ToolsHelper isConnectBySDK]) {
        return [JL_RunSDK sharedInstance].mBleEntityM.mPeripheral.identifier.UUIDString;
    } else {
        return [JLBleManager sharedInstance].mBlePeripheral.identifier.UUIDString;
    }
}

- (BOOL)handleGetBleStatus {
    BOOL isPoweredOn = NO;
    
    if ([ToolsHelper isConnectBySDK]) {
        isPoweredOn = (sdkManager.bleManagerState == CBManagerStatePoweredOn);
    } else {
        isPoweredOn = ([JLBleManager sharedInstance].mBleManagerState == CBManagerStatePoweredOn);
    }
    
    return isPoweredOn;
}

- (void)handleScanDevice {
    if ([ToolsHelper isConnectBySDK]) {
        [sdkManager scanStart];
    } else {
        [userManager startScanBLE];
    }
}

- (void)handleStopScanDevice {
    if ([ToolsHelper isConnectBySDK]) {
        [sdkManager scanStop];
    } else {
        [userManager stopScanBLE];
    }
}

- (void)handleDisconnect {
    JL_EntityM *entity = [[JL_RunSDK sharedInstance] mBleEntityM];
    [sdkManager disconnectEntity:entity Result:^(JL_EntityM_Status status) {
        // Disconnect result handled internally
    }];
    [userManager disconnectBLE];
}

- (void)handleReconnectByMac {
    if ([ToolsHelper isConnectBySDK]) {
        kJLLog(JLLOG_DEBUG, kLogTagReconnectByMac, [JL_RunSDK sharedInstance].mBleEntityM.mBleAddr);
        [sdkManager scanStart];
    } else {
        kJLLog(JLLOG_DEBUG, kLogTagReconnectByMacCustom, userManager.otaManager.bleAddr);
        [JLBleManager sharedInstance].lastBleMacAddress = userManager.otaManager.bleAddr;
        [[JLBleManager sharedInstance] startScanBLE];
    }
}

- (void)handleReconnectByUUID {
    if ([ToolsHelper isConnectBySDK]) {
        sdkManager.BLE_PAIR_ENABLE = [ToolsHelper isSupportPair];
        kJLLog(JLLOG_DEBUG, kLogTagReconnectByUUID, [JL_RunSDK sharedInstance].mBleEntityM.mItem);
        
        JL_EntityM *entity = [sdkManager makeEntityWithUUID:[JL_RunSDK sharedInstance].lastUUID];
        [sdkManager connectEntity:entity Result:^(JL_EntityM_Status status) {
            // Connection result handled internally
        }];
    } else {
        kJLLog(JLLOG_DEBUG, kLogTagReconnectByUUIDCustom,
               userManager.mBlePeripheral.name, userManager.lastUUID);
        [userManager connectPeripheralWithUUID:userManager.lastUUID];
    }
}

- (void)handleConnectWithUUID:(NSString *)uuid {
    if ([ToolsHelper isConnectBySDK]) {
        [[JL_RunSDK sharedInstance] startLoopConnect:uuid];
    } else {
        [userManager connectPeripheralWithUUID:uuid];
    }
}

- (void)handleOtaFuncWithFilePath:(NSString *)otaFilePath {
    if ([ToolsHelper isConnectBySDK]) {
        [[JL_RunSDK sharedInstance] otaFuncWithFilePath:otaFilePath];
    } else {
        [[JLBleManager sharedInstance] otaFuncWithFilePath:otaFilePath];
    }
}

- (void)handleOtaCancelUpdate:(void(^)(JL_CMDStatus status))block {
    if (!block) return;
    
    if ([ToolsHelper isConnectBySDK]) {
        [self cancelOtaUpdateWithSDK:block];
    } else {
        [self cancelOtaUpdateWithCustomManager:block];
    }
}

- (void)cancelOtaUpdateWithSDK:(void(^)(JL_CMDStatus status))block {
    JL_EntityM *entity = [[JL_RunSDK sharedInstance] mBleEntityM];
    
    if (entity) {
        [entity.mCmdManager.mOTAManager cmdOTACancelResult:^(JL_CMDStatus status, uint8_t sn, NSData * _Nullable data) {
            block(status);
        }];
    } else {
        block(JL_CMDStatusFail);
    }
}

- (void)cancelOtaUpdateWithCustomManager:(void(^)(JL_CMDStatus status))block {
    JLBleEntity *entity = [[JLBleManager sharedInstance] currentEntity];
    
    if (entity) {
        [[JLBleManager sharedInstance] otaFuncCancel:^(uint8_t status) {
            block(status);
        }];
    } else {
        block(JL_CMDStatusFail);
    }
}

+ (NSString *)deviceType {
    JL_DeviceType type = [self getCurrentDeviceType];
    return [self stringFromDeviceType:type];
}

+ (JL_DeviceType)getCurrentDeviceType {
    if ([ToolsHelper isConnectBySDK]) {
        return [[JL_RunSDK sharedInstance] mBleEntityM].mType;
    } else {
        return [[JLBleManager sharedInstance] currentEntity].mType;
    }
}

+ (NSString *)stringFromDeviceType:(JL_DeviceType)type {
    switch (type) {
        case JL_DeviceTypeSoundBox:
            return kDeviceTypeSoundBox;
        case JL_DeviceTypeChargingBin:
            return kDeviceTypeChargingBin;
        case JL_DeviceTypeTWS:
            return kDeviceTypeTWS;
        case JL_DeviceTypeHeadset:
            return kDeviceTypeHeadset;
        case JL_DeviceTypeSoundCard:
            return kDeviceTypeSoundCard;
        case JL_DeviceTypeWatch:
            return kDeviceTypeWatch;
        case JL_DeviceTypeTradition:
            return kDeviceTypeTradition;
        default:
            return kDeviceTypeUnknown;
    }
}

- (void)otaProgressWithOtaResult:(JL_OTAResult)result withProgress:(float)progress {
    if ([self.delegate respondsToSelector:@selector(otaProgressOtaResult:withProgress:)]) {
        [self.delegate otaProgressOtaResult:result withProgress:progress];
    }
}

@end
