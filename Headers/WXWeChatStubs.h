#import <Foundation/Foundation.h>

// 仅保留本 tweak 用到的关键字段/方法，避免使用完整 dump 头导致编译错误。

@interface CMessageWrap : NSObject
@property (retain, nonatomic, nullable) NSString *m_nsFromUsr;
@property (retain, nonatomic, nullable) NSString *m_nsContent;
@property (retain, nonatomic, nullable) NSString *m_nsPushContent;
@property (retain, nonatomic, nullable) NSString *m_nsRealChatUsr; // 群聊时真实发送者
@end

@interface CBaseContact : NSObject
@property (retain, nonatomic, nullable) NSString *m_nsUsrName;
@property (retain, nonatomic, nullable) NSString *m_nsNickName;
@property (retain, nonatomic, nullable) NSString *m_nsRemark;
@property (retain, nonatomic, nullable) NSString *m_nsHeadImgUrl;
@property (retain, nonatomic, nullable) NSString *m_nsHeadHDImgUrl;
- (nullable id)getContactDisplayName;
@end

@interface CContact : CBaseContact
// 继续复用 CBaseContact 的属性/方法即可
@end

@interface CContactMgr : NSObject
- (nullable CContact *)getContactByName:(nullable NSString *)userName;
@end

@interface MMServiceCenter : NSObject
+ (nullable instancetype)defaultCenter;
- (nullable id)getService:(nullable Class)cls;
@end

@interface FlutterBizConversationPlugin : NSObject
- (void)enterChattingUIUsername:(nullable NSString *)userName error:(NSError * _Nullable * _Nullable)error;
@end

@interface CMessageMgr : NSObject
// 占位，无需方法声明；Logos hook 时按同名类生效
@end

