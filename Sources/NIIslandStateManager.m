#import "NIIslandStateManager.h"

@interface NIIslandStateManager ()
@property (nonatomic, copy, readwrite) NSArray<NSDictionary<NSString *, id> *> *snapshots;
@property (nonatomic, copy, nullable) NSString *selectedSnapshotIdentifier;
@property (nonatomic) BOOL idleVisible;
@property (nonatomic, readwrite, getter=isExpanded) BOOL expanded;
@end

@implementation NIIslandStateManager

- (instancetype)init {
    self = [super init];
    if (self) _snapshots = @[];
    return self;
}

- (void)updateSnapshots:(NSArray<NSDictionary<NSString *, id> *> *)snapshots idleVisible:(BOOL)idleVisible {
    NSMutableArray<NSDictionary<NSString *, id> *> *validSnapshots = [NSMutableArray array];
    NSMutableSet<NSString *> *identifiers = [NSMutableSet set];
    for (id value in snapshots) {
        if (![value isKindOfClass:NSDictionary.class]) continue;
        id identifier = value[@"id"];
        if (![identifier isKindOfClass:NSString.class] || [identifier length] == 0 || [identifiers containsObject:identifier]) continue;
        [identifiers addObject:identifier];
        [validSnapshots addObject:value];
    }
    self.snapshots = validSnapshots;
    self.idleVisible = idleVisible;
    if (![identifiers containsObject:self.selectedSnapshotIdentifier]) {
        self.selectedSnapshotIdentifier = [validSnapshots.firstObject[@"id"] isKindOfClass:NSString.class]
            ? validSnapshots.firstObject[@"id"] : nil;
    }
    if (!self.shouldShowContent) self.expanded = NO;
}

- (NSDictionary<NSString *, id> *)currentSnapshot {
    for (NSDictionary<NSString *, id> *snapshot in self.snapshots) {
        if ([snapshot[@"id"] isEqualToString:self.selectedSnapshotIdentifier]) return snapshot;
    }
    return nil;
}

- (BOOL)shouldShowContent {
    return self.currentSnapshot != nil || self.idleVisible;
}

- (NIIslandMode)mode {
    NSDictionary *snapshot = self.currentSnapshot;
    NSString *kind = [snapshot[@"kind"] isKindOfClass:NSString.class] ? snapshot[@"kind"] : @"";
    NIIslandContentKind contentKind = NIIslandContentDefault;
    if ([kind isEqualToString:@"music"]) contentKind = NIIslandContentMusic;
    else if ([kind isEqualToString:@"timer"]) contentKind = NIIslandContentTimer;
    else if ([kind isEqualToString:@"activity"]) contentKind = NIIslandContentActivity;
    else if ([kind isEqualToString:@"notification"]) contentKind = NIIslandContentNotification;
    else if ([kind isEqualToString:@"minimal"]) contentKind = NIIslandContentMinimal;
    return NIIslandModeForContent(snapshot != nil, self.idleVisible, contentKind, self.expanded);
}

- (void)toggleExpanded {
    if (self.shouldShowContent) self.expanded = !self.expanded;
}

- (void)collapse {
    self.expanded = NO;
}

- (void)moveSelection:(NSInteger)direction {
    if (self.snapshots.count < 2 || direction == 0) return;
    NSUInteger index = [self.snapshots indexOfObjectPassingTest:^BOOL(NSDictionary<NSString *,id> *snapshot, NSUInteger index, BOOL *stop) {
        (void)index;
        (void)stop;
        return [snapshot[@"id"] isEqualToString:self.selectedSnapshotIdentifier];
    }];
    if (index == NSNotFound) index = 0;
    NSUInteger count = self.snapshots.count;
    NSUInteger next = direction > 0 ? (index + 1) % count : (index + count - 1) % count;
    self.selectedSnapshotIdentifier = self.snapshots[next][@"id"];
}

@end