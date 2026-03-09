local addonName, addon = ...

addon.StreamTypes = addon.StreamTypes or {
    EVENT_CONTEXT = "EventContext",
    VISIBILITY_DECISION = "VisibilityDecision",
    VISIBILITY_ENVELOPE = "VisibilityEnvelope",
    SNAPSHOT_RECORD = "SnapshotRecord",
    DISPLAY_MESSAGE = "DisplayMessage",
    DISPLAY_PIPELINE_CONTEXT = "DisplayPipelineContext",
    DISPLAY_RENDER_RESULT = "DisplayRenderResult",
}

function addon:GetStreamTypeName(key)
    return self.StreamTypes and self.StreamTypes[key] or nil
end
