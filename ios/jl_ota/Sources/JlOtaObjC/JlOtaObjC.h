#import <TargetConditionals.h>

// The vendor SDK is distributed for physical iOS devices only.
#if !TARGET_OS_SIMULATOR
#import "DeviceTypeConstants.h"
#import "HandleBroadcastPtl.h"
#import "JLBleAssistManager.h"
#import "JLBleEntity.h"
#import "JLBleHandler.h"
#import "JLBleManager.h"
#import "JL_RunSDK.h"
#import "SingleDataSender.h"
#import "ToolsHelper.h"
#endif
