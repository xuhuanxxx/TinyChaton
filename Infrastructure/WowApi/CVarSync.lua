local addonName, addon = ...

-- =========================================================================
-- Middleware: Timestamp
-- Stage: ENRICH
-- Priority: 35
-- Description: Mirrors system timestamp state for chat processing
-- =========================================================================

local function IsSystemTimestampEnabled()
    local systemTimestamp = C_CVar.GetCVar("showTimestamps")
    return (systemTimestamp and systemTimestamp ~= "none") and true or false
end

local function TimestampMiddleware(chatData)
    if not addon.db or not addon.db.enabled then return end
    local event = chatData.event or ""
    if not event:match("^CHAT_MSG_") then return end
    chatData.metadata.systemTimestampEnabled = IsSystemTimestampEnabled()
end

local function SyncTimestampSetting()
    if not addon.db or not addon.db.plugin or not addon.db.plugin.chat or not addon.db.plugin.chat.interaction then
        return
    end
    addon.db.plugin.chat.interaction.timestampEnabled = IsSystemTimestampEnabled()
end

function addon:InitSystemTimestampSyncMiddleware()
    if addon.RegisterEvent then
        addon:RegisterEvent("CVAR_UPDATE", function(_, ...)
            local cvarName
            local argc = select("#", ...)
            for i = 1, argc do
                local candidate = select(i, ...)
                if type(candidate) == "string" and candidate ~= "" then
                    cvarName = candidate
                    break
                end
            end
            if type(cvarName) ~= "string" then
                return
            end

            local normalized = string.lower(cvarName)
            if normalized ~= "showtimestamps" then
                return
            end
            if addon.IsFeatureEnabled and not addon:IsFeatureEnabled("Timestamp") then
                return
            end
            SyncTimestampSetting()
        end)
    end

    local function EnableTimestamp()
        if addon.EventDispatcher and not addon.EventDispatcher:IsMiddlewareRegistered("ENRICH", "Timestamp") then
            addon.EventDispatcher:RegisterMiddleware("ENRICH", 35, "Timestamp", TimestampMiddleware)
        end
        SyncTimestampSetting()
    end

    local function DisableTimestamp()
        if addon.EventDispatcher then
            addon.EventDispatcher:UnregisterMiddleware("ENRICH", "Timestamp")
        end
    end

    if addon.RegisterFeature then
        addon:RegisterFeature("Timestamp", {
            requires = { "PROCESS_CHAT_DATA" },
            onEnable = EnableTimestamp,
            onDisable = DisableTimestamp,
        })
    else
        EnableTimestamp()
    end
end

addon:RegisterModule("SystemTimestampSyncMiddleware", addon.InitSystemTimestampSyncMiddleware)
