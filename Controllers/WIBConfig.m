#import "WIBConfig.h"

static NSString *const kWIBEnableKey          = @"com.wechat.island.enable";
static NSString *const kWIBWidthRatioKey      = @"com.wechat.island.widthRatio";
static NSString *const kWIBHeightKey          = @"com.wechat.island.height";
static NSString *const kWIBEnableBgKey        = @"com.wechat.island.bg.enable";
static NSString *const kWIBBgColorKey         = @"com.wechat.island.bg.color";
static NSString *const kWIBEnableBorderKey    = @"com.wechat.island.border.enable";
static NSString *const kWIBBorderColorKey     = @"com.wechat.island.border.color";
static NSString *const kWIBEnableTextColorKey = @"com.wechat.island.text.enable";
static NSString *const kWIBTextColorKey       = @"com.wechat.island.text.color";

@implementation WIBConfig

+ (instancetype)shared {
    static WIBConfig *cfg;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        [self registerDefaults];
        cfg = [[self alloc] init];
        [cfg reload];
    });
    return cfg;
}

+ (NSDictionary *)defaultValues {
    return @{
        kWIBEnableKey: @YES,
        kWIBWidthRatioKey: @0.85,
        kWIBHeightKey: @52.0,
        kWIBEnableBgKey: @NO,
        kWIBBgColorKey: @"#FFFFFFFF", 
        kWIBEnableBorderKey: @NO,
        kWIBBorderColorKey: @"#FFFFFFFF",
        kWIBEnableTextColorKey: @NO,
        kWIBTextColorKey: @"#FFFFFFFF",
    };
}

+ (void)registerDefaults {
    [[NSUserDefaults standardUserDefaults] registerDefaults:[self defaultValues]];
}

- (void)reload {
    NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
    self.enableIsland      = [ud boolForKey:kWIBEnableKey];
    self.widthRatio        = [ud doubleForKey:kWIBWidthRatioKey];
    self.height            = [ud doubleForKey:kWIBHeightKey];
    self.enableBackground  = [ud boolForKey:kWIBEnableBgKey];
    self.backgroundColor   = [self colorFromHex:[ud stringForKey:kWIBBgColorKey] defaultHex:@"#FFFFFFFF"];
    self.enableBorder      = [ud boolForKey:kWIBEnableBorderKey];
    self.borderColor       = [self colorFromHex:[ud stringForKey:kWIBBorderColorKey] defaultHex:@"#FFFFFFFF"];
    self.enableTextColor   = [ud boolForKey:kWIBEnableTextColorKey];
    self.textColor         = [self colorFromHex:[ud stringForKey:kWIBTextColorKey] defaultHex:@"#FFFFFFFF"];

    self.widthRatio = MIN(MAX(self.widthRatio, 0.5), 1.0);
    self.height     = MIN(MAX(self.height, 36.0), 88.0);
}

- (void)resetToDefaults {
    NSDictionary *defaults = [WIBConfig defaultValues];
    NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
    [defaults enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
        [ud setObject:obj forKey:key];
    }];
    [ud synchronize];
    [self reload];
}

- (void)save {
    NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
    [ud setBool:self.enableIsland forKey:kWIBEnableKey];
    [ud setDouble:self.widthRatio forKey:kWIBWidthRatioKey];
    [ud setDouble:self.height forKey:kWIBHeightKey];
    [ud setBool:self.enableBackground forKey:kWIBEnableBgKey];
    [ud setObject:[self hexFromColor:self.backgroundColor] forKey:kWIBBgColorKey];
    [ud setBool:self.enableBorder forKey:kWIBEnableBorderKey];
    [ud setObject:[self hexFromColor:self.borderColor] forKey:kWIBBorderColorKey];
    [ud setBool:self.enableTextColor forKey:kWIBEnableTextColorKey];
    [ud setObject:[self hexFromColor:self.textColor] forKey:kWIBTextColorKey];
    [ud synchronize];
}

#pragma mark - Helpers

- (UIColor *)colorFromHex:(NSString *)hex defaultHex:(NSString *)fallback {
    NSString *useHex = hex.length ? hex : fallback;
    NSString *clean = [[useHex stringByReplacingOccurrencesOfString:@"#" withString:@""] uppercaseString];
    unsigned int value = 0;
    [[NSScanner scannerWithString:clean] scanHexInt:&value];
    CGFloat a, r, g, b;
    if (clean.length == 8) {
        a = ((value >> 24) & 0xFF) / 255.0;
        r = ((value >> 16) & 0xFF) / 255.0;
        g = ((value >> 8) & 0xFF) / 255.0;
        b = (value & 0xFF) / 255.0;
    } else { // 默认 6 位
        a = 1.0;
        r = ((value >> 16) & 0xFF) / 255.0;
        g = ((value >> 8) & 0xFF) / 255.0;
        b = (value & 0xFF) / 255.0;
    }
    return [UIColor colorWithRed:r green:g blue:b alpha:a];
}

- (NSString *)hexFromColor:(UIColor *)color {
    if (!color) return @"#000000";
    CGFloat r, g, b, a;
    if (![color getRed:&r green:&g blue:&b alpha:&a]) {
        CGFloat white;
        if ([color getWhite:&white alpha:&a]) {
            r = g = b = white;
        } else {
            return @"#000000";
        }
    }
    int ri = (int)roundf(r * 255);
    int gi = (int)roundf(g * 255);
    int bi = (int)roundf(b * 255);
    int ai = (int)roundf(a * 255);
    return [NSString stringWithFormat:@"#%02X%02X%02X%02X", ai, ri, gi, bi];
}

@end

