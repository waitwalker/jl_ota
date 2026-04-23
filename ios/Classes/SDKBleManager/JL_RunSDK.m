//
//  JL_RunSDK.m
//  JL_OTA_InnerBle
//
//  Created by 凌煊峰 on 2021/10/9.
//

#import "JL_RunSDK.h"

@interface JL_RunSDK() <JL_ManagerMDelegate>

@property (strong, nonatomic) NSString *selectedOtaFilePath;
@property (strong, nonatomic) NSString *connectUUID;

@end

@implementation JL_RunSDK


+ (NSString *)textEntityStatus:(JL_EntityM_Status)status {
    if (status < 0) return kJL_TXT("unknown_error");
    NSArray *arr = @[kJL_TXT("bluetooth_off"), kJL_TXT("bt_connect_failed"), kJL_TXT("device_connecting"), kJL_TXT("repeated_connection"),
                     kJL_TXT("connect_timeout"), kJL_TXT("reject_by_device"), kJL_TXT("paire_failed"), kJL_TXT("paire_timeout"), kJL_TXT("paire_ok"),
                     kJL_TXT("master_slave_switch"), kJL_TXT("disconnect_success"), kJL_TXT("open_bluetooth")];
    if (status+1 <= arr.count) {
        return arr[status];
    } else {
        return kJL_TXT("unknown_error");
    }
}

+ (instancetype)sharedInstance {
    static JL_RunSDK *singleton = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        singleton = [[self alloc] init];
    });
    return singleton;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        /*--- 初始化JL_SDK ---*/
        self.mBleMultiple = [[JL_BLEMultiple alloc] init];
        self.mBleMultiple.BLE_FILTER_ENABLE = YES;
        self.mBleMultiple.BLE_PAIR_ENABLE = YES;
        self.mBleMultiple.BLE_TIMEOUT = 7;
        self.connectUUID = nil;
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(noteListen:) name:nil object:nil];
    }
    return self;
}


-(void)noteListen:(NSNotification *)note{
    NSString *name = note.name;
    if(!self.connectUUID) return;
    if([name isEqual:kJL_BLE_M_FOUND]){
        NSArray *itemsArray = [note object];
        __weak typeof(self) weakSelf = self;
        for (JL_EntityM *entity in itemsArray) {
            if([entity.mPeripheral.identifier.UUIDString isEqualToString:self.connectUUID]){
                [self.mBleMultiple scanStop];
                self.connectUUID = nil;
                [self.mBleMultiple connectEntity:entity Result:^(JL_EntityM_Status status) {
                    if(status == JL_EntityM_StatusPaired){
                        weakSelf.mBleEntityM = entity;
                    }
                }];
            }
        }
        
    }
}

-(void)startLoopConnect:(NSString *)uuid{
    self.connectUUID = uuid;
    [self.mBleMultiple scanStart];
}


- (JL_EntityM *)getEntity:(NSString *)uuid {
    NSMutableArray *mConnectArr = self.mBleMultiple.bleConnectedArr;
    for (JL_EntityM *entity in mConnectArr) {
        NSString *inUnid = entity.mPeripheral.identifier.UUIDString;
        if ([uuid isEqual:inUnid]) {
            return entity;
        }
    }
    return nil;
}


-(void)handelDeviceInfo{
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self getDeviceInfo:^(BOOL needForcedUpgrade) {
            
        }];
    });
}

#pragma mark - 杰理蓝牙库OTA流程相关业务

/**
 *  获取已连接的蓝牙设备信息，这里如果上次设备升级没有成功，会要求执行otaFuncWithFilePath:强制升级
 */
- (void)getDeviceInfo:(GET_DEVICE_CALLBACK _Nonnull)callback {
    __weak typeof(self) weakSelf = self;
    /*--- 获取设备信息 ---*/
    [self.mBleEntityM.mCmdManager cmdTargetFeatureResult:^(JL_CMDStatus status, uint8_t sn, NSData * _Nullable data) {
        if (status == JL_CMDStatusSuccess) {
            JLModel_Device *model = [weakSelf.mBleEntityM.mCmdManager outputDeviceModel];
            JL_OtaStatus upSt = model.otaStatus;
            if (upSt == JL_OtaStatusForce) {
                kJLLog(JLLOG_DEBUG, @"---> Enter force upgrade.");
                if (weakSelf.selectedOtaFilePath) {
                    [weakSelf otaFuncWithFilePath:weakSelf.selectedOtaFilePath];
                } else {
                    callback(true);
                }
                return;
            } else {
                if (model.otaHeadset == JL_OtaHeadsetYES) {
                    kJLLog(JLLOG_DEBUG, @"---> Enter force upgrade: OTA the other earbud.");
                    if (weakSelf.selectedOtaFilePath) {
                        [weakSelf otaFuncWithFilePath:weakSelf.selectedOtaFilePath];
                    } else {
                        callback(true);
                    }
                    return;
                }
            }
            kJLLog(JLLOG_DEBUG, @"---> The device works fine...");
            [JL_Tools mainTask:^{
                /*--- 获取公共信息 ---*/
                [weakSelf.mBleEntityM.mCmdManager cmdGetSystemInfo:JL_FunctionCodeCOMMON Result:nil];
                callback(false);
            }];
        } else {
            kJLLog(JLLOG_DEBUG, @"---> ERROR：There was an error retrieving the device information!");
        }
    }];
}

- (void)otaFuncWithFilePath:(NSString *)otaFilePath {
    kJLLog(JLLOG_DEBUG, @"current otaFilePath ---> %@", otaFilePath);
    self.selectedOtaFilePath = otaFilePath;
    __weak typeof(self) weakSelf = self;
    [self.mBleMultiple otaFuncWithEntityM:self.mBleEntityM withFilePath:otaFilePath Result:^(JL_OTAResult result, float progress) {
        if ([weakSelf.otaDelegate respondsToSelector:@selector(otaProgressWithOtaResult:withProgress:)]) {
            [weakSelf.otaDelegate otaProgressWithOtaResult:result withProgress:progress];
        }
    }];
}

@end
