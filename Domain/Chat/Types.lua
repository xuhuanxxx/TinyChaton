local addonName, addon = ...

addon.ChatTypes = addon.ChatTypes or {
    EVENT_CONTEXT = "EventContext",
    VISIBILITY_DECISION = "VisibilityDecision",
    SNAPSHOT_RECORD = "SnapshotRecord",
}

function addon:GetChatTypeName(key)
    return self.ChatTypes and self.ChatTypes[key] or nil
end
