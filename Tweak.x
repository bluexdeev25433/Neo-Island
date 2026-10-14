#import <Foundation/Foundation.h>
#import "Sources/NIIslandManager.h"

%ctor {
    @autoreleasepool {
        dispatch_async(dispatch_get_main_queue(), ^{
            [[NIIslandManager sharedManager] start];
        });
    }
}