#import <UIKit/UIKit.h>

// 简单的配置模型，持久化到 NSUserDefaults
@interface WIBConfig : NSObject
@property (nonatomic, assign) BOOL enableIsland;
@property (nonatomic, assign) CGFloat widthRatio;     // 相对屏幕宽度，0.5~1.0
@property (nonatomic, assign) CGFloat height;         // 高度，单位 point
@property (nonatomic, assign) BOOL enableBackground;
@property (nonatomic, strong) UIColor *backgroundColor;
@property (nonatomic, assign) BOOL enableBorder;
@property (nonatomic, strong) UIColor *borderColor;
@property (nonatomic, assign) BOOL enableTextColor;
@property (nonatomic, strong) UIColor *textColor;

+ (instancetype)shared;
+ (void)registerDefaults;
- (void)resetToDefaults;
- (void)save;
- (void)reload;
@end

