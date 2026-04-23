//
//  DeviceManager.m
//  JL_OTA
//
//  Created by EzioChan on 2022/11/24.
//  Copyright © 2022 Zhuhia Jieli Technology. All rights reserved.
//

#import "DeviceManager.h"

@interface DeviceManager()
@property (nonatomic, strong) dispatch_queue_t devicesAccessQueue;
@end

@implementation DeviceManager

+ (instancetype)share {
    static DeviceManager *mgr;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        mgr = [[DeviceManager alloc] init];
    });
    return mgr;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _devices = [NSMutableArray new];
        // Create a serial queue for thread-safe access to devices array
        _devicesAccessQueue = dispatch_queue_create("com.jieli.ota.deviceManager.queue", DISPATCH_QUEUE_SERIAL);
    }
    return self;
}

- (void)addDevicesWithSDKEntity:(JL_EntityM *)entity {
    if (!entity) {
        NSLog(@"Error: Cannot add nil entity to devices");
        return;
    }
    
    JLBleEntity *entityBasic = [[JLBleEntity alloc] init];
    entityBasic.mRSSI = entity.mRSSI;
    entityBasic.mPeripheral = entity.mPeripheral;
    entityBasic.bleMacAddress = entity.mBleAddr;
    entityBasic.mType = entity.mType;
    
    [self addDevicesEntity:entityBasic WithManager:entity.mCmdManager];
}

- (void)addDevicesEntity:(JLBleEntity *)entity WithManager:(JL_ManagerM *)manager {
    if (!entity || !manager) {
        NSLog(@"Error: Cannot add nil entity or manager to devices");
        return;
    }
    
    __weak typeof(self) weakSelf = self;
    dispatch_sync(self.devicesAccessQueue, ^{
        // Check if device already exists
        NSPredicate *predicate = [NSPredicate predicateWithFormat:@"entity.mPeripheral.identifier.UUIDString == %@", entity.mPeripheral.identifier.UUIDString];
        NSArray *existingDevices = [weakSelf.devices filteredArrayUsingPredicate:predicate];
        
        if (existingDevices.count == 0) {
            JLDeviceInfo *info = [[JLDeviceInfo alloc] init];
            info.entity = entity;
            info.manager = manager;
            [weakSelf.devices addObject:info];
            
            // Log the added device
            kJLLog(JLLOG_DEBUG, @"Added device: %@", info);
        } else {
            kJLLog(JLLOG_DEBUG, @"Device already exists: %@", entity.mPeripheral.identifier.UUIDString);
        }
        
        // Log all devices
        kJLLog(JLLOG_DEBUG, @"Current devices count: %lu", (unsigned long)weakSelf.devices.count);
        for (JLDeviceInfo *info in weakSelf.devices) {
            kJLLog(JLLOG_DEBUG, @"JLDeviceInfo: %@", info);
        }
    });
}

- (void)removeDevicesBy:(CBPeripheral *)cbp {
    if (!cbp) {
        NSLog(@"Error: Cannot remove device with nil peripheral");
        return;
    }
    
    __weak typeof(self) weakSelf = self;
    dispatch_sync(self.devicesAccessQueue, ^{
        NSPredicate *predicate = [NSPredicate predicateWithFormat:@"entity.mPeripheral.identifier.UUIDString == %@", cbp.identifier.UUIDString];
        NSArray *devicesToRemove = [weakSelf.devices filteredArrayUsingPredicate:predicate];
        
        if (devicesToRemove.count > 0) {
            [weakSelf.devices removeObjectsInArray:devicesToRemove];
            kJLLog(JLLOG_DEBUG, @"Removed device: %@", cbp.identifier.UUIDString);
        } else {
            kJLLog(JLLOG_DEBUG, @"Device not found for removal: %@", cbp.identifier.UUIDString);
        }
    });
}

- (JLDeviceInfo *)checkoutWith:(CBPeripheral *)peripheral {
    if (!peripheral) {
        NSLog(@"Error: Cannot checkout with nil peripheral");
        return nil;
    }
    
    __block JLDeviceInfo *result = nil;
    __weak typeof(self) weakSelf = self;
    
    dispatch_sync(self.devicesAccessQueue, ^{
        NSPredicate *predicate = [NSPredicate predicateWithFormat:@"entity.mPeripheral.identifier.UUIDString == %@", peripheral.identifier.UUIDString];
        NSArray *matchingDevices = [weakSelf.devices filteredArrayUsingPredicate:predicate];
        
        if (matchingDevices.count > 0) {
            result = matchingDevices.firstObject;
        }
    });
    
    return result;
}

- (NSArray<JLDeviceInfo *> *)allDevices {
    __block NSArray *devicesCopy = nil;
    
    dispatch_sync(self.devicesAccessQueue, ^{
        devicesCopy = [self.devices copy];
    });
    
    return devicesCopy;
}

- (NSUInteger)devicesCount {
    __block NSUInteger count = 0;
    
    dispatch_sync(self.devicesAccessQueue, ^{
        count = self.devices.count;
    });
    
    return count;
}

- (void)removeAllDevices {
    __weak typeof(self) weakSelf = self;
    dispatch_sync(self.devicesAccessQueue, ^{
        [weakSelf.devices removeAllObjects];
        kJLLog(JLLOG_DEBUG, @"Removed all devices");
    });
}

@end

@implementation JLDeviceInfo

- (void)test {
    if (!self.manager) {
        NSLog(@"Error: Manager is nil");
        return;
    }
    
    [self.manager cmdGetSystemInfo:JL_FunctionCodeCOMMON
                     SelectionBit:0x4000
                           Result:^(JL_CMDStatus status, uint8_t sn, NSData * _Nullable data) {
        // Handle result
        kJLLog(JLLOG_DEBUG, @"Test command completed with status: %ld", (long)status);
    }];
}

- (NSString *)description {
    return [NSString stringWithFormat:@"JLDeviceInfo: peripheral=%@, manager=%p",
            self.entity.mPeripheral.identifier.UUIDString, self.manager];
}

@end
