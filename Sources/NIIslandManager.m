#import "NIIslandManager.h"
#import "NICompatibility.h"
#import "NIConfigurationManager.h"
#import "NIIslandView.h"
#import "NIModuleProvider.h"
#import <os/log.h>

static void NIConfigurationDarwinChanged(CFNotificationCenterRef center, void *observer,
    CFStringRef name, const void *object, CFDictionaryRef userInfo);

@interface NIIslandManager ()
@property (nonatomic, strong) NIIslandView *islandView;
@property (nonatomic, strong) NIModuleProvider *moduleProvider;
@property (nonatomic) BOOL started;
- (void)configurationDidChange:(NSNotification *)notification;
@end

@implementation NIIslandManager

+ (instancetype)sharedManager {
    static NIIslandManager *manager;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ manager = [NIIslandManager new]; });
    return manager;
}

- (void)start {
    if (self.started) return;
    self.started = YES;
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(configurationDidChange:)
        name:NIConfigurationDidChangeNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(refresh)
        name:@"NIModuleProviderDidChange" object:nil];
    CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(),
        (__bridge const void *)self, NIConfigurationDarwinChanged,
        (__bridge CFStringRef)NIConfigurationDidChangeNotification, NULL,
        CFNotificationSuspensionBehaviorDeliverImmediately);
    [self refresh];
}

static void NIConfigurationDarwinChanged(CFNotificationCenterRef center, void *observer,
    CFStringRef name, const void *object, CFDictionaryRef userInfo) {
    (void)center; (void)name; (void)object; (void)userInfo;
    NIIslandManager *manager = (__bridge NIIslandManager *)observer;
    dispatch_async(dispatch_get_main_queue(), ^{ [manager configurationDidChange:nil]; });
}

- (void)refresh {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (![NICompatibility.sharedCompatibility mayCreateOverlay]) {
            [self.islandView removeFromScreen];
            self.islandView = nil;
            self.moduleProvider = nil;
            os_log_info(OS_LOG_DEFAULT, "Neo Island overlay inactive: unsupported device/system or disabled setting");
            return;
        }
        if (!self.moduleProvider) self.moduleProvider = [NIModuleProvider new];
        if (!self.islandView) self.islandView = [[NIIslandView alloc] initWithModuleProvider:self.moduleProvider];
        [self.islandView updateWithSnapshots:self.moduleProvider.snapshots];
        [self.islandView show];
        os_log_info(OS_LOG_DEFAULT, "Neo Island overlay active");
    });
}

- (void)configurationDidChange:(NSNotification *)notification {
    (void)notification;
    dispatch_async(dispatch_get_main_queue(), ^{
        if (![NICompatibility.sharedCompatibility mayCreateOverlay]) {
            [self refresh];
            return;
        }
        [NIConfigurationManager.sharedManager reloadFromDisk];
        if (!self.moduleProvider) self.moduleProvider = [NIModuleProvider new];
        [self.moduleProvider handleConfigurationChanges];
        [self refresh];
    });
}

@end