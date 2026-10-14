#import "NISettingsController.h"
#import <Preferences/PSSpecifier.h>

static NSString * const NISettingsDomain = @"com.neoisland.preferences";
static NSString * const NISettingsChanged = @"com.neoisland.configuration.changed";

@interface NISettingsController ()
@property (nonatomic, strong) NSUserDefaults *settings;
@end

@implementation NISettingsController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Dynamic Island";
    self.view.backgroundColor = [UIColor blackColor];
    self.tableView.backgroundColor = [UIColor blackColor];
    self.tableView.separatorColor = [UIColor colorWithWhite:0.2 alpha:1];
    self.navigationController.navigationBar.barStyle = UIBarStyleBlack;
    self.navigationController.navigationBar.translucent = NO;
    self.navigationController.navigationBar.backgroundColor = [UIColor blackColor];
    self.navigationController.navigationBar.tintColor = [UIColor systemBlueColor];
    self.settings = [[NSUserDefaults alloc] initWithSuiteName:NISettingsDomain];
}

- (PSSpecifier *)group:(NSString *)title footer:(NSString *)footer {
    PSSpecifier *specifier = [PSSpecifier preferenceSpecifierNamed:title target:nil set:nil get:nil detail:nil cell:PSGroupCell edit:nil];
    if (footer.length > 0) [specifier setProperty:footer forKey:@"footerText"];
    return specifier;
}

- (PSSpecifier *)switchNamed:(NSString *)title key:(NSString *)key defaultValue:(BOOL)defaultValue {
    PSSpecifier *specifier = [PSSpecifier preferenceSpecifierNamed:title target:self
        set:@selector(setPreferenceValue:specifier:) get:@selector(readPreferenceValue:)
        detail:nil cell:PSSwitchCell edit:nil];
    [specifier setProperty:key forKey:@"key"];
    [specifier setProperty:@(defaultValue) forKey:@"default"];
    return specifier;
}

- (PSSpecifier *)sliderNamed:(NSString *)title key:(NSString *)key defaultValue:(NSNumber *)defaultValue
    minimum:(NSNumber *)minimum maximum:(NSNumber *)maximum {
    PSSpecifier *specifier = [PSSpecifier preferenceSpecifierNamed:title target:self
        set:@selector(setPreferenceValue:specifier:) get:@selector(readPreferenceValue:)
        detail:nil cell:PSSliderCell edit:nil];
    [specifier setProperty:key forKey:@"key"];
    [specifier setProperty:defaultValue forKey:@"default"];
    [specifier setProperty:minimum forKey:@"min"];
    [specifier setProperty:maximum forKey:@"max"];
    return specifier;
}

- (PSSpecifier *)textNamed:(NSString *)title key:(NSString *)key defaultValue:(NSString *)defaultValue {
    PSSpecifier *specifier = [PSSpecifier preferenceSpecifierNamed:title target:self
        set:@selector(setPreferenceValue:specifier:) get:@selector(readPreferenceValue:)
        detail:nil cell:PSEditTextCell edit:nil];
    [specifier setProperty:key forKey:@"key"];
    [specifier setProperty:defaultValue forKey:@"default"];
    return specifier;
}

- (PSSpecifier *)buttonNamed:(NSString *)title action:(SEL)action {
    return [PSSpecifier preferenceSpecifierNamed:title target:self set:action get:nil
        detail:nil cell:PSButtonCell edit:nil];
}

- (NSArray *)specifiers {
    if (_specifiers) return _specifiers;
    NSMutableArray *items = [NSMutableArray array];
    [items addObject:[self group:@"Dynamic Island" footer:@"Overlay is limited to recognized non-Dynamic-Island iPhones. Unknown and native Dynamic Island models are disabled by default."]];
    [items addObject:[self switchNamed:@"Enabled" key:@"Enabled" defaultValue:YES]];
    [items addObject:[self switchNamed:@"Always show idle pill" key:@"AlwaysShowIdle" defaultValue:NO]];
    [items addObject:[self switchNamed:@"Show on Lock Screen" key:@"LockScreenEnabled" defaultValue:NO]];
    [items addObject:[self switchNamed:@"Allow sensitive metadata while locked" key:@"ShowSensitiveOnLockScreen" defaultValue:NO]];
    [items addObject:[self switchNamed:@"Force overlay on unrecognized hardware" key:@"ForceOverlay" defaultValue:NO]];
    [items addObject:[self group:@"Modules" footer:@"Unavailable data is omitted. Ringer switch, flashlight control, screen-recording detection, incoming-call integration and system Clock timers are not implemented."]];
    [items addObject:[self switchNamed:@"Music metadata and controls" key:@"MusicEnabled" defaultValue:YES]];
    [items addObject:[self switchNamed:@"Battery status" key:@"BatteryEnabled" defaultValue:YES]];
    [items addObject:[self switchNamed:@"Low battery transition at 20%" key:@"BatteryWarningEnabled" defaultValue:YES]];
    [items addObject:[self switchNamed:@"Output volume" key:@"VolumeEnabled" defaultValue:YES]];
    [items addObject:[self switchNamed:@"Network reachability" key:@"NetworkEnabled" defaultValue:YES]];
    [items addObject:[self switchNamed:@"Bluetooth/headphone route" key:@"AudioRouteEnabled" defaultValue:YES]];
    [items addObject:[self switchNamed:@"Neo Island timer" key:@"TimerEnabled" defaultValue:YES]];
    [items addObject:[self sliderNamed:@"Timer duration (minutes)" key:@"TimerDurationMinutes" defaultValue:@5 minimum:@1 maximum:@180]];
    [items addObject:[self buttonNamed:@"Start timer" action:@selector(startTimer:)]];
    [items addObject:[self buttonNamed:@"Pause timer" action:@selector(pauseTimer:)]];
    [items addObject:[self buttonNamed:@"Resume timer" action:@selector(resumeTimer:)]];
    [items addObject:[self buttonNamed:@"Cancel timer" action:@selector(cancelTimer:)]];
    [items addObject:[self switchNamed:@"Custom text widget" key:@"WidgetEnabled" defaultValue:YES]];
    [items addObject:[self textNamed:@"Widget text" key:@"WidgetText" defaultValue:@""]];

    [items addObject:[self group:@"Appearance and motion" footer:@"Changes apply immediately. Position and size are clamped to the visible safe area."]];
    [items addObject:[self switchNamed:@"Haptic feedback" key:@"HapticsEnabled" defaultValue:YES]];
    [items addObject:[self sliderNamed:@"Pill width" key:@"PillWidth" defaultValue:@180 minimum:@120 maximum:@320]];
    [items addObject:[self sliderNamed:@"Pill height" key:@"PillHeight" defaultValue:@48 minimum:@36 maximum:@100]];
    [items addObject:[self sliderNamed:@"Content size" key:@"ContentScale" defaultValue:@1 minimum:@0.7 maximum:@1.5]];
    [items addObject:[self sliderNamed:@"Horizontal offset" key:@"OffsetX" defaultValue:@0 minimum:@(-100) maximum:@100]];
    [items addObject:[self sliderNamed:@"Vertical offset" key:@"OffsetY" defaultValue:@8 minimum:@(-20) maximum:@100]];
    [items addObject:[self sliderNamed:@"Open/close speed" key:@"AnimationSpeed" defaultValue:@0.32 minimum:@0.08 maximum:@1.2]];
    [items addObject:[self sliderNamed:@"Spring bounce" key:@"AnimationBounce" defaultValue:@0.78 minimum:@0.45 maximum:@1]];
    [items addObject:[self sliderNamed:@"Auto-collapse seconds" key:@"AutoCollapseSeconds" defaultValue:@5 minimum:@0 maximum:@30]];
    [items addObject:[self buttonNamed:@"Restore defaults" action:@selector(restoreDefaults:)]];
    _specifiers = items;
    return _specifiers;
}

- (id)readPreferenceValue:(PSSpecifier *)specifier {
    NSString *key = [specifier propertyForKey:@"key"];
    if (![key isKindOfClass:NSString.class] || key.length == 0) return nil;
    id value = [self.settings objectForKey:key];
    if (!value) value = [specifier propertyForKey:@"default"];
    NSNumber *minimum = [specifier propertyForKey:@"min"];
    NSNumber *maximum = [specifier propertyForKey:@"max"];
    if ([value isKindOfClass:NSNumber.class] && minimum && maximum) {
        value = @(MIN(maximum.doubleValue, MAX(minimum.doubleValue, [value doubleValue])));
    }
    return value;
}

- (void)setPreferenceValue:(id)value specifier:(PSSpecifier *)specifier {
    NSString *key = [specifier propertyForKey:@"key"];
    if (![key isKindOfClass:NSString.class] || key.length == 0 || !value || !self.settings) return;
    NSNumber *minimum = [specifier propertyForKey:@"min"];
    NSNumber *maximum = [specifier propertyForKey:@"max"];
    if ([value isKindOfClass:NSNumber.class] && minimum && maximum) {
        value = @(MIN(maximum.doubleValue, MAX(minimum.doubleValue, [value doubleValue])));
    }
    [self.settings setObject:value forKey:key];
    [self.settings synchronize];
    [self postConfigurationChange];
}

- (void)postConfigurationChange {
    CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(),
        (__bridge CFStringRef)NISettingsChanged, NULL, NULL, YES);
}

- (void)sendTimerCommand:(NSInteger)command {
    if (!self.settings || command < 1 || command > 4) return;
    if (command == 1) [self.settings setBool:YES forKey:@"TimerEnabled"];
    [self.settings setInteger:command forKey:@"TimerCommand"];
    [self.settings synchronize];
    [self postConfigurationChange];
}

- (void)startTimer:(PSSpecifier *)specifier { (void)specifier; [self sendTimerCommand:1]; }
- (void)pauseTimer:(PSSpecifier *)specifier { (void)specifier; [self sendTimerCommand:2]; }
- (void)resumeTimer:(PSSpecifier *)specifier { (void)specifier; [self sendTimerCommand:3]; }
- (void)cancelTimer:(PSSpecifier *)specifier { (void)specifier; [self sendTimerCommand:4]; }

- (void)restoreDefaults:(PSSpecifier *)specifier {
    (void)specifier;
    if (!self.settings) return;
    NSDictionary *defaults = @{
        @"Enabled": @YES, @"AlwaysShowIdle": @NO, @"LockScreenEnabled": @NO,
        @"ShowSensitiveOnLockScreen": @NO, @"ForceOverlay": @NO,
        @"MusicEnabled": @YES, @"BatteryEnabled": @YES, @"BatteryWarningEnabled": @YES,
        @"VolumeEnabled": @YES, @"NetworkEnabled": @YES, @"AudioRouteEnabled": @YES,
        @"TimerEnabled": @YES, @"WidgetEnabled": @YES, @"WidgetText": @"",
        @"HapticsEnabled": @YES, @"PillWidth": @180, @"PillHeight": @48,
        @"ContentScale": @1, @"OffsetX": @0, @"OffsetY": @8, @"AnimationSpeed": @0.32,
        @"AnimationBounce": @0.78, @"AutoCollapseSeconds": @5, @"TimerDurationMinutes": @5,
        @"TimerCommand": @0, @"TimerEndTimestamp": @0, @"TimerRemaining": @0,
        @"LowBatteryLatched": @NO, @"LastObservedBatteryLevel": @-1
    };
    for (NSString *key in defaults) [self.settings setObject:defaults[key] forKey:key];
    [self.settings synchronize];
    [self postConfigurationChange];
    [self reloadSpecifiers];
}

@end