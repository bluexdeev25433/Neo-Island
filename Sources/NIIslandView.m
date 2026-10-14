#import "NIIslandView.h"
#import "NIConfigurationManager.h"
#import "NIIslandStateManager.h"
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
@property (nonatomic, strong) NIIslandStateManager *stateManager;
@property (nonatomic, strong) NIIslandPassThroughWindow *window;
@property (nonatomic, strong) UIView *pill;
@property (nonatomic, strong) UIVisualEffectView *materialView;
@property (nonatomic, strong) UIImageView *artworkView;
@property (nonatomic, strong) UIImageView *symbolView;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *subtitleLabel;
@property (nonatomic, strong) UIButton *previousButton;
@property (nonatomic, strong) UIButton *playPauseButton;
@property (nonatomic, strong) UIButton *nextButton;
@property (nonatomic) NSUInteger expansionGeneration;
@property (nonatomic) BOOL hasRenderedMode;
- (void)renderCurrentSnapshotAnimated:(BOOL)animated;
@end

@implementation NIIslandView

- (instancetype)initWithModuleProvider:(NIModuleProvider *)moduleProvider {
    self = [super init];
    if (self) {
        _moduleProvider = moduleProvider;
        _stateManager = [NIIslandStateManager new];
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
    self.pill.backgroundColor = UIColor.clearColor;
    self.pill.layer.masksToBounds = YES;
    self.pill.layer.borderWidth = 0.5;
    self.pill.layer.borderColor = [UIColor colorWithWhite:1 alpha:0.16].CGColor;
    self.pill.isAccessibilityElement = YES;
    self.pill.accessibilityTraits = UIAccessibilityTraitButton;
    [self.window.rootViewController.view addSubview:self.pill];
    self.window.pillView = self.pill;

    UIBlurEffectStyle materialStyle = UIAccessibilityIsReduceTransparencyEnabled()
        ? UIBlurEffectStyleDark : UIBlurEffectStyleSystemChromeMaterialDark;
    self.materialView = [[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:materialStyle]];
    self.materialView.userInteractionEnabled = NO;
    self.materialView.frame = self.pill.bounds;
    self.materialView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.pill addSubview:self.materialView];
    [self.pill sendSubviewToBack:self.materialView];

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
    NIIslandMode previousMode = self.stateManager.mode;
    BOOL hadRenderedMode = self.hasRenderedMode;
    [self.stateManager updateSnapshots:snapshots idleVisible:[NIConfigurationManager.sharedManager boolForKey:@"AlwaysShowIdle"]];
    [self renderCurrentSnapshotAnimated:!hadRenderedMode || previousMode != self.stateManager.mode];
}

- (NSDictionary *)currentSnapshot {
    return self.stateManager.currentSnapshot;
}

- (void)renderCurrentSnapshot {
    [self renderCurrentSnapshotAnimated:NO];
}

- (void)renderCurrentSnapshotAnimated:(BOOL)animated {
    NSDictionary *snapshot = [self currentSnapshot];
    NIIslandMode mode = self.stateManager.mode;
    self.pill.hidden = !self.stateManager.shouldShowContent;
    if (self.pill.hidden) return;

    NSString *title = snapshot[@"title"] ?: @"";
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
    BOOL expanded = self.stateManager.isExpanded;
    self.previousButton.hidden = !expanded || !isMusic;
    self.nextButton.hidden = !expanded || !isMusic;
    self.playPauseButton.hidden = !expanded || (!isMusic && !isTimer);
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
    [actions addObject:[[UIAccessibilityCustomAction alloc] initWithName:expanded ? @"Collapse" : @"Expand"
        target:self selector:@selector(performAccessibilityAction:)]];
    if (self.stateManager.snapshots.count > 1) {
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
    [self layoutPillAnimated:animated];
    self.hasRenderedMode = YES;
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
    NIIslandMode mode = self.stateManager.mode;
    CGFloat compactWidth = MIN(maximumWidth, [configuration floatForKey:@"PillWidth"]);
    CGFloat compactHeight = [configuration floatForKey:@"PillHeight"];
    CGFloat width = compactWidth;
    CGFloat height = compactHeight;
    if (mode == NIIslandModeExpanded) {
        width = MIN(maximumWidth, 340);
        height = MAX(108, compactHeight + 56);
    } else if (mode == NIIslandModeMinimal) {
        width = MIN(maximumWidth, MAX(48, compactHeight));
    } else if (mode == NIIslandModeNotification) {
        width = MIN(maximumWidth, 340);
        height = MAX(76, compactHeight + 28);
    }
    CGFloat scale = [configuration floatForKey:@"ContentScale"];
    CGFloat x = (CGRectGetWidth(bounds) - width) / 2 + [configuration floatForKey:@"OffsetX"];
    x = MIN(CGRectGetWidth(bounds) - safe.right - width - 10, MAX(safe.left + 10, x));
    CGFloat y = MAX(safe.top + 4, safe.top + [configuration floatForKey:@"OffsetY"]);
    y = MIN(CGRectGetHeight(bounds) - safe.bottom - height - 10, y);
    CGRect frame = CGRectMake(x, y, width, height);
    void (^layout)(void) = ^{
        self.pill.frame = frame;
        self.pill.layer.cornerRadius = height / 2;
        BOOL expanded = mode == NIIslandModeExpanded;
        BOOL minimal = mode == NIIslandModeMinimal;
        CGFloat artSide = expanded ? 42 : MIN(height - 8, 30);
        self.artworkView.frame = CGRectMake(10, (height - artSide) / 2, artSide, artSide);
        self.artworkView.layer.cornerRadius = artSide * 0.22;
        self.symbolView.frame = self.artworkView.frame;
        CGFloat rightControls = expanded && !self.previousButton.hidden ? 105 : 0;
        CGFloat textX = 18 + artSide;
        CGFloat textWidth = MAX(40, width - textX - 18 - rightControls);
        self.titleLabel.hidden = minimal;
        self.symbolView.hidden = minimal ? NO : self.artworkView.image != nil;
        self.titleLabel.frame = CGRectMake(textX, expanded ? 20 : 0, textWidth, expanded ? 22 : height);
        self.subtitleLabel.frame = CGRectMake(textX, 44, textWidth, 16);
        self.subtitleLabel.hidden = !expanded && mode != NIIslandModeNotification || self.subtitleLabel.text.length == 0;
        self.titleLabel.font = [UIFont systemFontOfSize:(expanded ? 14 : 13) * scale weight:UIFontWeightSemibold];
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
    [self.stateManager toggleExpanded];
    [self renderCurrentSnapshotAnimated:YES];
    if (self.stateManager.isExpanded) [self scheduleCollapse];
    if ([NIConfigurationManager.sharedManager boolForKey:@"HapticsEnabled"]) {
        [[[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight] impactOccurred];
    }
}

- (void)handleLongPress:(UILongPressGestureRecognizer *)gesture {
    if (gesture.state != UIGestureRecognizerStateBegan) return;
    if (!self.stateManager.isExpanded) {
        [self.stateManager toggleExpanded];
        [self renderCurrentSnapshotAnimated:YES];
        [self scheduleCollapse];
    }
}

- (void)handleSwipe:(UIPanGestureRecognizer *)gesture {
    if (gesture.state != UIGestureRecognizerStateEnded || self.stateManager.snapshots.count < 2) return;
    CGFloat translation = [gesture translationInView:self.pill].x;
    if (fabs(translation) < 28) return;
    [self handleSwipeDirection:translation < 0 ? 1 : -1];
}

- (void)handleSwipeDirection:(NSInteger)direction {
    [self.stateManager moveSelection:direction];
    [self renderCurrentSnapshotAnimated:YES];
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
        if (!weakSelf || !weakSelf.stateManager.isExpanded || weakSelf.expansionGeneration != generation) return;
        [weakSelf.stateManager collapse];
        [weakSelf renderCurrentSnapshotAnimated:YES];
    });
}

- (void)togglePrimaryAction {
    NSDictionary *snapshot = [self currentSnapshot];
    if ([snapshot[@"kind"] isEqual:@"timer"]) [self.moduleProvider toggleTimer];
    else if ([snapshot[@"kind"] isEqual:@"music"]) [self.moduleProvider toggleMusic];
}

- (void)nextTrack { [self.moduleProvider nextTrack]; }
- (void)previousTrack { [self.moduleProvider previousTrack]; }
- (void)layoutForDeviceChange {
    self.window.frame = UIScreen.mainScreen.bounds;
    [self.window.rootViewController.view setNeedsLayout];
    [self.window.rootViewController.view layoutIfNeeded];
    [self layoutPillAnimated:NO];
}

- (void)show {
    if (!self.window) [self buildWindow];
    if (!self.window) return;
    BOOL locked = !UIApplication.sharedApplication.protectedDataAvailable;
    if (locked && ![NIConfigurationManager.sharedManager boolForKey:@"LockScreenEnabled"]) {
        self.window.hidden = YES;
        return;
    }
    BOOL hasData = self.stateManager.snapshots.count > 0;
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