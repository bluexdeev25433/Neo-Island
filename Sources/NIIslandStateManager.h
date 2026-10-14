#import <Foundation/Foundation.h>

#import "NIIslandMode.h"

NS_ASSUME_NONNULL_BEGIN

@interface NIIslandStateManager : NSObject
@property (nonatomic, copy, readonly) NSArray<NSDictionary<NSString *, id> *> *snapshots;
@property (nonatomic, copy, readonly, nullable) NSDictionary<NSString *, id> *currentSnapshot;
@property (nonatomic, readonly) NIIslandMode mode;
@property (nonatomic, readonly) BOOL shouldShowContent;
@property (nonatomic, readonly, getter=isExpanded) BOOL expanded;
- (void)updateSnapshots:(NSArray<NSDictionary<NSString *, id> *> *)snapshots idleVisible:(BOOL)idleVisible;
- (void)toggleExpanded;
- (void)collapse;
- (void)moveSelection:(NSInteger)direction;
@end

NS_ASSUME_NONNULL_END