#import "NICompatibility.h"
#import "NIConfigurationManager.h"
#import <UIKit/UIKit.h>
#import <sys/utsname.h>

@implementation NICompatibility

+ (instancetype)sharedCompatibility {
    static NICompatibility *compatibility;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ compatibility = [NICompatibility new]; });
    return compatibility;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        struct utsname systemInfo;
        uname(&systemInfo);
        _machineIdentifier = [NSString stringWithUTF8String:systemInfo.machine] ?: @"unknown";
        _operatingSystemVersion = NSProcessInfo.processInfo.operatingSystemVersion;
    }
    return self;
}

- (BOOL)isSupportedOS {
    return self.operatingSystemVersion.majorVersion >= 15 &&
        UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPhone;
}

- (BOOL)mayCreateOverlay {
    if (![self isSupportedOS]) return NO;
    NIConfigurationManager *configuration = NIConfigurationManager.sharedManager;
    if (![configuration boolForKey:@"Enabled"]) return NO;
    if ([configuration boolForKey:@"ForceOverlay"]) return YES;

    static NSSet<NSString *> *nativeIslandModels;
    static NSSet<NSString *> *legacyOverlayModels;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        nativeIslandModels = [NSSet setWithArray:@[
            @"iPhone15,2", @"iPhone15,3", @"iPhone15,4", @"iPhone15,5",
            @"iPhone16,1", @"iPhone16,2", @"iPhone17,1", @"iPhone17,2",
            @"iPhone17,3", @"iPhone17,4"
        ]];
        legacyOverlayModels = [NSSet setWithArray:@[
            @"iPhone8,1", @"iPhone8,2", @"iPhone8,4", @"iPhone9,1", @"iPhone9,2",
            @"iPhone9,3", @"iPhone9,4", @"iPhone10,1", @"iPhone10,2", @"iPhone10,3",
            @"iPhone10,4", @"iPhone10,5", @"iPhone10,6", @"iPhone11,2", @"iPhone11,4",
            @"iPhone11,6", @"iPhone11,8", @"iPhone12,1", @"iPhone12,3", @"iPhone12,5",
            @"iPhone12,8", @"iPhone13,1", @"iPhone13,2", @"iPhone13,3", @"iPhone13,4",
            @"iPhone14,2", @"iPhone14,3", @"iPhone14,4", @"iPhone14,5", @"iPhone14,6",
            @"iPhone14,7", @"iPhone14,8"
        ]];
    });
    if ([nativeIslandModels containsObject:self.machineIdentifier]) return NO;
    return [legacyOverlayModels containsObject:self.machineIdentifier];
}

@end