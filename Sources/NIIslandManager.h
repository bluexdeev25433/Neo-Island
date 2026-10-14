#import <Foundation/Foundation.h>

@interface NIIslandManager : NSObject
+ (instancetype)sharedManager;
- (void)start;
- (void)refresh;
@end