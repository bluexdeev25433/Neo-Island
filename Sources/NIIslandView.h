#import <UIKit/UIKit.h>

@class NIModuleProvider;

@interface NIIslandView : NSObject <UIGestureRecognizerDelegate>
- (instancetype)initWithModuleProvider:(NIModuleProvider *)moduleProvider;
- (void)updateWithSnapshots:(NSArray<NSDictionary<NSString *, id> *> *)snapshots;
- (void)show;
- (void)removeFromScreen;
@end