#import "WXBannerManager.h"
#import "WIBConfig.h"
#import <objc/message.h>

@interface WXBannerManager ()
@property (nonatomic, strong) UIWindow *window;
@property (nonatomic, strong) UIView *bannerView;
@property (nonatomic, strong) UIImageView *avatarView;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *messageLabel;
@property (nonatomic, strong) NSCache<NSString *, UIImage *> *imageCache;
@property (nonatomic, strong) NSMutableArray<NSDictionary<NSString *, NSString *> *> *pendingPayloads;
@property (nonatomic, assign) BOOL isShowing;
@property (nonatomic, copy) NSString *currentUserName;
@property (nonatomic, copy) NSString *currentAvatarToken;
@property (nonatomic, assign) CGFloat currentBannerHeight;
@end

@implementation WXBannerManager

+ (instancetype)shared {
    static WXBannerManager *mgr;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        mgr = [[self alloc] init];
    });
    return mgr;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _imageCache = [NSCache new];
        _pendingPayloads = [NSMutableArray array];
    }
    return self;
}

- (void)showWithTitle:(NSString *)title
              message:(NSString *)message
            avatarURL:(NSString *)avatarURL
             userName:(NSString *)userName {
    NSString *safeTitle = title.length ? title : @"微信";
    NSString *safeMessage = message.length ? message : @"新消息";

    dispatch_async(dispatch_get_main_queue(), ^{
        [[WIBConfig shared] reload];
        if (![WIBConfig shared].enableIsland) {
            return;
        }

        NSDictionary<NSString *, NSString *> *payload = @{
            @"title": safeTitle,
            @"message": safeMessage,
            @"avatarURL": avatarURL ?: @"",
            @"userName": userName ?: @""
        };

        if (self.pendingPayloads.count >= 40) {
            [self.pendingPayloads removeObjectAtIndex:0];
        }
        [self.pendingPayloads addObject:payload];
        [self processNextIfNeeded];
    });
}

- (void)processNextIfNeeded {
    if (self.isShowing || self.pendingPayloads.count == 0) {
        return;
    }

    NSDictionary<NSString *, NSString *> *payload = self.pendingPayloads.firstObject;
    [self.pendingPayloads removeObjectAtIndex:0];
    [self presentPayload:payload];
}

- (void)presentPayload:(NSDictionary<NSString *, NSString *> *)payload {
    [self ensureWindowAndLayout];
    [self applyStyle];

    self.titleLabel.text = payload[@"title"];
    self.messageLabel.text = payload[@"message"];
    self.currentUserName = payload[@"userName"];

    [self loadAvatarIfNeeded:payload[@"avatarURL"]];
    [self layoutLabels];

    self.isShowing = YES;
    self.window.hidden = NO;

    CGRect frame = self.bannerView.frame;
    frame.origin.y = -frame.size.height - 10.f;
    self.bannerView.frame = frame;

    [UIView animateWithDuration:0.35
                          delay:0
         usingSpringWithDamping:0.82
          initialSpringVelocity:0.85
                        options:UIViewAnimationOptionCurveEaseOut
                     animations:^{
        CGRect shown = self.bannerView.frame;
        shown.origin.y = [self visibleBannerY];
        self.bannerView.frame = shown;
    } completion:^(__unused BOOL finished) {
        [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(hide) object:nil];
        [self performSelector:@selector(hide) withObject:nil afterDelay:2.5];
    }];
}

- (void)ensureWindowAndLayout {
    CGRect screenBounds = [UIScreen mainScreen].bounds;
    UIWindowScene *scene = [self activeWindowScene];

    if (!self.window) {
        self.window = [[UIWindow alloc] initWithFrame:screenBounds];
        self.window.windowLevel = UIWindowLevelStatusBar + 10;
        self.window.backgroundColor = [UIColor clearColor];
        self.window.hidden = YES;
        self.window.userInteractionEnabled = YES;
        self.window.rootViewController = [UIViewController new];
    }

    if (@available(iOS 13.0, *)) {
        if (scene && self.window.windowScene != scene) {
            self.window.windowScene = scene;
        }
    }
    self.window.frame = screenBounds;

    if (!self.bannerView) {
        self.bannerView = [[UIView alloc] initWithFrame:CGRectZero];
        self.bannerView.layer.masksToBounds = YES;

        UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(onTap)];
        [self.bannerView addGestureRecognizer:tap];

        self.avatarView = [[UIImageView alloc] initWithFrame:CGRectZero];
        self.avatarView.contentMode = UIViewContentModeScaleAspectFill;
        self.avatarView.clipsToBounds = YES;

        self.titleLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        self.titleLabel.font = [UIFont boldSystemFontOfSize:14];

        self.messageLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        self.messageLabel.font = [UIFont systemFontOfSize:13];
        self.messageLabel.numberOfLines = 1;

        [self.window.rootViewController.view addSubview:self.bannerView];
        [self.bannerView addSubview:self.avatarView];
        [self.bannerView addSubview:self.titleLabel];
        [self.bannerView addSubview:self.messageLabel];
    }

    WIBConfig *cfg = [WIBConfig shared];
    CGFloat widthRatio = MIN(MAX(cfg.widthRatio, 0.5), 1.0);
    CGFloat width = floor(screenBounds.size.width * widthRatio);
    width = MIN(width, screenBounds.size.width - 16.0);
    width = MAX(width, 200.0);

    CGFloat height = MIN(MAX(cfg.height, 36.0), 88.0);
    self.currentBannerHeight = height;

    self.bannerView.frame = CGRectMake((screenBounds.size.width - width) / 2.0,
                                       -height - 10.0,
                                       width,
                                       height);
    self.bannerView.layer.cornerRadius = height / 2.0;
}

- (void)applyStyle {
    WIBConfig *cfg = [WIBConfig shared];

    UIColor *defaultBackground = [UIColor colorWithWhite:0 alpha:0.85];
    self.bannerView.backgroundColor = cfg.enableBackground ? (cfg.backgroundColor ?: defaultBackground) : defaultBackground;

    if (cfg.enableBorder) {
        self.bannerView.layer.borderWidth = 1.0;
        self.bannerView.layer.borderColor = (cfg.borderColor ?: [UIColor colorWithWhite:1 alpha:0.25]).CGColor;
    } else {
        self.bannerView.layer.borderWidth = 0;
        self.bannerView.layer.borderColor = nil;
    }

    UIColor *titleColor = cfg.enableTextColor ? (cfg.textColor ?: UIColor.whiteColor) : UIColor.whiteColor;
    self.titleLabel.textColor = titleColor;
    self.messageLabel.textColor = cfg.enableTextColor ? [titleColor colorWithAlphaComponent:0.92] : [UIColor colorWithWhite:1 alpha:0.9];
}

- (void)layoutLabels {
    CGFloat padding = 12.f;
    CGFloat avatar = MIN(34.f, MAX(28.f, self.currentBannerHeight - 18.f));
    CGFloat midY = self.bannerView.bounds.size.height / 2.f;

    self.avatarView.frame = CGRectMake(padding, midY - avatar / 2.f, avatar, avatar);
    self.avatarView.layer.cornerRadius = avatar / 2.f;

    CGFloat textX = padding + avatar + 10.f;
    CGFloat textWidth = self.bannerView.bounds.size.width - textX - padding;
    self.titleLabel.frame = CGRectMake(textX, midY - 16, textWidth, 15);
    self.messageLabel.frame = CGRectMake(textX, midY + 1, textWidth, 14);
}

- (CGFloat)visibleBannerY {
    UIWindowScene *scene = [self activeWindowScene];
    CGFloat topInset = 0;
    if (@available(iOS 13.0, *)) {
        if (scene.windows.count > 0) {
            topInset = scene.windows.firstObject.safeAreaInsets.top;
        }
    }
    if (topInset > 24.0) {
        return 8.0;
    }
    return 10.0;
}

- (void)hide {
    dispatch_async(dispatch_get_main_queue(), ^{
        [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(hide) object:nil];
        [UIView animateWithDuration:0.22 animations:^{
            CGRect frame = self.bannerView.frame;
            frame.origin.y = -frame.size.height - 10.f;
            self.bannerView.frame = frame;
        } completion:^(__unused BOOL finished) {
            self.window.hidden = YES;
            self.isShowing = NO;
            self.currentUserName = nil;
            self.currentAvatarToken = nil;
            [self processNextIfNeeded];
        }];
    });
}

- (void)loadAvatarIfNeeded:(NSString *)avatarURL {
    UIImage *placeholder = [self placeholderImage];
    self.avatarView.image = placeholder;

    if (avatarURL.length == 0) {
        self.currentAvatarToken = nil;
        return;
    }

    UIImage *cached = [self.imageCache objectForKey:avatarURL];
    if (cached) {
        self.avatarView.image = cached;
        self.currentAvatarToken = nil;
        return;
    }

    NSURL *url = [NSURL URLWithString:avatarURL];
    if (!url) {
        self.currentAvatarToken = nil;
        return;
    }

    NSString *token = NSUUID.UUID.UUIDString;
    self.currentAvatarToken = token;

    NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithURL:url completionHandler:^(NSData *data, __unused NSURLResponse *response, NSError *error) {
        if (error || data.length == 0) return;
        UIImage *img = [UIImage imageWithData:data];
        if (!img) return;
        [self.imageCache setObject:img forKey:avatarURL];

        dispatch_async(dispatch_get_main_queue(), ^{
            if (![self.currentAvatarToken isEqualToString:token]) {
                return;
            }
            self.avatarView.image = img;
        });
    }];
    [task resume];
}

- (UIImage *)placeholderImage {
    static UIImage *img;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        CGFloat size = 34.f;
        UIGraphicsBeginImageContextWithOptions(CGSizeMake(size, size), NO, 0);
        [[UIColor colorWithWhite:1 alpha:0.18] setFill];
        UIBezierPath *path = [UIBezierPath bezierPathWithOvalInRect:CGRectMake(0, 0, size, size)];
        [path fill];
        img = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
    });
    return img;
}

- (UIWindowScene *)activeWindowScene {
    if (@available(iOS 13.0, *)) {
        for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
            if (![scene isKindOfClass:[UIWindowScene class]]) continue;
            if (scene.activationState == UISceneActivationStateForegroundActive) {
                return (UIWindowScene *)scene;
            }
        }
    }
    return nil;
}

- (void)onTap {
    NSString *target = self.currentUserName;
    if (target.length == 0) {
        [self hide];
        return;
    }

    BOOL opened = NO;
    Class pluginCls = NSClassFromString(@"FlutterBizConversationPlugin");
    if (pluginCls) {
        Class centerCls = NSClassFromString(@"MMServiceCenter");
        if (centerCls && [centerCls respondsToSelector:@selector(defaultCenter)]) {
            id center = [centerCls performSelector:@selector(defaultCenter)];
            if (center && [center respondsToSelector:@selector(getService:)]) {
                id plugin = [center performSelector:@selector(getService:) withObject:pluginCls];
                SEL sel = NSSelectorFromString(@"enterChattingUIUsername:error:");
                if (plugin && [plugin respondsToSelector:sel]) {
                    NSError *error = nil;
                    ((void (*)(id, SEL, NSString *, NSError **))objc_msgSend)(plugin, sel, target, &error);
                    if (error == nil) {
                        opened = YES;
                    }
                }
            }
        }
    }

    if (!opened) {
        NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"weixin://dl/chat?%@", target]];
        if (url) {
            [[UIApplication sharedApplication] openURL:url options:@{} completionHandler:nil];
        }
    }

    [self hide];
}

@end
