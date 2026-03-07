local addonName, addon = ...

addon.StreamTypes = addon.StreamTypes or {
    EVENT_CONTEXT = "EventContext",
    VISIBILITY_DECISION = "VisibilityDecision",
    SNAPSHOT_RECORD = "SnapshotRecord",
    DISPLAY_ENVELOPE = "DisplayEnvelope",
    DISPLAY_AUGMENT_CONTEXT = "DisplayAugmentContext",
    DISPLAY_RENDER_RESULT = "DisplayRenderResult",
}

function addon:GetStreamTypeName(key)
    return self.StreamTypes and self.StreamTypes[key] or nil
end
