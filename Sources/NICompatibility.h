#import <Foundation/Foundation.h>

@interface NICompatibility : NSObject
+ (instancetype)sharedCompatibility;
- (BOOL)isSupportedOS;
- (BOOL)mayCreateOverlay;
@property (nonatomic, copy, readonly) NSString *machineIdentifier;
@property (nonatomic, readonly) NSOperatingSystemVersion operatingSystemVersion;
@end