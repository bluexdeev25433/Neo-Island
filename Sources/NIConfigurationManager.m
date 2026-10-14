#import "NIConfigurationManager.h"
#import <math.h>

NSString * const NIConfigurationDidChangeNotification = @"com.neoisland.configuration.changed";
static NSString * const NIPreferencesDomain = @"com.neoisland.preferences";
static NSInteger const NISchemaVersion = 1;

@interface NIConfigurationManager ()
@property (nonatomic, strong) NSUserDefaults *defaults;
@property (nonatomic, copy) NSDictionary<NSString *, id> *schema;
- (id)normalizedValue:(id)value forKey:(NSString *)key;
@end

@implementation NIConfigurationManager

+ (instancetype)sharedManager {
    static NIConfigurationManager *manager;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ manager = [NIConfigurationManager new]; });
    return manager;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _defaults = [[NSUserDefaults alloc] initWithSuiteName:NIPreferencesDomain];
        _schema = @{
            @"Enabled": @YES, @"AlwaysShowIdle": @NO,
            @"MusicEnabled": @YES, @"BatteryEnabled": @YES, @"BatteryWarningEnabled": @YES,
            @"VolumeEnabled": @YES, @"NetworkEnabled": @YES, @"AudioRouteEnabled": @YES,
            @"TimerEnabled": @YES, @"WidgetEnabled": @YES,
            @"LockScreenEnabled": @NO, @"ShowSensitiveOnLockScreen": @NO,
            @"ForceOverlay": @NO, @"HapticsEnabled": @YES,
            @"TimerCommand": @0, @"TimerEndTimestamp": @0.0, @"TimerRemaining": @0.0,
            @"LastObservedBatteryLevel": @-1.0, @"LowBatteryLatched": @NO,
            @"WidgetText": @"",
            @"PillWidth": @180.0, @"PillHeight": @48.0, @"ContentScale": @1.0,
            @"OffsetX": @0.0, @"OffsetY": @8.0, @"AnimationSpeed": @0.32,
            @"AnimationBounce": @0.78, @"AutoCollapseSeconds": @5.0,
            @"TimerDurationMinutes": @5.0
        };
        [self migrateAndNormalize];
    }
    return self;
}

- (void)migrateAndNormalize {
    NSInteger storedVersion = [self.defaults integerForKey:@"SchemaVersion"];
    if (storedVersion > NISchemaVersion) return;
    for (NSString *key in self.schema) {
        [self.defaults setObject:[self normalizedValue:[self.defaults objectForKey:key] forKey:key] forKey:key];
    }
    [self.defaults setInteger:NISchemaVersion forKey:@"SchemaVersion"];
    [self.defaults synchronize];
}

- (id)normalizedValue:(id)value forKey:(NSString *)key {
    id fallback = self.schema[key];
    if ([fallback isKindOfClass:[NSString class]]) {
        if (![value isKindOfClass:[NSString class]]) value = fallback;
        return [value length] > 100 ? [value substringToIndex:100] : value;
    }
    if (![value isKindOfClass:[NSNumber class]]) value = fallback;
    if ([key hasSuffix:@"Enabled"] || [key isEqualToString:@"ForceOverlay"] ||
        [key isEqualToString:@"AlwaysShowIdle"] || [key isEqualToString:@"ShowSensitiveOnLockScreen"] ||
        [key isEqualToString:@"HapticsEnabled"] || [key isEqualToString:@"LowBatteryLatched"]) {
        return @([value boolValue]);
    }
    CGFloat minimum = 0;
    CGFloat maximum = 10000;
    if ([key isEqualToString:@"PillWidth"]) { minimum = 120; maximum = 320; }
    else if ([key isEqualToString:@"PillHeight"]) { minimum = 36; maximum = 100; }
    else if ([key isEqualToString:@"ContentScale"]) { minimum = 0.7; maximum = 1.5; }
    else if ([key isEqualToString:@"OffsetX"]) { minimum = -100; maximum = 100; }
    else if ([key isEqualToString:@"OffsetY"]) { minimum = -20; maximum = 100; }
    else if ([key isEqualToString:@"AnimationSpeed"]) { minimum = 0.08; maximum = 1.2; }
    else if ([key isEqualToString:@"AnimationBounce"]) { minimum = 0.45; maximum = 1.0; }
    else if ([key isEqualToString:@"AutoCollapseSeconds"]) { minimum = 0; maximum = 30; }
    else if ([key isEqualToString:@"TimerDurationMinutes"]) { minimum = 1; maximum = 180; }
    else if ([key isEqualToString:@"TimerCommand"]) { minimum = 0; maximum = 4; }
    else if ([key isEqualToString:@"TimerEndTimestamp"]) { minimum = 0; maximum = 4102444800.0; }
    else if ([key isEqualToString:@"TimerRemaining"]) { minimum = 0; maximum = 64800; }
    else if ([key isEqualToString:@"LastObservedBatteryLevel"]) { minimum = -1; maximum = 1; }
    CGFloat number = [value doubleValue];
    return @(MIN(maximum, MAX(minimum, isfinite(number) ? number : [fallback doubleValue])));
}

- (id)objectForKey:(NSString *)key {
    id fallback = self.schema[key];
    if (!fallback) return nil;
    return [self normalizedValue:[self.defaults objectForKey:key] forKey:key];
}

- (BOOL)boolForKey:(NSString *)key { return [[self objectForKey:key] boolValue]; }
- (CGFloat)floatForKey:(NSString *)key { return [[self objectForKey:key] doubleValue]; }

- (void)setObject:(id)value forConfigurationKey:(NSString *)key {
    id fallback = self.schema[key];
    if (!fallback) return;
    if ([key isEqualToString:@"WidgetText"] && ![value isKindOfClass:[NSString class]]) {
        return;
    }
    if (![key isEqualToString:@"WidgetText"] && ![value isKindOfClass:[NSNumber class]]) return;
    value = [self normalizedValue:value forKey:key];
    [self.defaults setObject:value forKey:key];
    [self.defaults synchronize];
    [[NSNotificationCenter defaultCenter] postNotificationName:NIConfigurationDidChangeNotification object:key];
    CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(),
        (__bridge CFStringRef)NIConfigurationDidChangeNotification, NULL, NULL, YES);
}

- (void)reloadFromDisk {
    [self.defaults synchronize];
    [self migrateAndNormalize];
}

- (void)resetToDefaults {
    for (NSString *key in self.schema) [self.defaults removeObjectForKey:key];
    [self.defaults setInteger:NISchemaVersion forKey:@"SchemaVersion"];
    [self.defaults synchronize];
    [[NSNotificationCenter defaultCenter] postNotificationName:NIConfigurationDidChangeNotification object:nil];
    CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(),
        (__bridge CFStringRef)NIConfigurationDidChangeNotification, NULL, NULL, YES);
}

@end