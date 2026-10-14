#ifndef NI_TIMER_LOGIC_H
#define NI_TIMER_LOGIC_H

#include <math.h>
#include <stdbool.h>

typedef struct {
    double endTimestamp;
    double pausedRemaining;
} NITimerLogicState;

static inline double NITimerLogicRemaining(NITimerLogicState state, double now) {
    double remaining = state.endTimestamp > 0 ? state.endTimestamp - now : state.pausedRemaining;
    return fmax(0.0, remaining);
}

static inline bool NITimerLogicIsExpired(NITimerLogicState state, double now) {
    return state.endTimestamp > 0 && now >= state.endTimestamp;
}

static inline void NITimerLogicStart(NITimerLogicState *state, double duration, double now) {
    state->endTimestamp = now + duration;
    state->pausedRemaining = 0;
}

static inline void NITimerLogicPause(NITimerLogicState *state, double now) {
    if (state->endTimestamp <= 0) return;
    state->pausedRemaining = NITimerLogicRemaining(*state, now);
    state->endTimestamp = 0;
}

static inline void NITimerLogicResume(NITimerLogicState *state, double now) {
    if (state->endTimestamp > 0 || state->pausedRemaining <= 0) return;
    state->endTimestamp = now + state->pausedRemaining;
    state->pausedRemaining = 0;
}

static inline void NITimerLogicCancel(NITimerLogicState *state) {
    state->endTimestamp = 0;
    state->pausedRemaining = 0;
}

#endif