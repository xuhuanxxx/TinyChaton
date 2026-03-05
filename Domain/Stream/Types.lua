local addonName, addon = ...

addon.StreamTypes = addon.StreamTypes or {
    EVENT_CONTEXT = "EventContext",
    VISIBILITY_DECISION = "VisibilityDecision",
    SNAPSHOT_RECORD = "SnapshotRecord",
    DISPLAY_ENVELOPE = "DisplayEnvelope",
}

function addon:GetStreamTypeName(key)
    return self.StreamTypes and self.StreamTypes[key] or nil
end
