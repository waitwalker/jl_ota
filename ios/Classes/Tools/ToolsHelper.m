//
//  ToolsHelper.m
//  JL_OTA
//
//  Created by EzioChan on 2022/10/10.
//  Copyright © 2022 Zhuhia Jieli Technology. All rights reserved.
//

#import "ToolsHelper.h"

@interface ToolsHelper()

@property(nonatomic,strong)NSTimer *logTimer;
@property(nonatomic,strong)NSString *targetPath;
@property(nonatomic,assign)NSInteger maxSize;

@end

@implementation ToolsHelper

+(instancetype)share{
    static ToolsHelper *helper;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        helper = [[ToolsHelper alloc] init];
    });
    return helper;
}


-(void)countLogSize{
    NSData *data = [NSData dataWithContentsOfFile:_targetPath];
    if(data.length > _maxSize){
        [[NSData new] writeToFile:_targetPath atomically:true];
    }
}






+(BOOL)isSupportSelectMore{
    if([DFTools getUserByKey:@"SupportSelectMore"]){
        return [[DFTools getUserByKey:@"SupportSelectMore"] boolValue];
    }else{
        return NO;
    }
}

+(void)setSupportSelect:(BOOL)status{
    [DFTools setUser:[NSNumber numberWithBool:status] forKey:@"SupportSelectMore"];
}


+(BOOL)isSupportPair{
    if([DFTools getUserByKey:@"SupportPair"]){
        return [[DFTools getUserByKey:@"SupportPair"] boolValue];
    }else{
        [self setSupportPair:YES];
        return YES;
    }
}



+(void)setSupportPair:(BOOL)status{
    [DFTools setUser:[NSNumber numberWithBool:status] forKey:@"SupportPair"];
}

/// 设置是否HID
/// - Parameter status: 是否HID
+(void)setSupportHID:(BOOL)status{
    [DFTools setUser:[NSNumber numberWithBool:status] forKey:@"SupportHID"];
}

/// 获取是否HID
+(BOOL)isSupportHID{
    
    if([DFTools getUserByKey:@"SupportHID"]){
        return [[DFTools getUserByKey:@"SupportHID"] boolValue];
    }else{
        [self setSupportHID:NO];
        return NO;
    }
}

/// 设置是否需要广播音箱过滤
/// - Parameter status: 是否广播音箱过滤
+(void)setBroadcastFitter:(BOOL)status{
    [DFTools setUser:[NSNumber numberWithBool:status] forKey:@"BroadcastFitter"];
}

/// 获取是否需要广播音箱过滤
+(BOOL)isBroadcastFitter{
    if([DFTools getUserByKey:@"BroadcastFitter"]){
        return [[DFTools getUserByKey:@"BroadcastFitter"] boolValue];
    }else{
        [self setBroadcastFitter:YES];
        return YES;
    }
}

/// 设置是否开启广播音箱
/// - Parameter status: 是否广播音箱
+(void)setBroadcast:(BOOL)status{
    [DFTools setUser:[NSNumber numberWithBool:status] forKey:@"Broadcast_tag"];
}

/// 获取是否开启广播音箱
+(BOOL)isBroadcast{
    if([DFTools getUserByKey:@"Broadcast_tag"]){
        return [[DFTools getUserByKey:@"Broadcast_tag"] boolValue];
    }else{
        [self setBroadcastFitter:NO];
        return NO;
    }
}



+(BOOL)isConnectBySDK{
    if([DFTools getUserByKey:@"ConnectBySDK"]){
        return [[DFTools getUserByKey:@"ConnectBySDK"] boolValue];
    }else{
        [self setConnectBySDK:NO];
        return NO;
    }
}

+(void)setConnectBySDK:(BOOL)status{
    [DFTools setUser:[NSNumber numberWithBool:status] forKey:@"ConnectBySDK"];
}


+(BOOL)isAutoTestOta{
    if([DFTools getUserByKey:@"AutoTestOta"]){
        return [[DFTools getUserByKey:@"AutoTestOta"] boolValue];
    }else{
        return NO;
    }
}

+(void)setAutoTestOta:(BOOL)status{
    [DFTools setUser:[NSNumber numberWithBool:status] forKey:@"AutoTestOta"];
    [self setSupportSelect:status];
}


+(NSInteger)getAutoTestOtaNumber{
    if([DFTools getUserByKey:@"AutoTestOtaNumber"]){
        kJLLog(JLLOG_DEBUG,@"getAutoTestOtaNumber:%d",[[DFTools getUserByKey:@"AutoTestOtaNumber"] intValue]);
        return [[DFTools getUserByKey:@"AutoTestOtaNumber"] intValue];
    }else{
        kJLLog(JLLOG_DEBUG, @"getAutoTestOtaNumber:1");
        return 1;
    }
}

+(void)setAutoTestOtaNumber:(NSInteger)number{
    kJLLog(JLLOG_DEBUG, @"setAutoTestOtaNumber:%d",number);
    [DFTools setUser:[NSNumber numberWithInt:(int)number] forKey:@"AutoTestOtaNumber"];
}

+(void)setFaultTolerant:(BOOL)status{
    [DFTools setUser:[NSNumber numberWithBool:status] forKey:@"fault_tolerant"];
}

+(BOOL)getFaultTolerant{
    if([DFTools getUserByKey:@"fault_tolerant"]){
        return [[DFTools getUserByKey:@"fault_tolerant"] boolValue];
    }else{
        return NO;
    }
}


+(NSInteger)getFaultTolerantTimes{
    if([DFTools getUserByKey:@"fault_tolerant_times"]){
        return [[DFTools getUserByKey:@"fault_tolerant_times"] intValue];
    }else{
        return 5;
    }
}

+(void)setFaultTolerantTimes:(NSInteger)number{
    [DFTools setUser:[NSNumber numberWithInt:(int)number] forKey:@"fault_tolerant_times"];
}









+(NSString *)errorReason:(JL_OTAResult)result{
    switch (result) {
        case JL_OTAResultSuccess:
            return @"Upgrade successful";
            break;
        case JL_OTAResultFail:
            return @"Upgrade failed";
            break;
        case JL_OTAResultDataIsNull:
            return @"Upgrade data is null";
            break;
        case JL_OTAResultCommandFail:
            return @"Command failed";
            break;
        case JL_OTAResultSeekFail:
            return @"Failed to find the mark offset";
            break;
        case JL_OTAResultInfoFail:
            return @"Firmware information error";
            break;
        case JL_OTAResultLowPower:
            return @"Low power";
            break;
        case JL_OTAResultEnterFail:
            return @"Unable to enter OTA upgrade";
            break;
        case JL_OTAResultUpgrading:
            return @"Upgrading";
            break;
        case JL_OTAResultReconnect:
            return @"Reconnecting";
            break;
        case JL_OTAResultReboot:
            return @"Device restarting";
            break;
        case JL_OTAResultPreparing:
            return @"Preparing...";
            break;
        case JL_OTAResultPrepared:
            return @"Prepared...";
            break;
        case JL_OTAResultFailVerification:
            return @"Firmware verification failed";
            break;
        case JL_OTAResultFailCompletely:
            return @"Data verification failed";
            break;
        case JL_OTAResultFailKey:
            return @"Incorrect key for the upgrade file";
            break;
        case JL_OTAResultFailErrorFile:
            return @"Error in the upgrade file";
            break;
        case JL_OTAResultFailUboot:
            return @"Uboot content does not match";
            break;
        case JL_OTAResultFailLenght:
            return @"Error in the transmission length";
            break;
        case JL_OTAResultFailFlash:
            return @"Flash read and write failed during the upgrade";
            break;
        case JL_OTAResultFailCmdTimeout:
            return @"Command sent to device, reply timed out";
            break;
        case JL_OTAResultFailSameVersion:
            return @"Same firmware";
            break;
        case JL_OTAResultFailTWSDisconnect:
            return @"TWS headset is not connected";
            break;
        case JL_OTAResultFailNotInBin:
            return @"The headset is not in the charging case";
            break;
        case JL_OTAResultReconnectWithMacAddr:
            return @"Reconnect to the device through mac";
            break;
        case JL_OTAResultUnknown:
            return @"Unknown error";
            break;
        case JL_OTAResultDisconnect:
            return @"Device disconnected";
            break;
        case JL_OTAResultFailedConnectMore:
            return @"Firmware multiple connections, upgrade failed";
            break;
        case JL_OTAResultStatusIsUpdating:
            return @"Device is already being upgraded...";
            break;
        case JL_OTAResultFailSameSN:
            return @"Same SN";
            break;
        case JL_OTAResultCancel:
            return @"User canceled";
            break;
    }
    return @"";
}

+(void)setProductType:(ProductType)type{
    [DFTools setUser:[NSNumber numberWithInt:(int)type] forKey:@"ProductType"];
}

+(ProductType)getproductType{
    if([DFTools getUserByKey:@"ProductType"]){
        return [[DFTools getUserByKey:@"ProductType"] intValue];
    }else{
        return ProductTypeNormal;
    }
}



+(void)ufwDataSave:(NSData *)data path:(NSURL *)url{
    
    NSString *fname = url.path.lastPathComponent;
    NSString *basicPath = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, true).firstObject;
    basicPath = [basicPath stringByAppendingPathComponent:OTA_UPGRADE];
    NSFileManager *fm = [NSFileManager new];
    BOOL isDir = FALSE;
    BOOL isDirExist = [fm fileExistsAtPath:basicPath isDirectory:&isDir];
    
    if(!(isDirExist && isDir))
    {
        
        BOOL bCreateDir = [fm createDirectoryAtPath:basicPath
                                 withIntermediateDirectories:YES
                                                  attributes:nil
                                                       error:nil];
        if(!bCreateDir){
            kJLLog(JLLOG_DEBUG, @"Create upgrade Directory Failed.");
        }
    }
    NSString *docPath = [basicPath stringByAppendingPathComponent:fname];
    if ([fm fileExistsAtPath:docPath]) {
        NSArray *arr = [fname componentsSeparatedByString:@"."];
        NSDateFormatter *dfm = [NSDateFormatter new];
        dfm.dateFormat = @"yyyyMMddHHmmss";
        NSString *newDateStr = [dfm stringFromDate:[NSDate new]];
        fname = [NSString stringWithFormat:@"%@_%@.%@",arr[0],newDateStr,arr[1]];
    }
    docPath = [basicPath stringByAppendingPathComponent:fname];
    [fm createFileAtPath:docPath contents:data attributes:nil];
}

+(NSURL *)targetSavePath:(NSString *)fileName{
    
    NSString *basicPath = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, true).firstObject;
    basicPath = [basicPath stringByAppendingPathComponent:OTA_UPGRADE];
    NSFileManager *fm = [NSFileManager new];
    BOOL isDir = FALSE;
    BOOL isDirExist = [fm fileExistsAtPath:basicPath isDirectory:&isDir];
    
    if(!(isDirExist && isDir))
    {
        
        BOOL bCreateDir = [fm createDirectoryAtPath:basicPath
                                 withIntermediateDirectories:YES
                                                  attributes:nil
                                                       error:nil];
        if(!bCreateDir){
            kJLLog(JLLOG_DEBUG, @"Create upgrade Directory Failed.");
        }
    }
    NSString *docPath = [basicPath stringByAppendingPathComponent:fileName];
    if ([fm fileExistsAtPath:docPath]) {
        NSArray *arr = [fileName componentsSeparatedByString:@"."];
        NSDateFormatter *dfm = [NSDateFormatter new];
        dfm.dateFormat = @"yyyyMMddHHmmss";
        NSString *newDateStr = [dfm stringFromDate:[NSDate new]];
        fileName = [NSString stringWithFormat:@"%@_%@.%@",arr[0],newDateStr,arr[1]];
    }
    docPath = [basicPath stringByAppendingPathComponent:fileName];
    return [NSURL fileURLWithPath:docPath];
}



@end
