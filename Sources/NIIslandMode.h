#ifndef NI_ISLAND_MODE_H
#define NI_ISLAND_MODE_H

#include <stdbool.h>

typedef enum {
    NIIslandModeCompact = 0,
    NIIslandModeExpanded,
    NIIslandModeMinimal,
    NIIslandModeActivity,
    NIIslandModeNotification
} NIIslandMode;

typedef enum {
    NIIslandContentDefault = 0,
    NIIslandContentMusic,
    NIIslandContentTimer,
    NIIslandContentActivity,
    NIIslandContentNotification,
    NIIslandContentMinimal
} NIIslandContentKind;

static inline NIIslandMode NIIslandModeForContent(bool hasContent, bool idleVisible,
    NIIslandContentKind kind, bool expanded) {
    if (expanded && (hasContent || idleVisible)) return NIIslandModeExpanded;
    if (!hasContent) return idleVisible ? NIIslandModeMinimal : NIIslandModeCompact;
    if (kind == NIIslandContentNotification) return NIIslandModeNotification;
    if (kind == NIIslandContentMusic || kind == NIIslandContentTimer || kind == NIIslandContentActivity) {
        return NIIslandModeActivity;
    }
    if (kind == NIIslandContentMinimal) return NIIslandModeMinimal;
    return NIIslandModeCompact;
}

#endif