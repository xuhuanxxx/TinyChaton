local addonName, addon = ...

addon.ChatTypes = addon.ChatTypes or {
    EVENT_CONTEXT = "EventContext",
    VISIBILITY_DECISION = "VisibilityDecision",
    SNAPSHOT_RECORD = "SnapshotRecord",
}
