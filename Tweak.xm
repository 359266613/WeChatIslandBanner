#import <UIKit/UIKit.h>
#import "WXBannerManager.h"
#import "WXWeChatStubs.h"
#import <objc/message.h>

static id WIBValueForKey(id obj, NSString *key) {
    if (!obj || key.length == 0) return nil;
    @try {
        return [obj valueForKey:key];
    } @catch (__unused NSException *exception) {
        return nil;
    }
}

static NSString *WIBStringForKey(id obj, NSString *key) {
    id value = WIBValueForKey(obj, key);
    if ([value isKindOfClass:[NSString class]]) {
        return value;
    }
    if ([value respondsToSelector:@selector(stringValue)]) {
        return [value stringValue];
    }
    return nil;
}

static long long WIBLongLongForKey(id obj, NSString *key) {
    id value = WIBValueForKey(obj, key);
    if ([value respondsToSelector:@selector(longLongValue)]) {
        return [value longLongValue];
    }
    return 0;
}

static unsigned int WIBUIntForKey(id obj, NSString *key) {
    id value = WIBValueForKey(obj, key);
    if ([value respondsToSelector:@selector(unsignedIntValue)]) {
        return [value unsignedIntValue];
    }
    return 0;
}

static NSString *WIBTrimmed(NSString *text) {
    if (![text isKindOfClass:[NSString class]]) return @"";
    return [text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
}

static BOOL WIBBoolCallNoArg(id obj, NSString *selectorName, BOOL fallback) {
    if (!obj || selectorName.length == 0) return fallback;
    SEL sel = NSSelectorFromString(selectorName);
    if (![obj respondsToSelector:sel]) return fallback;
    return ((BOOL (*)(id, SEL))objc_msgSend)(obj, sel);
}

static BOOL WIBIsTextMessage(CMessageWrap *msgWrap) {
    if (!msgWrap) return NO;
    if (WIBBoolCallNoArg(msgWrap, @"IsTextMsg", NO)) {
        return YES;
    }
    unsigned int msgType = WIBUIntForKey(msgWrap, @"m_uiMessageType");
    if (msgType != 0) {
        return msgType == 1;
    }
    return WIBTrimmed(msgWrap.m_nsContent).length > 0 || WIBTrimmed(msgWrap.m_nsPushContent).length > 0;
}

static BOOL WIBIsSelfSent(CMessageWrap *msgWrap) {
    if (!msgWrap) return NO;
    if (WIBBoolCallNoArg(msgWrap, @"IsSendBySendMsg", NO)) {
        return YES;
    }
    Class wrapCls = NSClassFromString(@"CMessageWrap");
    SEL classSel = NSSelectorFromString(@"isSenderFromMsgWrap:");
    if (wrapCls && [wrapCls respondsToSelector:classSel]) {
        return ((BOOL (*)(id, SEL, id))objc_msgSend)(wrapCls, classSel, msgWrap);
    }
    return NO;
}

static BOOL WIBIsNoiseContent(NSString *content) {
    NSString *trimmed = WIBTrimmed(content);
    if (trimmed.length == 0) return YES;
    return [trimmed hasPrefix:@"<sysmsg"] || [trimmed hasPrefix:@"<?xml"];
}

static BOOL WIBIsDuplicateMessageKey(NSString *messageKey) {
    if (messageKey.length == 0) return NO;
    static NSMutableDictionary<NSString *, NSNumber *> *recent;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        recent = [NSMutableDictionary dictionary];
    });

    CFAbsoluteTime now = CFAbsoluteTimeGetCurrent();
    @synchronized (recent) {
        NSArray<NSString *> *allKeys = [recent allKeys];
        for (NSString *key in allKeys) {
            NSNumber *time = recent[key];
            if (time && now - time.doubleValue > 15.0) {
                [recent removeObjectForKey:key];
            }
        }

        NSNumber *existing = recent[messageKey];
        if (existing && now - existing.doubleValue < 8.0) {
            return YES;
        }
        recent[messageKey] = @(now);
        return NO;
    }
}

static UIViewController *WIBTopViewController(void) {
    UIApplication *app = UIApplication.sharedApplication;
    UIWindow *keyWindow = nil;

    if (@available(iOS 13.0, *)) {
        for (UIScene *scene in app.connectedScenes) {
            if (![scene isKindOfClass:[UIWindowScene class]]) continue;
            if (scene.activationState != UISceneActivationStateForegroundActive) continue;
            UIWindowScene *windowScene = (UIWindowScene *)scene;
            for (UIWindow *window in windowScene.windows) {
                if (window.isKeyWindow) {
                    keyWindow = window;
                    break;
                }
            }
            if (!keyWindow && windowScene.windows.count > 0) {
                keyWindow = windowScene.windows.firstObject;
            }
            if (keyWindow) break;
        }
    }

    if (!keyWindow) {
        for (UIScene *scene in app.connectedScenes) {
            if (![scene isKindOfClass:[UIWindowScene class]]) continue;
            UIWindowScene *windowScene = (UIWindowScene *)scene;
            if (windowScene.windows.count > 0) {
                keyWindow = windowScene.windows.firstObject;
                break;
            }
        }
    }

    if (!keyWindow) return nil;

    UIViewController *vc = keyWindow.rootViewController;
    while (vc.presentedViewController) {
        vc = vc.presentedViewController;
    }
    if ([vc isKindOfClass:[UINavigationController class]]) {
        vc = [(UINavigationController *)vc topViewController] ?: vc;
    }
    if ([vc isKindOfClass:[UITabBarController class]]) {
        vc = [(UITabBarController *)vc selectedViewController] ?: vc;
        if ([vc isKindOfClass:[UINavigationController class]]) {
            vc = [(UINavigationController *)vc topViewController] ?: vc;
        }
    }
    return vc;
}

static NSString *WIBExtractChatUserFromObject(id obj) {
    if (!obj) return nil;
    NSArray<NSString *> *keys = @[@"m_chatUsrName", @"m_nsUsrName", @"m_chatUserName", @"chatUsrName", @"chatUserName", @"m_userName"];
    for (NSString *key in keys) {
        NSString *value = WIBTrimmed(WIBStringForKey(obj, key));
        if (value.length > 0) return value;
    }

    id contact = WIBValueForKey(obj, @"m_contact");
    NSString *userName = WIBTrimmed(WIBStringForKey(contact, @"m_nsUsrName"));
    if (userName.length > 0) return userName;

    SEL getContactSel = NSSelectorFromString(@"GetContact");
    if ([obj respondsToSelector:getContactSel]) {
        id c = ((id (*)(id, SEL))objc_msgSend)(obj, getContactSel);
        userName = WIBTrimmed(WIBStringForKey(c, @"m_nsUsrName"));
        if (userName.length > 0) return userName;
    }
    return nil;
}

static NSString *WIBCurrentChatUserName(void) {
    UIViewController *top = WIBTopViewController();
    UIViewController *cursor = top;
    while (cursor) {
        NSString *chat = WIBExtractChatUserFromObject(cursor);
        if (chat.length > 0) {
            return chat;
        }
        cursor = cursor.parentViewController;
    }
    return nil;
}

static CContact *WIBLookupContact(NSString *userName) {
    if (userName.length == 0) return nil;
    Class centerCls = NSClassFromString(@"MMServiceCenter");
    Class mgrCls = NSClassFromString(@"CContactMgr");
    if (!centerCls || !mgrCls || ![centerCls respondsToSelector:@selector(defaultCenter)]) {
        return nil;
    }
    id center = ((id (*)(id, SEL))objc_msgSend)(centerCls, @selector(defaultCenter));
    if (!center || ![center respondsToSelector:@selector(getService:)]) {
        return nil;
    }
    id mgr = ((id (*)(id, SEL, id))objc_msgSend)(center, @selector(getService:), mgrCls);
    if (!mgr || ![mgr respondsToSelector:@selector(getContactByName:)]) {
        return nil;
    }
    return ((id (*)(id, SEL, id))objc_msgSend)(mgr, @selector(getContactByName:), userName);
}

static NSString *WIBDisplayNameForContact(CContact *contact) {
    if (!contact) return nil;
    NSString *display = nil;
    if ([contact respondsToSelector:@selector(getContactDisplayName)]) {
        display = [contact getContactDisplayName];
    }
    if (display.length == 0) {
        display = WIBStringForKey(contact, @"m_nsRemark");
    }
    if (display.length == 0) {
        display = WIBStringForKey(contact, @"m_nsNickName");
    }
    return WIBTrimmed(display);
}

static NSString *WIBAvatarForContact(CContact *contact) {
    if (!contact) return nil;
    NSString *hd = WIBTrimmed(WIBStringForKey(contact, @"m_nsHeadHDImgUrl"));
    NSString *normal = WIBTrimmed(WIBStringForKey(contact, @"m_nsHeadImgUrl"));
    return hd.length ? hd : normal;
}

static NSDictionary<NSString *, NSString *> *WIBBuildPayload(CMessageWrap *msgWrap) {
    if (!msgWrap) return nil;
    if (!WIBIsTextMessage(msgWrap)) return nil;

    NSString *conversationUser = WIBTrimmed(msgWrap.m_nsFromUsr);
    NSString *realSender = WIBTrimmed(msgWrap.m_nsRealChatUsr);

    NSString *content = WIBTrimmed(msgWrap.m_nsContent);
    if (content.length == 0) {
        content = WIBTrimmed(msgWrap.m_nsPushContent);
    }
    if (WIBIsNoiseContent(content)) {
        return nil;
    }

    NSString *title = conversationUser;

    if ([content containsString:@":\n"]) {
        NSArray<NSString *> *parts = [content componentsSeparatedByString:@":\n"];
        if (parts.count >= 2) {
            NSString *head = WIBTrimmed(parts.firstObject);
            NSString *body = WIBTrimmed([[parts subarrayWithRange:NSMakeRange(1, parts.count - 1)] componentsJoinedByString:@":\n"]);
            if (head.length > 0) {
                title = head;
            }
            if (body.length > 0) {
                content = body;
            }
        }
    }

    NSString *contactLookup = realSender.length > 0 ? realSender : conversationUser;
    CContact *contact = WIBLookupContact(contactLookup);
    NSString *displayName = WIBDisplayNameForContact(contact);
    NSString *avatarURL = WIBAvatarForContact(contact);
    if (displayName.length > 0) {
        title = displayName;
    }

    NSString *messageKey = nil;
    long long svrId = WIBLongLongForKey(msgWrap, @"m_n64MesSvrID");
    if (svrId > 0) {
        messageKey = [NSString stringWithFormat:@"svr:%lld", svrId];
    } else {
        unsigned int localId = WIBUIntForKey(msgWrap, @"m_uiMesLocalID");
        if (localId > 0) {
            messageKey = [NSString stringWithFormat:@"local:%u", localId];
        } else {
            unsigned int createTime = WIBUIntForKey(msgWrap, @"m_uiCreateTime");
            messageKey = [NSString stringWithFormat:@"fallback:%@:%u:%@", conversationUser ?: @"", createTime, content ?: @""];
        }
    }

    return @{
        @"title": title.length ? title : @"微信",
        @"message": content,
        @"avatarURL": avatarURL ?: @"",
        @"targetUser": conversationUser.length ? conversationUser : (contactLookup ?: @""),
        @"messageKey": messageKey ?: @""
    };
}

static BOOL WIBShouldPresent(CMessageWrap *msgWrap, NSDictionary<NSString *, NSString *> *payload) {
    if (!msgWrap || !payload) return NO;
    if (WIBIsSelfSent(msgWrap)) return NO;

    NSString *targetUser = payload[@"targetUser"];
    NSString *activeChat = WIBCurrentChatUserName();
    if (targetUser.length > 0 && activeChat.length > 0 && [activeChat isEqualToString:targetUser]) {
        return NO;
    }

    if (WIBIsDuplicateMessageKey(payload[@"messageKey"])) {
        return NO;
    }
    return YES;
}

static void WIBHandleIncomingMessage(CMessageWrap *msgWrap) {
    NSDictionary<NSString *, NSString *> *payload = WIBBuildPayload(msgWrap);
    if (!WIBShouldPresent(msgWrap, payload)) {
        return;
    }

    [[WXBannerManager shared] showWithTitle:payload[@"title"]
                                    message:payload[@"message"]
                                  avatarURL:payload[@"avatarURL"]
                                   userName:payload[@"targetUser"]];
}

// 入口：微信消息管理器新增消息时调用
%hook CMessageMgr

- (void)AsyncOnAddMsg:(id)a0 MsgWrap:(CMessageWrap *)msgWrap {
    %orig;
    WIBHandleIncomingMessage(msgWrap);
}

%end

// 备用入口：部分版本会走 onNewSyncAddMessage:（单参数），这里兜底
%hook CMessageMgr

- (void)onNewSyncAddMessage:(CMessageWrap *)msgWrap {
    %orig;
    WIBHandleIncomingMessage(msgWrap);
}

%end

#import <objc/runtime.h>

// 仅追加设置入口与插件注册，不改动原消息处理逻辑
static NSString *const kWIBPluginDisplayName = @"灵动消息";
static NSString *const kWIBPluginVersion     = @"5.2.0";

static BOOL WIBPluginManagerAvailable(void) {
    Class mgr = objc_getClass("WCPluginsMgr");
    if (!mgr) return NO;
    SEL sharedSel = sel_registerName("sharedInstance");
    if (![mgr respondsToSelector:sharedSel]) return NO;
    id instance = ((id (*)(id, SEL))objc_msgSend)(mgr, sharedSel);
    if (!instance) return NO;
    SEL regSel = sel_registerName("registerControllerWithTitle:version:controller:");
    return [instance respondsToSelector:regSel];
}

static void WIBRegisterSettingsIfPossible(void) {
    static BOOL registered = NO;
    if (registered || !WIBPluginManagerAvailable()) return;
    @try {
        Class mgr = objc_getClass("WCPluginsMgr");
        SEL sharedSel = sel_registerName("sharedInstance");
        id instance = ((id (*)(id, SEL))objc_msgSend)(mgr, sharedSel);
        SEL regSel = sel_registerName("registerControllerWithTitle:version:controller:");
        if (instance && [instance respondsToSelector:regSel]) {
            // 注册灵动消息
            ((void (*)(id, SEL, NSString *, NSString *, NSString *))objc_msgSend)(instance,
                                                                                  regSel,
                                                                                  kWIBPluginDisplayName,
                                                                                  kWIBPluginVersion,
                                                                                  @"WeChatIslandBannerSettingsController");
            registered = YES;
        }
    } @catch (__unused NSException *exception) {
    }
}

static void WIBPresentSettingsFromController(id hostController) {
    BOOL pluginManagerAvailable = WIBPluginManagerAvailable();
    BOOL canAccessPanel = pluginManagerAvailable ? YES : YES;
    if (!hostController || !canAccessPanel) {
        return;
    }
    id controller = [[NSClassFromString(@"WeChatIslandBannerSettingsController") alloc] init];
    if (!controller) return;

    SEL navSel = sel_registerName("navigationController");
    if ([hostController respondsToSelector:navSel]) {
        id nav = ((id (*)(id, SEL))objc_msgSend)(hostController, navSel);
        if (nav) {
            SEL pushSel = sel_registerName("pushViewController:animated:");
            if ([nav respondsToSelector:pushSel]) {
                ((void (*)(id, SEL, id, BOOL))objc_msgSend)(nav, pushSel, controller, YES);
                return;
            }
        }
    }

    Class navCls = objc_getClass("UINavigationController");
    if (navCls) {
        id nav = [[navCls alloc] initWithRootViewController:controller];
        SEL presentSel = sel_registerName("presentViewController:animated:completion:");
        if ([hostController respondsToSelector:presentSel]) {
            ((void (*)(id, SEL, id, BOOL, id))objc_msgSend)(hostController, presentSel, nav, YES, nil);
        }
    }
}

static id WIBSettingsTableManager(id controller) {
    if (!controller) return nil;
    const char *managerIvarNames[] = {"m_tableViewMgr", "_tableViewMgr", "m_tableMgr", "_tableMgr"};
    for (NSUInteger idx = 0; idx < sizeof(managerIvarNames) / sizeof(const char *); idx++) {
        Ivar ivar = class_getInstanceVariable([controller class], managerIvarNames[idx]);
        if (!ivar) continue;
        id value = object_getIvar(controller, ivar);
        if (value) return value;
    }
    return nil;
}

static void *kWIBSettingsEntryAssociatedKey = &kWIBSettingsEntryAssociatedKey;

static void WIBEnsureSettingsEntry(id controller) {
    if (!controller || WIBPluginManagerAvailable()) return;
    if (objc_getAssociatedObject(controller, kWIBSettingsEntryAssociatedKey)) return;
    id manager = WIBSettingsTableManager(controller);
    if (!manager) return;

    SEL getSectionSel = sel_registerName("getSectionAt:");
    id section = nil;
    if ([manager respondsToSelector:getSectionSel]) {
        section = ((id (*)(id, SEL, NSInteger))objc_msgSend)(manager, getSectionSel, 0);
    }
    if (!section) return;

    Class cellMgrCls = objc_getClass("WCTableViewNormalCellManager");
    if (!cellMgrCls) return;
    
    // 添加灵动消息入口
    SEL normalSel = sel_registerName("normalCellForSel:target:title:rightValue:accessoryType:");
    id cell = nil;
    if ([cellMgrCls respondsToSelector:normalSel]) {
        cell = ((id (*)(id, SEL, SEL, id, NSString *, NSString *, long))objc_msgSend)(cellMgrCls,
                                                                                       normalSel,
                                                                                       sel_registerName("wib_onSettingsEntryTapped"),
                                                                                       controller,
                                                                                       kWIBPluginDisplayName,
                                                                                       kWIBPluginVersion,
                                                                                       1);
    }
    if (cell) {
        SEL addCellSel = sel_registerName("addCell:");
        if ([section respondsToSelector:addCellSel]) {
            ((void (*)(id, SEL, id))objc_msgSend)(section, addCellSel, cell);
        }
        objc_setAssociatedObject(controller, kWIBSettingsEntryAssociatedKey, cell, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    
    SEL reloadSel = sel_registerName("reloadTableView");
    if ([manager respondsToSelector:reloadSel]) {
        ((void (*)(id, SEL))objc_msgSend)(manager, reloadSel);
    }
}

%hook MinimizeViewController

- (void)viewDidLoad {
    %orig;
    WIBRegisterSettingsIfPossible();
}

%end

%hook NewSettingViewController

- (void)viewDidLoad {
    %orig;
    WIBEnsureSettingsEntry(self);
}

- (void)viewWillAppear:(BOOL)animated {
    %orig;
    WIBEnsureSettingsEntry(self);
}

- (void)viewDidAppear:(BOOL)animated {
    %orig;
    WIBEnsureSettingsEntry(self);
}

%new
- (void)wib_onSettingsEntryTapped {
    WIBPresentSettingsFromController(self);
}

%end
