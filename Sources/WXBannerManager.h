#import <UIKit/UIKit.h>

@interface WXBannerManager : NSObject

+ (instancetype)shared;
- (void)showWithTitle:(NSString *)title
              message:(NSString *)message
            avatarURL:(NSString *)avatarURL
             userName:(NSString *)userName;

@end
