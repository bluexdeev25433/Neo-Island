#import "NIModuleProvider.h"
#import "NIConfigurationManager.h"
#import "NITimerLogic.h"
#import <UIKit/UIKit.h>
#import <MediaPlayer/MediaPlayer.h>
#import <AVFAudio/AVFAudio.h>
#import <SystemConfiguration/SystemConfiguration.h>
#import <netinet/in.h>

static void NIReachabilityChanged(SCNetworkReachabilityRef target, SCNetworkReachabilityFlags flags, void *info);
static void *NIAudioVolumeContext = &NIAudioVolumeContext;

@interface NIModuleProvider ()
@property (nonatomic, copy, readwrite) NSArray<NSDictionary<NSString *, id> *> *snapshots;
@property (nonatomic, strong) NSTimer *timerTicker;
@property (nonatomic, strong) NSTimer *batteryNoticeTimer;
@property (nonatomic) SCNetworkReachabilityRef reachability;
@property (nonatomic) NSTimeInterval lowBatteryNoticeExpiry;
@property (nonatomic) BOOL monitoringBattery;
@property (nonatomic) BOOL monitoringMusic;
@property (nonatomic) BOOL monitoringAudioRoute;
@property (nonatomic) BOOL monitoringVolume;
@property (nonatomic) BOOL monitoringNetwork;
- (void)updateObserversForConfiguration;
- (void)refreshAndNotify;
- (void)updateBatteryTransition;
- (void)batteryStateChanged:(NSNotification *)notification;
- (NITimerLogicState)currentTimerState;
- (void)storeTimerState:(NITimerLogicState)state;
- (void)finishTimer;
@end

static void NIReachabilityChanged(SCNetworkReachabilityRef target, SCNetworkReachabilityFlags flags, void *info) {
    (void)target; (void)flags;
    NIModuleProvider *provider = (__bridge NIModuleProvider *)info;
    dispatch_async(dispatch_get_main_queue(), ^{ [provider refreshAndNotify]; });
}

@implementation NIModuleProvider

- (instancetype)init {
    self = [super init];
    if (self) {
        self.snapshots = @[];
        NSNotificationCenter *center = NSNotificationCenter.defaultCenter;
        [center addObserver:self selector:@selector(protectedDataChanged:) name:UIApplicationProtectedDataWillBecomeUnavailable object:nil];
        [center addObserver:self selector:@selector(protectedDataChanged:) name:UIApplicationProtectedDataDidBecomeAvailable object:nil];
        [self updateObserversForConfiguration];
        [self updateBatteryTransition];
        [self refreshAndNotify];
        [self consumeTimerCommand];
        if ([NIConfigurationManager.sharedManager boolForKey:@"TimerEnabled"]) {
            NITimerLogicState state = [self currentTimerState];
            NSTimeInterval now = NSDate.date.timeIntervalSince1970;
            if (NITimerLogicIsExpired(state, now)) [self finishTimer];
            else if (state.endTimestamp > 0) [self startTicker];
        }
    }
    return self;
}

- (void)dealloc {
    [self.timerTicker invalidate];
    [self.batteryNoticeTimer invalidate];
    [NSNotificationCenter.defaultCenter removeObserver:self];
    if (self.monitoringMusic) [MPMusicPlayerController.systemMusicPlayer endGeneratingPlaybackNotifications];
    if (self.monitoringVolume) {
        [AVAudioSession.sharedInstance removeObserver:self forKeyPath:@"outputVolume" context:NIAudioVolumeContext];
    }
    if (self.monitoringBattery) UIDevice.currentDevice.batteryMonitoringEnabled = NO;
    if (self.reachability) {
        SCNetworkReachabilityUnscheduleFromRunLoop(self.reachability, CFRunLoopGetMain(), kCFRunLoopCommonModes);
        CFRelease(self.reachability);
    }
}

- (void)systemStateChanged:(NSNotification *)notification {
    (void)notification;
    [self refreshAndNotify];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object
    change:(NSDictionary<NSKeyValueChangeKey, id> *)change context:(void *)context {
    (void)object;
    (void)change;
    if (context == NIAudioVolumeContext && [keyPath isEqualToString:@"outputVolume"]) {
        dispatch_async(dispatch_get_main_queue(), ^{ [self refreshAndNotify]; });
        return;
    }
    [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
}

- (void)batteryStateChanged:(NSNotification *)notification {
    (void)notification;
    [self updateBatteryTransition];
    [self refreshAndNotify];
}

- (void)protectedDataChanged:(NSNotification *)notification {
    (void)notification;
    [self refreshAndNotify];
}

- (BOOL)mayShowSensitiveData {
    NIConfigurationManager *configuration = NIConfigurationManager.sharedManager;
    return UIApplication.sharedApplication.protectedDataAvailable || [configuration boolForKey:@"ShowSensitiveOnLockScreen"];
}

- (void)updateBatteryTransition {
    NIConfigurationManager *configuration = NIConfigurationManager.sharedManager;
    float level = UIDevice.currentDevice.batteryLevel;
    if (level < 0) return;
    float previous = [configuration floatForKey:@"LastObservedBatteryLevel"];
    BOOL latched = [configuration boolForKey:@"LowBatteryLatched"];
    if ([configuration boolForKey:@"BatteryWarningEnabled"] && previous > 0.20f && level <= 0.20f && !latched) {
        self.lowBatteryNoticeExpiry = NSDate.date.timeIntervalSince1970 + 8.0;
        [self.batteryNoticeTimer invalidate];
        __weak typeof(self) weakSelf = self;
        self.batteryNoticeTimer = [NSTimer scheduledTimerWithTimeInterval:8.0 repeats:NO block:^(NSTimer *timer) {
            (void)timer;
            weakSelf.lowBatteryNoticeExpiry = 0;
            [weakSelf refreshAndNotify];
        }];
        [configuration setObject:@YES forConfigurationKey:@"LowBatteryLatched"];
    } else if (level > 0.22f && latched) {
        [configuration setObject:@NO forConfigurationKey:@"LowBatteryLatched"];
    }
    [configuration setObject:@(level) forConfigurationKey:@"LastObservedBatteryLevel"];
}

- (NSDictionary *)musicSnapshot {
    if (![NIConfigurationManager.sharedManager boolForKey:@"MusicEnabled"] || ![self mayShowSensitiveData]) return nil;
    NSDictionary *info = MPNowPlayingInfoCenter.defaultCenter.nowPlayingInfo;
    NSString *title = [info[MPMediaItemPropertyTitle] isKindOfClass:NSString.class] ? info[MPMediaItemPropertyTitle] : nil;
    if (title.length == 0) return nil;
    NSString *artist = [info[MPMediaItemPropertyArtist] isKindOfClass:NSString.class] ? info[MPMediaItemPropertyArtist] : @"";
    id artworkValue = info[MPMediaItemPropertyArtwork];
    UIImage *artwork = [artworkValue isKindOfClass:MPMediaItemArtwork.class] ? [artworkValue imageWithSize:CGSizeMake(128, 128)] : nil;
    BOOL playing = MPMusicPlayerController.systemMusicPlayer.playbackState == MPMusicPlaybackStatePlaying;
    NSMutableDictionary *snapshot = [@{@"id": @"music", @"title": title, @"subtitle": artist,
        @"symbol": playing ? @"waveform" : @"music.note", @"kind": @"music", @"playing": @(playing)} mutableCopy];
    if (artwork) snapshot[@"artwork"] = artwork;
    return snapshot;
}

- (NSDictionary *)batterySnapshot {
    NIConfigurationManager *configuration = NIConfigurationManager.sharedManager;
    BOOL showBattery = [configuration boolForKey:@"BatteryEnabled"];
    BOOL showWarning = [configuration boolForKey:@"BatteryWarningEnabled"] && self.lowBatteryNoticeExpiry > NSDate.date.timeIntervalSince1970;
    if (!showBattery && !showWarning) return nil;
    UIDevice *device = UIDevice.currentDevice;
    float level = device.batteryLevel;
    if (level < 0) return nil;
    NSInteger percent = (NSInteger)lroundf(level * 100.0f);
    BOOL charging = device.batteryState == UIDeviceBatteryStateCharging || device.batteryState == UIDeviceBatteryStateFull;
    BOOL lowNotice = self.lowBatteryNoticeExpiry > NSDate.date.timeIntervalSince1970;
    return @{@"id": lowNotice ? @"lowBattery" : @"battery",
        @"title": [NSString stringWithFormat:@"%ld%%", (long)percent],
        @"subtitle": lowNotice ? @"Battery low" : (charging ? @"Charging" : @"Battery"),
        @"symbol": charging ? @"battery.100percent.bolt" : (percent <= 20 ? @"battery.25percent" : @"battery.100percent"),
        @"kind": lowNotice ? @"warning" : @"battery"};
}

- (NSDictionary *)volumeSnapshot {
    if (![NIConfigurationManager.sharedManager boolForKey:@"VolumeEnabled"]) return nil;
    float volume = AVAudioSession.sharedInstance.outputVolume;
    NSString *symbol = volume <= 0.01f ? @"speaker.slash.fill" : @"speaker.wave.2.fill";
    return @{@"id": @"volume", @"title": [NSString stringWithFormat:@"%ld%%", (long)lroundf(volume * 100)],
        @"subtitle": @"Volume", @"symbol": symbol, @"kind": @"volume"};
}

- (NSDictionary *)networkSnapshot {
    if (![NIConfigurationManager.sharedManager boolForKey:@"NetworkEnabled"] || !self.reachability) return nil;
    SCNetworkReachabilityFlags flags = 0;
    if (!SCNetworkReachabilityGetFlags(self.reachability, &flags) || !(flags & kSCNetworkReachabilityFlagsReachable)) return nil;
    BOOL cellular = (flags & kSCNetworkReachabilityFlagsIsWWAN) != 0;
    return @{@"id": @"network", @"title": cellular ? @"Cellular" : @"Online", @"subtitle": @"Network",
        @"symbol": cellular ? @"antenna.radiowaves.left.and.right" : @"wifi", @"kind": @"network"};
}

- (NSDictionary *)audioRouteSnapshot {
    if (![NIConfigurationManager.sharedManager boolForKey:@"AudioRouteEnabled"]) return nil;
    AVAudioSessionPortDescription *port = AVAudioSession.sharedInstance.currentRoute.outputs.firstObject;
    if (!port) return nil;
    BOOL headset = [@[AVAudioSessionPortBluetoothA2DP, AVAudioSessionPortBluetoothHFP,
        AVAudioSessionPortBluetoothLE, AVAudioSessionPortHeadphones] containsObject:port.portType];
    if (!headset) return nil;
    return @{@"id": @"audioRoute", @"title": port.portName ?: @"Audio device", @"subtitle": @"Connected",
        @"symbol": @"headphones", @"kind": @"audioRoute"};
}

- (NSDictionary *)timerSnapshot {
    NIConfigurationManager *configuration = NIConfigurationManager.sharedManager;
    if (![configuration boolForKey:@"TimerEnabled"]) return nil;
    NITimerLogicState state = [self currentTimerState];
    NSTimeInterval now = NSDate.date.timeIntervalSince1970;
    if (NITimerLogicIsExpired(state, now)) return nil;
    NSTimeInterval remaining = NITimerLogicRemaining(state, now);
    if (remaining <= 0) return nil;
    NSInteger seconds = (NSInteger)MAX(0, ceil(remaining));
    NSString *remainingLabel = [NSString stringWithFormat:@"%ld:%02ld", (long)(seconds / 60), (long)(seconds % 60)];
    BOOL paused = state.endTimestamp <= 0;
    return @{@"id": @"timer", @"title": remainingLabel, @"subtitle": paused ? @"Timer paused" : @"Timer",
        @"symbol": @"timer", @"kind": @"timer", @"paused": @(paused)};
}

- (NSDictionary *)widgetSnapshot {
    NIConfigurationManager *configuration = NIConfigurationManager.sharedManager;
    NSString *text = [configuration objectForKey:@"WidgetText"];
    if (![configuration boolForKey:@"WidgetEnabled"] || text.length == 0) return nil;
    return @{@"id": @"widget", @"title": text, @"subtitle": @"", @"symbol": @"text.alignleft", @"kind": @"widget"};
}

- (NSArray<NSDictionary<NSString *, id> *> *)snapshots {
    NSMutableArray *items = [NSMutableArray array];
    NSDictionary *warning = [self batterySnapshot];
    if ([warning[@"kind"] isEqual:@"warning"]) [items addObject:warning];
    NSDictionary *timer = [self timerSnapshot];
    if (timer) [items addObject:timer];
    NSDictionary *music = [self musicSnapshot];
    if (music) [items addObject:music];
    NSDictionary *audio = [self audioRouteSnapshot];
    if (audio) [items addObject:audio];
    NSDictionary *volume = [self volumeSnapshot];
    if (volume) [items addObject:volume];
    NSDictionary *network = [self networkSnapshot];
    if (network) [items addObject:network];
    NSDictionary *widget = [self widgetSnapshot];
    if (widget) [items addObject:widget];
    if (warning && ![warning[@"kind"] isEqual:@"warning"]) [items addObject:warning];
    return items;
}

- (void)refreshAndNotify {
    self.snapshots = [self snapshots];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"NIModuleProviderDidChange" object:self];
}

- (void)consumeTimerCommand {
    NIConfigurationManager *configuration = NIConfigurationManager.sharedManager;
    NSInteger command = [[configuration objectForKey:@"TimerCommand"] integerValue];
    if (command == 1) [self startTimer];
    else if (command == 2) [self pauseTimer];
    else if (command == 3) [self resumeTimer];
    else if (command == 4) [self cancelTimer];
    if (command != 0) [configuration setObject:@0 forConfigurationKey:@"TimerCommand"];
}

- (void)handleConfigurationChanges {
    [self updateObserversForConfiguration];
    [self consumeTimerCommand];
    NIConfigurationManager *configuration = NIConfigurationManager.sharedManager;
    NITimerLogicState state = [self currentTimerState];
    BOOL timerEnabled = [configuration boolForKey:@"TimerEnabled"];
    if (!timerEnabled) {
        if (state.endTimestamp > 0 || state.pausedRemaining > 0 || self.timerTicker) [self finishTimer];
        return;
    }
    if (timerEnabled && NITimerLogicIsExpired(state, NSDate.date.timeIntervalSince1970)) {
        [self finishTimer];
        return;
    }
    BOOL shouldTick = timerEnabled && state.endTimestamp > NSDate.date.timeIntervalSince1970;
    if (shouldTick && !self.timerTicker) [self startTicker];
    else if (!shouldTick && self.timerTicker) {
        [self.timerTicker invalidate];
        self.timerTicker = nil;
    }
}

- (void)updateObserversForConfiguration {
    NIConfigurationManager *configuration = NIConfigurationManager.sharedManager;
    NSNotificationCenter *center = NSNotificationCenter.defaultCenter;
    BOOL wantsBattery = [configuration boolForKey:@"BatteryEnabled"] || [configuration boolForKey:@"BatteryWarningEnabled"];
    if (wantsBattery != self.monitoringBattery) {
        if (wantsBattery) {
            UIDevice.currentDevice.batteryMonitoringEnabled = YES;
            [center addObserver:self selector:@selector(batteryStateChanged:) name:UIDeviceBatteryLevelDidChangeNotification object:UIDevice.currentDevice];
            [center addObserver:self selector:@selector(batteryStateChanged:) name:UIDeviceBatteryStateDidChangeNotification object:UIDevice.currentDevice];
            [self updateBatteryTransition];
        } else {
            [center removeObserver:self name:UIDeviceBatteryLevelDidChangeNotification object:UIDevice.currentDevice];
            [center removeObserver:self name:UIDeviceBatteryStateDidChangeNotification object:UIDevice.currentDevice];
            UIDevice.currentDevice.batteryMonitoringEnabled = NO;
        }
        self.monitoringBattery = wantsBattery;
    }
    BOOL wantsMusic = [configuration boolForKey:@"MusicEnabled"];
    if (wantsMusic != self.monitoringMusic) {
        if (wantsMusic) {
            [center addObserver:self selector:@selector(systemStateChanged:) name:MPMusicPlayerControllerNowPlayingItemDidChangeNotification object:nil];
            [center addObserver:self selector:@selector(systemStateChanged:) name:MPMusicPlayerControllerPlaybackStateDidChangeNotification object:nil];
            [MPMusicPlayerController.systemMusicPlayer beginGeneratingPlaybackNotifications];
        } else {
            [center removeObserver:self name:MPMusicPlayerControllerNowPlayingItemDidChangeNotification object:nil];
            [center removeObserver:self name:MPMusicPlayerControllerPlaybackStateDidChangeNotification object:nil];
            [MPMusicPlayerController.systemMusicPlayer endGeneratingPlaybackNotifications];
        }
        self.monitoringMusic = wantsMusic;
    }
    BOOL wantsRoute = [configuration boolForKey:@"AudioRouteEnabled"];
    if (wantsRoute != self.monitoringAudioRoute) {
        if (wantsRoute) [center addObserver:self selector:@selector(systemStateChanged:) name:AVAudioSessionRouteChangeNotification object:AVAudioSession.sharedInstance];
        else [center removeObserver:self name:AVAudioSessionRouteChangeNotification object:AVAudioSession.sharedInstance];
        self.monitoringAudioRoute = wantsRoute;
    }
    BOOL wantsVolume = [configuration boolForKey:@"VolumeEnabled"];
    if (wantsVolume != self.monitoringVolume) {
        if (wantsVolume) {
            [AVAudioSession.sharedInstance addObserver:self forKeyPath:@"outputVolume"
                options:0 context:NIAudioVolumeContext];
        } else {
            [AVAudioSession.sharedInstance removeObserver:self forKeyPath:@"outputVolume"
                context:NIAudioVolumeContext];
        }
        self.monitoringVolume = wantsVolume;
    }
    BOOL wantsNetwork = [configuration boolForKey:@"NetworkEnabled"];
    if (wantsNetwork && !self.reachability) {
        struct sockaddr_in address = { .sin_len = sizeof(struct sockaddr_in), .sin_family = AF_INET };
        self.reachability = SCNetworkReachabilityCreateWithAddress(kCFAllocatorDefault, (const struct sockaddr *)&address);
        if (self.reachability) {
            SCNetworkReachabilityContext context = {0, (__bridge void *)self, NULL, NULL, NULL};
            if (SCNetworkReachabilitySetCallback(self.reachability, NIReachabilityChanged, &context) &&
                SCNetworkReachabilityScheduleWithRunLoop(self.reachability, CFRunLoopGetMain(), kCFRunLoopCommonModes)) {
                self.monitoringNetwork = YES;
            } else {
                CFRelease(self.reachability);
                self.reachability = NULL;
            }
        }
    } else if (!wantsNetwork && self.reachability) {
        SCNetworkReachabilityUnscheduleFromRunLoop(self.reachability, CFRunLoopGetMain(), kCFRunLoopCommonModes);
        CFRelease(self.reachability);
        self.reachability = NULL;
        self.monitoringNetwork = NO;
    }
}

- (void)startTimer {
    NIConfigurationManager *configuration = NIConfigurationManager.sharedManager;
    if (![configuration boolForKey:@"TimerEnabled"]) return;
    NSTimeInterval duration = [configuration floatForKey:@"TimerDurationMinutes"] * 60;
    NITimerLogicState state = [self currentTimerState];
    NITimerLogicStart(&state, duration, NSDate.date.timeIntervalSince1970);
    [self storeTimerState:state];
    [self startTicker];
    [self refreshAndNotify];
}

- (void)pauseTimer {
    NITimerLogicState state = [self currentTimerState];
    if (NITimerLogicIsExpired(state, NSDate.date.timeIntervalSince1970)) {
        [self finishTimer];
        return;
    }
    if (state.endTimestamp <= 0) return;
    NITimerLogicPause(&state, NSDate.date.timeIntervalSince1970);
    [self storeTimerState:state];
    [self.timerTicker invalidate];
    self.timerTicker = nil;
    [self refreshAndNotify];
}

- (void)resumeTimer {
    NITimerLogicState state = [self currentTimerState];
    NITimerLogicResume(&state, NSDate.date.timeIntervalSince1970);
    if (state.endTimestamp <= 0) return;
    [self storeTimerState:state];
    [self startTicker];
    [self refreshAndNotify];
}

- (void)toggleTimer {
    NITimerLogicState state = [self currentTimerState];
    if (NITimerLogicIsExpired(state, NSDate.date.timeIntervalSince1970)) [self finishTimer];
    else if (state.endTimestamp > 0) [self pauseTimer];
    else [self resumeTimer];
}

- (void)cancelTimer {
    [self finishTimer];
}

- (NITimerLogicState)currentTimerState {
    NIConfigurationManager *configuration = NIConfigurationManager.sharedManager;
    return (NITimerLogicState){
        .endTimestamp = [configuration floatForKey:@"TimerEndTimestamp"],
        .pausedRemaining = [configuration floatForKey:@"TimerRemaining"]
    };
}

- (void)storeTimerState:(NITimerLogicState)state {
    NIConfigurationManager *configuration = NIConfigurationManager.sharedManager;
    [configuration setObject:@(state.endTimestamp) forConfigurationKey:@"TimerEndTimestamp"];
    [configuration setObject:@(state.pausedRemaining) forConfigurationKey:@"TimerRemaining"];
}

- (void)finishTimer {
    [self.timerTicker invalidate];
    self.timerTicker = nil;
    NITimerLogicState state = {0};
    [self storeTimerState:state];
    [self refreshAndNotify];
}

- (void)startTicker {
    if (self.timerTicker) return;
    __weak typeof(self) weakSelf = self;
    self.timerTicker = [NSTimer scheduledTimerWithTimeInterval:1.0 repeats:YES block:^(NSTimer *timer) {
        NIModuleProvider *strongSelf = weakSelf;
        if (!strongSelf || strongSelf.timerTicker != timer) return;
        [strongSelf timerDidTick:timer];
    }];
}

- (void)timerDidTick:(NSTimer *)timer {
    if (timer != self.timerTicker) return;
    NIConfigurationManager *configuration = NIConfigurationManager.sharedManager;
    if (![configuration boolForKey:@"TimerEnabled"]) {
        [timer invalidate];
        self.timerTicker = nil;
        return;
    }
    if (NITimerLogicIsExpired([self currentTimerState], NSDate.date.timeIntervalSince1970)) {
        [self finishTimer];
        return;
    }
    [self refreshAndNotify];
}

- (void)toggleMusic {
    MPMusicPlayerController *player = MPMusicPlayerController.systemMusicPlayer;
    if (player.playbackState == MPMusicPlaybackStatePlaying) [player pause];
    else [player play];
}
- (void)nextTrack { [MPMusicPlayerController.systemMusicPlayer skipToNextItem]; }
- (void)previousTrack { [MPMusicPlayerController.systemMusicPlayer skipToPreviousItem]; }

@end