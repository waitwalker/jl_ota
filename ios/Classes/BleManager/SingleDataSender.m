//
//  SingleDataSender.m
//  JL_OTA
//
//  Created by EzioChan on 2023/3/8.
//  Copyright © 2023 Zhuhia Jieli Technology. All rights reserved.
//

#import "SingleDataSender.h"

// MARK: - Constants
static NSString * const kLogTagSingleWait = @"single wait:%d";
static NSString * const kLogTagSingleSend = @"single send";

@interface SingleDataSender()
{
    dispatch_semaphore_t semaphore;      ///< Semaphore for controlling send queue
    dispatch_queue_t sendQueue;          ///< Serial queue for sending data
    NSMutableArray *sendDataArray;       ///< Queue of data to send
    NSLock *lock;                        ///< Lock for thread-safe array access
}

@end

@implementation SingleDataSender

+ (instancetype)share {
    static SingleDataSender *sender;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sender = [[SingleDataSender alloc] init];
    });
    return sender;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        sendDataArray = [NSMutableArray new];
        semaphore = dispatch_semaphore_create(1);
        sendQueue = dispatch_queue_create("com.jieli.ota.send.queue", DISPATCH_QUEUE_SERIAL);
        lock = [NSLock new];
        dispatch_async(sendQueue, ^{
            [self sendQueueAction];
        });
    }
    return self;
}

- (void)appendSend:(NSData *)data {
    if (!data) return;
    
    NSData *dt = [data copy];
    [lock lock];
    [sendDataArray addObject:dt];
    NSUInteger count = sendDataArray.count;
    [lock unlock];
    
    if (count == 1) {
        [self sendSingle];
    }
}

- (void)sendQueueAction {
    while (1) {
        @autoreleasepool {
            if (sendDataArray.count >= 1) {
                [lock lock];
                NSData *data = sendDataArray.firstObject;
                if (data) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        for (id<SingleSendDelegate> objc in self.delegates) {
                            if ([objc respondsToSelector:@selector(singleDidSendData:)]) {
                                [objc singleDidSendData:data];
                            }
                        }
                    });
                }
                [sendDataArray removeObjectAtIndex:0];
                [lock unlock];
            } else {
                kJLLog(JLLOG_DEBUG, kLogTagSingleWait, (int)sendDataArray.count);
                dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
            }
        }
    }
}

- (void)sendSingle {
    dispatch_semaphore_signal(semaphore);
    kJLLog(JLLOG_DEBUG, kLogTagSingleSend);
}

@end
