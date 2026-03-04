local addonName, addon = ...

-- =========================================================================
-- Middleware: Timestamp
-- Stage: TRANSFORM
-- Priority: 35
-- Description: Reads system timestamp state for chat processing
-- =========================================================================

local function IsSystemTimestampEnabled()
    local systemTimestamp = C_CVar.GetCVar("showTimestamps")
    return (systemTimestamp and systemTimestamp ~= "none") and true or false
end

local function TimestampMiddleware(streamContext)
    if not addon.db or not addon.db.enabled then return end
    local event = streamContext.event or ""
    if not event:match("^CHAT_MSG_") then return end
    streamContext.metadata.systemTimestampEnabled = IsSystemTimestampEnabled()
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
        end)
    end

    local function EnableTimestamp()
        if addon.StreamEventDispatcher and not addon.StreamEventDispatcher:IsMiddlewareRegistered("TRANSFORM", "Timestamp") then
            addon.StreamEventDispatcher:RegisterMiddleware("TRANSFORM", 35, "Timestamp", TimestampMiddleware)
        end
    end

    local function DisableTimestamp()
        if addon.StreamEventDispatcher then
            addon.StreamEventDispatcher:UnregisterMiddleware("TRANSFORM", "Timestamp")
        end
    end

    addon:RegisterFeature("Timestamp", {
        requires = { "PROCESS_CHAT_DATA" },
        plane = addon.RUNTIME_PLANES and addon.RUNTIME_PLANES.CHAT_DATA or "CHAT_DATA",
        onEnable = EnableTimestamp,
        onDisable = DisableTimestamp,
    })
end

addon:RegisterModule("SystemTimestampSyncMiddleware", addon.InitSystemTimestampSyncMiddleware)
