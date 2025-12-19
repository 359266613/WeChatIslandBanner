#import <UIKit/UIKit.h>
#import "WXBannerManager.h"
#import "WXWeChatStubs.h"

// 入口：微信消息管理器新增消息时调用
%hook CMessageMgr

- (void)AsyncOnAddMsg:(id)a0 MsgWrap:(CMessageWrap *)msgWrap {
    %orig;

    // 提取展示信息
    NSString *from = msgWrap.m_nsFromUsr;
    NSString *realSender = msgWrap.m_nsRealChatUsr; // 群聊真实发送者
    NSString *content = msgWrap.m_nsContent;
    if (!content.length && msgWrap.m_nsPushContent.length) {
        content = msgWrap.m_nsPushContent;
    }

    // 群聊文本格式通常为 "sender:\ncontent"，这里做个简单剥离
    if ([content containsString:@":\n"]) {
        NSArray *parts = [content componentsSeparatedByString:@":\n"];
        if (parts.count >= 2) {
            NSString *first = parts.firstObject;
            NSString *rest = [[parts subarrayWithRange:NSMakeRange(1, parts.count - 1)] componentsJoinedByString:@":\n"];
            if (first.length) {
                from = first;
            }
            content = rest;
        }
    }

    // 尝试从联系人获取昵称、头像
    NSString *avatar = nil;
    NSString *lookup = realSender.length ? realSender : from;
    if (lookup.length) {
        Class centerCls = NSClassFromString(@"MMServiceCenter");
        Class mgrCls = NSClassFromString(@"CContactMgr");
        if (centerCls && mgrCls && [centerCls respondsToSelector:@selector(defaultCenter)]) {
            id center = ((id (*)(id, SEL))objc_msgSend)(centerCls, @selector(defaultCenter));
            if (center && [center respondsToSelector:@selector(getService:)]) {
                id mgr = ((id (*)(id, SEL, id))objc_msgSend)(center, @selector(getService:), mgrCls);
                if (mgr && [mgr respondsToSelector:@selector(getContactByName:)]) {
                    id contact = ((id (*)(id, SEL, id))objc_msgSend)(mgr, @selector(getContactByName:), lookup);
                    if (contact) {
                        NSString *display = nil;
                        if ([contact respondsToSelector:@selector(getContactDisplayName)]) {
                            display = [contact getContactDisplayName];
                        }
                        if (!display.length && [contact respondsToSelector:@selector(m_nsRemark)]) {
                            display = [contact valueForKey:@"m_nsRemark"];
                        }
                        if (!display.length && [contact respondsToSelector:@selector(m_nsNickName)]) {
                            display = [contact valueForKey:@"m_nsNickName"];
                        }
                        if (display.length) {
                            from = display;
                        }
                        NSString *hd = nil;
                        if ([contact respondsToSelector:@selector(m_nsHeadHDImgUrl)]) {
                            hd = [contact valueForKey:@"m_nsHeadHDImgUrl"];
                        }
                        NSString *normal = nil;
                        if ([contact respondsToSelector:@selector(m_nsHeadImgUrl)]) {
                            normal = [contact valueForKey:@"m_nsHeadImgUrl"];
                        }
                        avatar = hd.length ? hd : normal;
                    }
                }
            }
        }
    }

    NSString *userName = lookup.length ? lookup : from;
    [[WXBannerManager shared] showWithTitle:from message:content avatarURL:avatar userName:userName];
}

%end

// 备用入口：部分版本会走 onNewSyncAddMessage:（单参数），这里兜底
%hook CMessageMgr

- (void)onNewSyncAddMessage:(CMessageWrap *)msgWrap {
    %orig;
    NSString *from = msgWrap.m_nsFromUsr;
    NSString *realSender = msgWrap.m_nsRealChatUsr;
    NSString *content = msgWrap.m_nsContent;
    if (!content.length && msgWrap.m_nsPushContent.length) {
        content = msgWrap.m_nsPushContent;
    }
    NSString *avatar = nil;
    NSString *lookup = realSender.length ? realSender : from;
    if (lookup.length) {
        Class centerCls = NSClassFromString(@"MMServiceCenter");
        Class mgrCls = NSClassFromString(@"CContactMgr");
        if (centerCls && mgrCls && [centerCls respondsToSelector:@selector(defaultCenter)]) {
            id center = ((id (*)(id, SEL))objc_msgSend)(centerCls, @selector(defaultCenter));
            if (center && [center respondsToSelector:@selector(getService:)]) {
                id mgr = ((id (*)(id, SEL, id))objc_msgSend)(center, @selector(getService:), mgrCls);
                if (mgr && [mgr respondsToSelector:@selector(getContactByName:)]) {
                    id contact = ((id (*)(id, SEL, id))objc_msgSend)(mgr, @selector(getContactByName:), lookup);
                    if (contact) {
                        NSString *display = nil;
                        if ([contact respondsToSelector:@selector(getContactDisplayName)]) {
                            display = [contact getContactDisplayName];
                        }
                        if (!display.length && [contact respondsToSelector:@selector(m_nsRemark)]) {
                            display = [contact valueForKey:@"m_nsRemark"];
                        }
                        if (!display.length && [contact respondsToSelector:@selector(m_nsNickName)]) {
                            display = [contact valueForKey:@"m_nsNickName"];
                        }
                        if (display.length) {
                            from = display;
                        }
                        NSString *hd = nil;
                        if ([contact respondsToSelector:@selector(m_nsHeadHDImgUrl)]) {
                            hd = [contact valueForKey:@"m_nsHeadHDImgUrl"];
                        }
                        NSString *normal = nil;
                        if ([contact respondsToSelector:@selector(m_nsHeadImgUrl)]) {
                            normal = [contact valueForKey:@"m_nsHeadImgUrl"];
                        }
                        avatar = hd.length ? hd : normal;
                    }
                }
            }
        }
    }
    NSString *userName = lookup.length ? lookup : from;
    [[WXBannerManager shared] showWithTitle:from message:content avatarURL:avatar userName:userName];
}

%end

#import <objc/runtime.h>
#import <objc/message.h>

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
    if (!cell) return;

    SEL addCellSel = sel_registerName("addCell:");
    if ([section respondsToSelector:addCellSel]) {
        ((void (*)(id, SEL, id))objc_msgSend)(section, addCellSel, cell);
    }
    SEL reloadSel = sel_registerName("reloadTableView");
    if ([manager respondsToSelector:reloadSel]) {
        ((void (*)(id, SEL))objc_msgSend)(manager, reloadSel);
    }
    objc_setAssociatedObject(controller, kWIBSettingsEntryAssociatedKey, cell, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
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

