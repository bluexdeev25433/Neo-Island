#include "NITimerLogic.h"

#include <assert.h>

int main(void) {
    NITimerLogicState state = {0};
    NITimerLogicStart(&state, 30.0, 100.0);
    assert(state.endTimestamp == 130.0);
    assert(NITimerLogicRemaining(state, 100.0) == 30.0);
    assert(NITimerLogicRemaining(state, 129.5) == 0.5);
    assert(!NITimerLogicIsExpired(state, 129.999));
    assert(NITimerLogicIsExpired(state, 130.0));

    NITimerLogicPause(&state, 112.0);
    assert(state.endTimestamp == 0.0);
    assert(state.pausedRemaining == 18.0);
    assert(NITimerLogicRemaining(state, 500.0) == 18.0);

    NITimerLogicResume(&state, 200.0);
    assert(state.endTimestamp == 218.0);
    assert(state.pausedRemaining == 0.0);
    assert(!NITimerLogicIsExpired(state, 217.999));
    assert(NITimerLogicIsExpired(state, 218.0));

    NITimerLogicCancel(&state);
    assert(state.endTimestamp == 0.0);
    assert(state.pausedRemaining == 0.0);
    assert(!NITimerLogicIsExpired(state, 1000.0));
    assert(NITimerLogicRemaining(state, 1000.0) == 0.0);
    return 0;
}