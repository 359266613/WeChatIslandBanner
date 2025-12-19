#import "WXBannerManager.h"
#import <objc/message.h>

@interface WXBannerManager ()
@property (nonatomic, strong) UIWindow *window;
@property (nonatomic, strong) UIView *bannerView;
@property (nonatomic, strong) UIImageView *avatarView;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *messageLabel;
@property (nonatomic, strong) NSCache<NSString *, UIImage *> *imageCache;
@property (nonatomic, assign) BOOL isShowing;
@property (nonatomic, copy) NSString *currentUserName;
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
        [self buildUI];
    }
    return self;
}

- (void)buildUI {
    CGRect screen = [UIScreen mainScreen].bounds;
    CGFloat width = MIN(screen.size.width, 360.f);
    CGFloat height = 52.f;

    self.window = [[UIWindow alloc] initWithFrame:screen];
    self.window.windowLevel = UIWindowLevelStatusBar + 10;
    self.window.backgroundColor = [UIColor clearColor];
    self.window.hidden = YES;
    self.window.userInteractionEnabled = YES;
    self.window.rootViewController = [UIViewController new];

    self.bannerView = [[UIView alloc] initWithFrame:CGRectMake((screen.size.width - width) / 2.f, -height - 10.f, width, height)];
    self.bannerView.backgroundColor = [UIColor colorWithWhite:0 alpha:0.85];
    self.bannerView.layer.cornerRadius = height / 2.f;
    self.bannerView.layer.masksToBounds = YES;

    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(onTap)];
    [self.bannerView addGestureRecognizer:tap];

    self.avatarView = [[UIImageView alloc] initWithFrame:CGRectZero];
    self.avatarView.contentMode = UIViewContentModeScaleAspectFill;
    self.avatarView.clipsToBounds = YES;

    self.titleLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    self.titleLabel.font = [UIFont boldSystemFontOfSize:14];
    self.titleLabel.textColor = UIColor.whiteColor;

    self.messageLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    self.messageLabel.font = [UIFont systemFontOfSize:13];
    self.messageLabel.textColor = [UIColor colorWithWhite:1 alpha:0.9];
    self.messageLabel.numberOfLines = 1;

    self.imageCache = [NSCache new];

    [self.window.rootViewController.view addSubview:self.bannerView];
    [self.bannerView addSubview:self.avatarView];
    [self.bannerView addSubview:self.titleLabel];
    [self.bannerView addSubview:self.messageLabel];
}

- (void)layoutLabels {
    CGFloat padding = 12.f;
    CGFloat avatar = 32.f;
    CGFloat midY = self.bannerView.bounds.size.height / 2.f;

    self.avatarView.frame = CGRectMake(padding, midY - avatar / 2.f, avatar, avatar);
    self.avatarView.layer.cornerRadius = avatar / 2.f;

    CGFloat textX = padding + avatar + 10.f;
    CGFloat textWidth = self.bannerView.bounds.size.width - textX - padding;
    self.titleLabel.frame = CGRectMake(textX, midY - 16, textWidth, 15);
    self.messageLabel.frame = CGRectMake(textX, midY + 1, textWidth, 14);
}

- (void)showWithTitle:(NSString *)title
              message:(NSString *)message
            avatarURL:(NSString *)avatarURL
             userName:(NSString *)userName {
    if (!title.length && !message.length) {
        return;
    }

    dispatch_async(dispatch_get_main_queue(), ^{
        self.titleLabel.text = title.length ? title : @"微信";
        self.messageLabel.text = message.length ? message : @"新消息";
        [self layoutLabels];
        [self loadAvatarIfNeeded:avatarURL];
        self.currentUserName = userName;

        if (self.isShowing) {
            [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(hide) object:nil];
            [self performSelector:@selector(hide) withObject:nil afterDelay:2.5];
            return;
        }

        self.isShowing = YES;
        self.window.hidden = NO;

        CGRect frame = self.bannerView.frame;
        frame.origin.y = -frame.size.height - 10.f;
        self.bannerView.frame = frame;

        [UIView animateWithDuration:0.35
                              delay:0
             usingSpringWithDamping:0.8
              initialSpringVelocity:0.8
                            options:UIViewAnimationOptionCurveEaseOut
                         animations:^{
            CGRect f = self.bannerView.frame;
            f.origin.y = 10.f;
            self.bannerView.frame = f;
        } completion:^(BOOL finished) {
            [self performSelector:@selector(hide) withObject:nil afterDelay:2.5];
        }];
    });
}

- (void)hide {
    dispatch_async(dispatch_get_main_queue(), ^{
        [UIView animateWithDuration:0.25 animations:^{
            CGRect f = self.bannerView.frame;
            f.origin.y = -f.size.height - 10.f;
            self.bannerView.frame = f;
        } completion:^(BOOL finished) {
            self.window.hidden = YES;
            self.isShowing = NO;
        }];
    });
}

- (void)loadAvatarIfNeeded:(NSString *)avatarURL {
    UIImage *placeholder = [self placeholderImage];
    if (!avatarURL.length) {
        self.avatarView.image = placeholder;
        return;
    }

    UIImage *cached = [self.imageCache objectForKey:avatarURL];
    if (cached) {
        self.avatarView.image = cached;
        return;
    }

    self.avatarView.image = placeholder;
    NSURL *url = [NSURL URLWithString:avatarURL];
    if (!url) return;

    NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithURL:url completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (error || data.length == 0) return;
        UIImage *img = [UIImage imageWithData:data];
        if (!img) return;
        [self.imageCache setObject:img forKey:avatarURL];
        dispatch_async(dispatch_get_main_queue(), ^{
            self.avatarView.image = img;
        });
    }];
    [task resume];
}

- (UIImage *)placeholderImage {
    static UIImage *img;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        CGFloat size = 32.f;
        UIGraphicsBeginImageContextWithOptions(CGSizeMake(size, size), NO, 0);
        [[UIColor colorWithWhite:1 alpha:0.18] setFill];
        UIBezierPath *path = [UIBezierPath bezierPathWithOvalInRect:CGRectMake(0, 0, size, size)];
        [path fill];
        img = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
    });
    return img;
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
            opened = YES;
        }
    }

    [self hide];
}

@end

