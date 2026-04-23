//
//  SingleDataSender.h
//  JL_OTA
//
//  Created by EzioChan on 2023/3/8.
//  Copyright © 2023 Zhuhia Jieli Technology. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <JL_BLEKit/JL_BLEKit.h>

NS_ASSUME_NONNULL_BEGIN

/// 单数据发送的代理协议
@protocol SingleSendDelegate <NSObject>

/// 数据发送完成的回调
/// @param data 发送的数据
- (void)singleDidSendData:(NSData *)data;

@end

/// 单数据发送器
@interface SingleDataSender : ECOneToMorePtl

/// 获取单例对象
+ (instancetype)share;

/// 添加待发送的数据
/// @param data 待发送的数据
- (void)appendSend:(NSData *)data;

/// 触发单次发送
- (void)sendSingle;

@end

NS_ASSUME_NONNULL_END
