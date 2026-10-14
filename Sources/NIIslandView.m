#import "NIIslandView.h"
#import "NIConfigurationManager.h"
#import "NIModuleProvider.h"
#import "NIIconRenderer.h"
#import <MediaPlayer/MediaPlayer.h>

@interface NIIslandPassThroughWindow : UIWindow
@property (nonatomic, weak) UIView *pillView;
@end

@implementation NIIslandPassThroughWindow
- (BOOL)pointInside:(CGPoint)point withEvent:(UIEvent *)event {
    (void)event;
    if (!self.pillView || self.hidden) return NO;
    CGPoint localPoint = [self convertPoint:point toView:self.pillView];
    return [self.pillView pointInside:localPoint withEvent:nil];
}
@end

@interface NIIslandView ()
@property (nonatomic, strong) NIModuleProvider *moduleProvider;
@property (nonatomic, strong) NIIslandPassThroughWindow *window;
@property (nonatomic, strong) UIView *pill;
@property (nonatomic, strong) UIImageView *artworkView;
@property (nonatomic, strong) UIImageView *symbolView;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *subtitleLabel;
@property (nonatomic, strong) UIButton *previousButton;
@property (nonatomic, strong) UIButton *playPauseButton;
@property (nonatomic, strong) UIButton *nextButton;
@property (nonatomic, copy) NSArray<NSDictionary<NSString *, id> *> *snapshots;
@property (nonatomic) NSUInteger currentIndex;
@property (nonatomic) NSUInteger expansionGeneration;
@property (nonatomic) BOOL expanded;
@end

@implementation NIIslandView

- (instancetype)initWithModuleProvider:(NIModuleProvider *)moduleProvider {
    self = [super init];
    if (self) {
        _moduleProvider = moduleProvider;
        _snapshots = @[];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(layoutForDeviceChange)
            name:UIDeviceOrientationDidChangeNotification object:nil];
    }
    return self;
}

- (void)dealloc { [[NSNotificationCenter defaultCenter] removeObserver:self]; }

- (UIButton *)buttonWithSymbol:(NSString *)symbol action:(SEL)action label:(NSString *)label {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    UIImage *image = [NIIconRenderer imageForSymbol:symbol pointSize:18];
    if (image) [button setImage:image forState:UIControlStateNormal];
    button.tintColor = UIColor.whiteColor;
    button.accessibilityLabel = label;
    [button addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    return button;
}

- (void)buildWindow {
    if (self.window) return;
    CGRect screenBounds = UIScreen.mainScreen.bounds;
    self.window = [[NIIslandPassThroughWindow alloc] initWithFrame:screenBounds];
    self.window.windowLevel = UIWindowLevelStatusBar + 1;
    self.window.backgroundColor = UIColor.clearColor;
    self.window.rootViewController = [UIViewController new];
    self.window.rootViewController.view.backgroundColor = UIColor.clearColor;
    self.window.hidden = NO;

    self.pill = [UIView new];
    self.pill.backgroundColor = UIColor.blackColor;
    self.pill.layer.masksToBounds = YES;
    self.pill.isAccessibilityElement = YES;
    self.pill.accessibilityTraits = UIAccessibilityTraitButton;
    [self.window.rootViewController.view addSubview:self.pill];
    self.window.pillView = self.pill;

    self.artworkView = [UIImageView new];
    self.artworkView.contentMode = UIViewContentModeScaleAspectFill;
    self.artworkView.clipsToBounds = YES;
    [self.pill addSubview:self.artworkView];
    self.symbolView = [UIImageView new];
    self.symbolView.contentMode = UIViewContentModeScaleAspectFit;
    self.symbolView.tintColor = UIColor.whiteColor;
    [self.pill addSubview:self.symbolView];
    self.titleLabel = [UILabel new];
    self.titleLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightSemibold];
    self.titleLabel.adjustsFontForContentSizeCategory = YES;
    self.titleLabel.textColor = UIColor.whiteColor;
    self.titleLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    [self.pill addSubview:self.titleLabel];
    self.subtitleLabel = [UILabel new];
    self.subtitleLabel.font = [UIFont systemFontOfSize:10 weight:UIFontWeightRegular];
    self.subtitleLabel.adjustsFontForContentSizeCategory = YES;
    self.subtitleLabel.textColor = [UIColor colorWithWhite:0.72 alpha:1];
    self.subtitleLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    [self.pill addSubview:self.subtitleLabel];
    self.previousButton = [self buttonWithSymbol:@"backward.end.fill" action:@selector(previousTrack) label:@"Previous track"];
    self.playPauseButton = [self buttonWithSymbol:@"playpause.fill" action:@selector(togglePrimaryAction) label:@"Play or pause"];
    self.nextButton = [self buttonWithSymbol:@"forward.end.fill" action:@selector(nextTrack) label:@"Next track"];
    [self.pill addSubview:self.previousButton];
    [self.pill addSubview:self.playPauseButton];
    [self.pill addSubview:self.nextButton];

    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(toggleExpanded)];
    UILongPressGestureRecognizer *longPress = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(handleLongPress:)];
    longPress.minimumPressDuration = 0.5;
    [tap requireGestureRecognizerToFail:longPress];
    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handleSwipe:)];
    pan.maximumNumberOfTouches = 1;
    tap.delegate = self;
    longPress.delegate = self;
    pan.delegate = self;
    [self.pill addGestureRecognizer:tap];
    [self.pill addGestureRecognizer:longPress];
    [self.pill addGestureRecognizer:pan];
    [self layoutPillAnimated:NO];
    [self renderCurrentSnapshot];
}

- (void)updateWithSnapshots:(NSArray<NSDictionary<NSString *, id> *> *)snapshots {
    self.snapshots = snapshots ?: @[];
    if (self.snapshots.count > 0 && [self.snapshots.firstObject[@"kind"] isEqual:@"warning"]) self.currentIndex = 0;
    else if (self.snapshots.count > 0) self.currentIndex %= self.snapshots.count;
    else self.currentIndex = 0;
    [self renderCurrentSnapshot];
}

- (NSDictionary *)currentSnapshot {
    return self.snapshots.count > 0 ? self.snapshots[self.currentIndex] : nil;
}

- (void)renderCurrentSnapshot {
    NSDictionary *snapshot = [self currentSnapshot];
    BOOL idle = !snapshot && [NIConfigurationManager.sharedManager boolForKey:@"AlwaysShowIdle"];
    self.pill.hidden = !snapshot && !idle;
    if (!snapshot && !idle) return;

    NSString *title = snapshot[@"title"] ?: @"Dynamic Island";
    NSString *subtitle = snapshot[@"subtitle"] ?: @"";
    self.titleLabel.text = title;
    self.subtitleLabel.text = subtitle;
    self.pill.accessibilityLabel = subtitle.length ? [NSString stringWithFormat:@"%@, %@", title, subtitle] : title;
    self.pill.accessibilityHint = @"Activate to expand or collapse. Swipe actions are available in the rotor.";
    self.artworkView.image = [snapshot[@"artwork"] isKindOfClass:UIImage.class] ? snapshot[@"artwork"] : nil;
    NSString *symbol = snapshot[@"symbol"] ?: @"circle.fill";
    UIImage *image = [NIIconRenderer imageForSymbol:symbol pointSize:16];
    self.symbolView.image = image;
    self.symbolView.hidden = self.artworkView.image != nil;
    BOOL isMusic = [snapshot[@"kind"] isEqual:@"music"];
    BOOL isTimer = [snapshot[@"kind"] isEqual:@"timer"];
    self.previousButton.hidden = !self.expanded || !isMusic;
    self.nextButton.hidden = !self.expanded || !isMusic;
    self.playPauseButton.hidden = !self.expanded || (!isMusic && !isTimer);
    if (isMusic) {
        BOOL playing = [snapshot[@"playing"] boolValue];
        UIImage *controlImage = [NIIconRenderer imageForSymbol:playing ? @"pause.fill" : @"play.fill" pointSize:16];
        [self.playPauseButton setImage:controlImage forState:UIControlStateNormal];
        self.playPauseButton.accessibilityLabel = playing ? @"Pause" : @"Play";
    } else if (isTimer) {
        BOOL paused = [snapshot[@"paused"] boolValue];
        [self.playPauseButton setImage:[NIIconRenderer imageForSymbol:paused ? @"play.fill" : @"pause.fill" pointSize:16] forState:UIControlStateNormal];
        self.playPauseButton.accessibilityLabel = paused ? @"Resume timer" : @"Pause timer";
    }
    NSMutableArray<UIAccessibilityCustomAction *> *actions = [NSMutableArray array];
    [actions addObject:[[UIAccessibilityCustomAction alloc] initWithName:self.expanded ? @"Collapse" : @"Expand"
        target:self selector:@selector(performAccessibilityAction:)]];
    if (self.snapshots.count > 1) {
        [actions addObject:[[UIAccessibilityCustomAction alloc] initWithName:@"Next module" target:self selector:@selector(performAccessibilityAction:)]];
        [actions addObject:[[UIAccessibilityCustomAction alloc] initWithName:@"Previous module" target:self selector:@selector(performAccessibilityAction:)]];
    }
    if (isMusic) {
        [actions addObject:[[UIAccessibilityCustomAction alloc] initWithName:@"Previous track" target:self selector:@selector(performAccessibilityAction:)]];
        [actions addObject:[[UIAccessibilityCustomAction alloc] initWithName:[snapshot[@"playing"] boolValue] ? @"Pause" : @"Play"
            target:self selector:@selector(performAccessibilityAction:)]];
        [actions addObject:[[UIAccessibilityCustomAction alloc] initWithName:@"Next track" target:self selector:@selector(performAccessibilityAction:)]];
    } else if (isTimer) {
        [actions addObject:[[UIAccessibilityCustomAction alloc] initWithName:[snapshot[@"paused"] boolValue] ? @"Resume timer" : @"Pause timer"
            target:self selector:@selector(performAccessibilityAction:)]];
    }
    self.pill.accessibilityCustomActions = actions;
    [self layoutPillAnimated:NO];
}

- (BOOL)performAccessibilityAction:(UIAccessibilityCustomAction *)action {
    NSString *name = action.name;
    if ([name isEqualToString:@"Expand"] || [name isEqualToString:@"Collapse"]) [self toggleExpanded];
    else if ([name isEqualToString:@"Next module"]) [self handleSwipeDirection:1];
    else if ([name isEqualToString:@"Previous module"]) [self handleSwipeDirection:-1];
    else if ([name isEqualToString:@"Previous track"]) [self previousTrack];
    else if ([name isEqualToString:@"Next track"]) [self nextTrack];
    else if ([name isEqualToString:@"Play"] || [name isEqualToString:@"Pause"] ||
        [name isEqualToString:@"Resume timer"] || [name isEqualToString:@"Pause timer"]) [self togglePrimaryAction];
    else return NO;
    return YES;
}

- (void)layoutPillAnimated:(BOOL)animated {
    if (!self.window || !self.pill) return;
    NIConfigurationManager *configuration = NIConfigurationManager.sharedManager;
    CGRect bounds = self.window.bounds;
    UIEdgeInsets safe = self.window.safeAreaInsets;
    CGFloat maximumWidth = CGRectGetWidth(bounds) - safe.left - safe.right - 20;
    CGFloat width = self.expanded ? MIN(maximumWidth, 330) : MIN(maximumWidth, [configuration floatForKey:@"PillWidth"]);
    CGFloat height = self.expanded ? MAX(100, [configuration floatForKey:@"PillHeight"] + 52) : [configuration floatForKey:@"PillHeight"];
    CGFloat scale = [configuration floatForKey:@"ContentScale"];
    CGFloat x = (CGRectGetWidth(bounds) - width) / 2 + [configuration floatForKey:@"OffsetX"];
    x = MIN(CGRectGetWidth(bounds) - safe.right - width - 10, MAX(safe.left + 10, x));
    CGFloat y = MAX(safe.top + 4, safe.top + [configuration floatForKey:@"OffsetY"]);
    y = MIN(CGRectGetHeight(bounds) - safe.bottom - height - 10, y);
    CGRect frame = CGRectMake(x, y, width, height);
    void (^layout)(void) = ^{
        self.pill.frame = frame;
        self.pill.layer.cornerRadius = height / 2;
        CGFloat artSide = self.expanded ? 42 : MIN(height - 8, 30);
        self.artworkView.frame = CGRectMake(10, (height - artSide) / 2, artSide, artSide);
        self.artworkView.layer.cornerRadius = artSide * 0.22;
        self.symbolView.frame = self.artworkView.frame;
        CGFloat rightControls = self.expanded && !self.previousButton.hidden ? 105 : 0;
        CGFloat textX = 18 + artSide;
        CGFloat textWidth = MAX(40, width - textX - 18 - rightControls);
        self.titleLabel.frame = CGRectMake(textX, self.expanded ? 20 : 0, textWidth, self.expanded ? 22 : height);
        self.subtitleLabel.frame = CGRectMake(textX, 44, textWidth, 16);
        self.subtitleLabel.hidden = !self.expanded || self.subtitleLabel.text.length == 0;
        self.titleLabel.font = [UIFont systemFontOfSize:(self.expanded ? 14 : 13) * scale weight:UIFontWeightSemibold];
        self.subtitleLabel.font = [UIFont systemFontOfSize:10 * scale weight:UIFontWeightRegular];
        self.previousButton.frame = CGRectMake(width - 96, height - 34, 24, 24);
        self.playPauseButton.frame = CGRectMake(width - 62, height - 34, 24, 24);
        self.nextButton.frame = CGRectMake(width - 28, height - 34, 24, 24);
    };
    if (!animated || UIAccessibilityIsReduceMotionEnabled()) {
        layout();
        return;
    }
    [UIView animateWithDuration:[configuration floatForKey:@"AnimationSpeed"] delay:0
        usingSpringWithDamping:[configuration floatForKey:@"AnimationBounce"] initialSpringVelocity:0.25
        options:UIViewAnimationOptionBeginFromCurrentState animations:layout completion:nil];
}

- (void)toggleExpanded {
    self.expanded = !self.expanded;
    [self layoutPillAnimated:YES];
    if (self.expanded) [self scheduleCollapse];
    if ([NIConfigurationManager.sharedManager boolForKey:@"HapticsEnabled"]) {
        [[[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight] impactOccurred];
    }
}

- (void)handleLongPress:(UILongPressGestureRecognizer *)gesture {
    if (gesture.state != UIGestureRecognizerStateBegan) return;
    if (!self.expanded) {
        self.expanded = YES;
        [self layoutPillAnimated:YES];
        [self scheduleCollapse];
    }
}

- (void)handleSwipe:(UIPanGestureRecognizer *)gesture {
    if (gesture.state != UIGestureRecognizerStateEnded || self.snapshots.count < 2) return;
    CGFloat translation = [gesture translationInView:self.pill].x;
    if (fabs(translation) < 28) return;
    [self handleSwipeDirection:translation < 0 ? 1 : -1];
}

- (void)handleSwipeDirection:(NSInteger)direction {
    if (self.snapshots.count < 2) return;
    self.currentIndex = (self.currentIndex + (direction > 0 ? 1 : self.snapshots.count - 1)) % self.snapshots.count;
    [self renderCurrentSnapshot];
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldReceiveTouch:(UITouch *)touch {
    (void)gestureRecognizer;
    UIView *view = touch.view;
    while (view && view != self.pill) {
        if ([view isKindOfClass:UIControl.class]) return NO;
        view = view.superview;
    }
    return YES;
}

- (void)scheduleCollapse {
    NSTimeInterval delay = [NIConfigurationManager.sharedManager floatForKey:@"AutoCollapseSeconds"];
    if (delay <= 0) return;
    NSUInteger generation = ++self.expansionGeneration;
    __weak typeof(self) weakSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (!weakSelf || !weakSelf.expanded || weakSelf.expansionGeneration != generation) return;
        weakSelf.expanded = NO;
        [weakSelf layoutPillAnimated:YES];
    });
}

- (void)togglePrimaryAction {
    NSDictionary *snapshot = [self currentSnapshot];
    if ([snapshot[@"kind"] isEqual:@"timer"]) [self.moduleProvider toggleTimer];
    else if ([snapshot[@"kind"] isEqual:@"music"]) [self.moduleProvider toggleMusic];
}

- (void)nextTrack { [self.moduleProvider nextTrack]; }
- (void)previousTrack { [self.moduleProvider previousTrack]; }
- (void)layoutForDeviceChange { [self layoutPillAnimated:NO]; }

- (void)show {
    if (!self.window) [self buildWindow];
    if (!self.window) return;
    BOOL locked = !UIApplication.sharedApplication.protectedDataAvailable;
    if (locked && ![NIConfigurationManager.sharedManager boolForKey:@"LockScreenEnabled"]) {
        self.window.hidden = YES;
        return;
    }
    BOOL hasData = self.snapshots.count > 0;
    BOOL idle = [NIConfigurationManager.sharedManager boolForKey:@"AlwaysShowIdle"];
    self.window.hidden = !hasData && !idle;
}

- (void)removeFromScreen {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    self.window.hidden = YES;
    self.window = nil;
    self.pill = nil;
}

@end