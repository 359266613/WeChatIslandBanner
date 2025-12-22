#import "WMMConfig.h"

static NSString *const kWMMEnableMergeKey = @"com.wechat.messagemerge.enable";
static NSString *const kWMMGroupSpacingKey = @"com.wechat.messagemerge.groupSpacing";
static NSString *const kWMMPrivateSpacingKey = @"com.wechat.messagemerge.privateSpacing";
static NSString *const kWMMHideLeftAvatarKey = @"com.wechat.messagemerge.hideLeftAvatar";
static NSString *const kWMMHideRightAvatarKey = @"com.wechat.messagemerge.hideRightAvatar";
static NSString *const kWMMEnableCustomLogicKey = @"com.wechat.messagemerge.enableCustomLogic";
static NSString *const kWMMTimeWindowKey = @"com.wechat.messagemerge.timeWindow";

@implementation WMMConfig

+ (instancetype)shared {
    static WMMConfig *cfg;
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
        kWMMEnableMergeKey: @YES,
        kWMMGroupSpacingKey: @1.0,
        kWMMPrivateSpacingKey: @1.0,
        kWMMHideLeftAvatarKey: @NO,
        kWMMHideRightAvatarKey: @NO,
        kWMMEnableCustomLogicKey: @YES,
        kWMMTimeWindowKey: @120
    };
}

+ (void)registerDefaults {
    [[NSUserDefaults standardUserDefaults] registerDefaults:[self defaultValues]];
}

- (void)reload {
    NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
    self.enableMerge = [ud boolForKey:kWMMEnableMergeKey];
    self.groupSpacing = [ud doubleForKey:kWMMGroupSpacingKey];
    self.privateSpacing = [ud doubleForKey:kWMMPrivateSpacingKey];
    self.hideLeftAvatar = [ud boolForKey:kWMMHideLeftAvatarKey];
    self.hideRightAvatar = [ud boolForKey:kWMMHideRightAvatarKey];
    self.enableCustomMergeLogic = [ud boolForKey:kWMMEnableCustomLogicKey];
    self.mergeTimeWindow = [ud integerForKey:kWMMTimeWindowKey];
}

- (void)resetToDefaults {
    NSDictionary *defaults = [WMMConfig defaultValues];
    NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
    [defaults enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
        [ud setObject:obj forKey:key];
    }];
    [ud synchronize];
    [self reload];
}

- (void)save {
    NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
    [ud setBool:self.enableMerge forKey:kWMMEnableMergeKey];
    [ud setDouble:self.groupSpacing forKey:kWMMGroupSpacingKey];
    [ud setDouble:self.privateSpacing forKey:kWMMPrivateSpacingKey];
    [ud setBool:self.hideLeftAvatar forKey:kWMMHideLeftAvatarKey];
    [ud setBool:self.hideRightAvatar forKey:kWMMHideRightAvatarKey];
    [ud setBool:self.enableCustomMergeLogic forKey:kWMMEnableCustomLogicKey];
    [ud setInteger:self.mergeTimeWindow forKey:kWMMTimeWindowKey];
    [ud synchronize];
}

@end
