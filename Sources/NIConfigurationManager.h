#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface NIConfigurationManager : NSObject
+ (instancetype)sharedManager;
- (id)objectForKey:(NSString *)key;
- (BOOL)boolForKey:(NSString *)key;
- (CGFloat)floatForKey:(NSString *)key;
- (void)setObject:(id)value forConfigurationKey:(NSString *)key;
- (void)reloadFromDisk;
- (void)resetToDefaults;
@end

FOUNDATION_EXPORT NSString * const NIConfigurationDidChangeNotification;

NS_ASSUME_NONNULL_END