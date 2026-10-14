#import <UIKit/UIKit.h>

@interface NIIconRenderer : NSObject
+ (UIImage *)imageForSymbol:(NSString *)symbol pointSize:(CGFloat)pointSize;
@end