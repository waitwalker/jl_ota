//
//  GCDWebKit.m
//  GCDWebServerDemo
//
//  Created by 杰理科技 on 2021/11/8.
//  Copyright © 2021 shapp. All rights reserved.
//

#import "GCDWebKit.h"
#import "SJXCSMIPHelper.h"
#import "AFNetworking.h"
#import <DFUnits/DFUnits.h>

static inline NSString *JLExampleText(const char *key) {
    return [DFUITools languageText:[NSString stringWithUTF8String:key] Table:@"Localizable"];
}

@interface GCDWebKit()<GCDWebUploaderDelegate>{
    GCDWebUploader      *webServer;
    GCDWebKit_BK        webKit_bk;
    NSString            *upgradePath;
}
@end


@implementation GCDWebKit

static GCDWebKit *ME = nil;
+(id)sharedInstance{
    static dispatch_once_t predicate;
    dispatch_once(&predicate, ^{
        ME = [[self alloc] init];
    });
    return ME;
}

-(instancetype)init{
    self = [super init];
    if (self) {
        upgradePath = [self makeUpgradePath];
    }
    return self;
}

-(NSString *)makeUpgradePath{
    NSFileManager * fm = [NSFileManager defaultManager];
    NSString  * searchPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject];
    NSString *path = [searchPath stringByAppendingPathComponent:OTA_UPGRADE];
    
    if (![fm fileExistsAtPath:path]) {
        [fm createDirectoryAtPath:path withIntermediateDirectories:YES
                       attributes:nil error:nil];
    }
    return path;
}

-(void)checkNetwork{
    // 监听网络状况
    AFNetworkReachabilityManager *mgr = [AFNetworkReachabilityManager sharedManager];
    [mgr setReachabilityStatusChangeBlock:^(AFNetworkReachabilityStatus status) {
        switch (status) {
            case AFNetworkReachabilityStatusUnknown:
                [self distroyServer];
                if (self->webKit_bk) {self->webKit_bk(GCDWebKitStatusWifiDisable,nil,-1);}
                break;
            case AFNetworkReachabilityStatusNotReachable:
                [self distroyServer];
                if (self->webKit_bk) {self->webKit_bk(GCDWebKitStatusWifiDisable,nil,-1);}
                break;
            case AFNetworkReachabilityStatusReachableViaWiFi:
                [self createServer];
                break;
            case AFNetworkReachabilityStatusReachableViaWWAN:
                [self distroyServer];
                if (self->webKit_bk) {self->webKit_bk(GCDWebKitStatusWifiDisable,nil,-1);}
                break;
            default:
                break;
        }
    }];
    [mgr startMonitoring];
}

-(void)createServer{
    [self distroyServer];
    
    // 创建webServer，设置根目录
    webServer = [[GCDWebUploader alloc] initWithUploadDirectory:upgradePath];
    // 设置代理
    webServer.delegate = self;
    webServer.allowHiddenItems = YES;
    // 限制文件上传类型
    webServer.allowedFileExtensions = @[@"ufw", @"zip"];
    // 设置网页标题
    webServer.title = JLExampleText("ota_update");
    // 设置展示在网页上的文字(开场白)
    webServer.prologue = JLExampleText("wecome_to_use_ota");
    // 设置展示在网页上的文字(收场白)
    webServer.epilogue = JLExampleText("drag_the_update_file");
    // 设置页尾文字
    webServer.footer = @"lifang@zh-jieli.com";
    
    NSString* device = [[UIDevice currentDevice] name];
    webServer.variables = @{
        @"device" : device,
        @"title" : JLExampleText("ota_update"),
        @"header" : JLExampleText("ota_update"),
        @"prologue" : JLExampleText("wecome_to_use_ota"),
        @"epilogue" : JLExampleText("drag_the_update_file"),
        @"footer" : @"lifang@zh-jieli.com",
        @"Upload Files":JLExampleText("upload_Files"),
        @"Create Folder":JLExampleText("create_folder"),
        @"Refresh":JLExampleText("refresh"),
        @"File Uploads in Progress":JLExampleText("file_uploads_in_progress"),
        @"Please enter the name of the folder to be created:":JLExampleText("please_enter_the_name_of_the_folder_to_be_created:"),
        @"Cancel":JLExampleText("cancel"),
        @"Move Item":JLExampleText("move_item"),
        @"Please enter the new location for this item:":JLExampleText("please_enter_the_new_location_for_this_item:")
    };
    if ([webServer start]) {
        NSString *wifi_IP = [SJXCSMIPHelper deviceIPAdress];
        NSInteger wifi_Port = webServer.port;
        if (webKit_bk) webKit_bk(GCDWebKitStatusStart,wifi_IP,wifi_Port);
    }else{
        if (webKit_bk) webKit_bk(GCDWebKitStatusFail,nil,-1);
    }
}

-(void)distroyServer{
    [webServer stop];
    webServer = nil;
}

-(GCDWebKit_BK)getBlock{
    return self->webKit_bk;
}

-(void)setBlock:(GCDWebKit_BK __nullable)bk{
    webKit_bk = bk;
}

-(GCDWebUploader*)getServer{
    return webServer;
}

#pragma mark - <GCDWebUploaderDelegate>
- (void)webUploader:(GCDWebUploader*)uploader didUploadFileAtPath:(NSString*)path {
    if (webKit_bk) webKit_bk(GCDWebKitStatusUpload,nil,-1);
}

- (void)webUploader:(GCDWebUploader*)uploader didMoveItemFromPath:(NSString*)fromPath toPath:(NSString*)toPath {
    if (webKit_bk) webKit_bk(GCDWebKitStatusMove,nil,-1);
}

- (void)webUploader:(GCDWebUploader*)uploader didDeleteItemAtPath:(NSString*)path {
    if (webKit_bk) webKit_bk(GCDWebKitStatusDelete,nil,-1);
}

- (void)webUploader:(GCDWebUploader*)uploader didCreateDirectoryAtPath:(NSString*)path {
    if (webKit_bk) webKit_bk(GCDWebKitStatusCreate,nil,-1);
}

+(void)startWithResult:(GCDWebKit_BK __nullable)result{
    [GCDWebKit sharedInstance];
    [ME setBlock:result];
    [ME checkNetwork];
}

+(void)stop{
    [ME distroyServer];
    [ME setBlock:NULL];
}



@end
