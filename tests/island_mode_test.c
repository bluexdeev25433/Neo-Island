#include "NIIslandMode.h"

#include <assert.h>

int main(void) {
    assert(NIIslandModeForContent(true, false, NIIslandContentDefault, false) == NIIslandModeCompact);
    assert(NIIslandModeForContent(true, false, NIIslandContentMusic, false) == NIIslandModeActivity);
    assert(NIIslandModeForContent(true, false, NIIslandContentTimer, false) == NIIslandModeActivity);
    assert(NIIslandModeForContent(true, false, NIIslandContentNotification, false) == NIIslandModeNotification);
    assert(NIIslandModeForContent(false, true, NIIslandContentDefault, false) == NIIslandModeMinimal);
    assert(NIIslandModeForContent(false, false, NIIslandContentDefault, false) == NIIslandModeCompact);
    assert(NIIslandModeForContent(true, false, NIIslandContentNotification, true) == NIIslandModeExpanded);
    assert(NIIslandModeForContent(false, true, NIIslandContentDefault, true) == NIIslandModeExpanded);
    return 0;
}