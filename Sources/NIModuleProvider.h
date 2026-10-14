#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface NIModuleProvider : NSObject
@property (nonatomic, copy, readonly) NSArray<NSDictionary<NSString *, id> *> *snapshots;
- (void)startTimer;
- (void)pauseTimer;
- (void)resumeTimer;
- (void)cancelTimer;
- (void)toggleMusic;
- (void)nextTrack;
- (void)previousTrack;
- (void)handleConfigurationChanges;
- (void)toggleTimer;
@end

NS_ASSUME_NONNULL_END