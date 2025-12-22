#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import "../Controllers/WMMConfig.h"

// 消息合并相关钩子
%hook MessageMergeManager

- (BOOL)isMessageMergeEnabled {
    return [WMMConfig shared].enableMerge;
}

- (CGFloat)getGroupChatLeftSpacing {
    return [WMMConfig shared].groupSpacing;
}

- (CGFloat)getPrivateChatLeftSpacing {
    return [WMMConfig shared].privateSpacing;
}

- (BOOL)hideLeftAvatarInGroupChat {
    return [WMMConfig shared].hideLeftAvatar;
}

- (BOOL)hideRightAvatarInGroupChat {
    return [WMMConfig shared].hideRightAvatar;
}

// 自定义消息合并逻辑
- (BOOL)canMergeMessage:(id)message1 with:(id)message2 {
    if (![WMMConfig shared].enableCustomMergeLogic) {
        return %orig;
    }
    
    // 获取消息时间
    NSTimeInterval time1 = 0;
    NSTimeInterval time2 = 0;
    
    if ([message1 respondsToSelector:@selector(msgTime)]) {
        time1 = [[message1 valueForKey:@"msgTime"] doubleValue];
    }
    
    if ([message2 respondsToSelector:@selector(msgTime)]) {
        time2 = [[message2 valueForKey:@"msgTime"] doubleValue];
    }
    
    // 如果时间差大于设定的窗口时间，则不合并
    if (fabs(time1 - time2) > [WMMConfig shared].mergeTimeWindow) {
        return NO;
    }
    
    return %orig;
}

// 自定义发送者逻辑
- (id)getRealSender:(id)message {
    if (![WMMConfig shared].enableCustomMergeLogic) {
        return %orig;
    }
    
    // 这里可以添加自定义的发送者判断逻辑
    // 例如，根据消息内容、时间戳等判断是否为同一发送者
    
    return %orig;
}

%end
