local addonName, addon = ...

-- =========================================================================
-- Middleware: Timestamp
-- Stage: ENRICH
-- Priority: 35
-- Description: Syncs timestamp settings with system
-- =========================================================================

local function TimestampMiddleware(chatData)
    if not addon.db or not addon.db.enabled then return end

    local event = chatData.event or ""
    if not event:match("^CHAT_MSG_") then return end

    -- Sync settings with system
    local systemTimestamp = C_CVar.GetCVar("showTimestamps")
    addon.db.plugin.chat.interaction.timestampEnabled = (systemTimestamp and systemTimestamp ~= "none")
end

if addon.EventDispatcher then
    addon.EventDispatcher:RegisterMiddleware("ENRICH", 35, "Timestamp", TimestampMiddleware)
end
