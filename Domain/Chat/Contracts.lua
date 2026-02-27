local addonName, addon = ...

addon.ChatContracts = addon.ChatContracts or {}

addon.ChatContracts.EventContext = {
    frame = "table|nil",
    event = "string",
    text = "string|nil",
    author = "string|nil",
    metadata = "table",
}

addon.ChatContracts.VisibilityDecision = {
    visible = "boolean",
    reason = "string|nil",
}

addon.ChatContracts.SnapshotRecord = {
    text = "string",
    author = "string|nil",
    channelKey = "string",
    time = "number",
}
