#import <UIKit/UIKit.h>

// 消息合并配置模型
@interface WMMConfig : NSObject

@property (nonatomic, assign) BOOL enableMerge;
@property (nonatomic, assign) CGFloat groupSpacing;
@property (nonatomic, assign) CGFloat privateSpacing;
@property (nonatomic, assign) BOOL hideLeftAvatar;
@property (nonatomic, assign) BOOL hideRightAvatar;
@property (nonatomic, assign) BOOL enableCustomMergeLogic;
@property (nonatomic, assign) NSInteger mergeTimeWindow;

+ (instancetype)shared;
+ (void)registerDefaults;
- (void)resetToDefaults;
- (void)save;
- (void)reload;

@end
