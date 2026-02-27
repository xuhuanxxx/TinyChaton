local addonName, addon = ...

-- =========================================================================
-- Middleware: DuplicateFilter
-- Stage: FILTER
-- Priority: 30
-- Description: Filters repeated messages and cleans character spam
-- =========================================================================

local lastMessage = {}
local lastAccess = {}
local cleanupCounter = 0
local CLEANUP_INTERVAL = 100  -- Cleanup every 100 messages.
local MAX_IDLE_TIME = 300     -- Drop idle sender cache after 5 minutes.

-- Cleanup old entries to prevent memory leak
local function CleanupOldEntries()
    local now = GetTime()
    local removed = 0

    for author, timestamp in pairs(lastAccess) do
        if now - timestamp > MAX_IDLE_TIME then
            lastMessage[author] = nil
            lastAccess[author] = nil
            removed = removed + 1
        end
    end

    if addon.Debug and removed > 0 then
        addon:Debug(string.format("DuplicateFilter cleanup: removed %d old entries", removed))
    end
end

local function BuildNormalizedMessage(msg)
    if type(msg) ~= "string" then
        return msg
    end
    if #msg <= 4 then
        return msg
    end

    local cleanMsg = msg
    cleanMsg = cleanMsg:gsub("([^%s]+)%s+%1", "%1")
    cleanMsg = cleanMsg:gsub("([^%s]+)%s+%1", "%1")
    return cleanMsg
end

local function DuplicateFilterBlockMiddleware(chatData)
    if not addon.db or not addon.db.enabled then return end
    local filterSettings = addon.db.plugin and addon.db.plugin.filter
    if not filterSettings or not filterSettings.repeatFilter then return end

    local author = chatData.author
    local msg = chatData.text
    local t = GetTime()

    -- Periodic cleanup.
    cleanupCounter = cleanupCounter + 1
    if cleanupCounter >= CLEANUP_INTERVAL then
        CleanupOldEntries()
        cleanupCounter = 0
    end

    local normalizedMsg = BuildNormalizedMessage(msg)
    local last = lastMessage[author]
    local window = addon.REPEAT_FILTER_WINDOW or 10

    -- Exact match check after normalization.
    if last and last.msg == normalizedMsg and (t - last.time) < window then
        lastAccess[author] = t
        return true
    end

    if normalizedMsg ~= msg then
        chatData.metadata.duplicateFilterCleanedText = normalizedMsg
    end
    lastMessage[author] = { msg = normalizedMsg, time = t }
    lastAccess[author] = t

    return false
end

local function DuplicateFilterEnrichMiddleware(chatData)
    if not addon.db or not addon.db.enabled then return end
    local filterSettings = addon.db.plugin and addon.db.plugin.filter
    if not filterSettings or not filterSettings.repeatFilter then return end

    local cleaned = chatData.metadata and chatData.metadata.duplicateFilterCleanedText
    if cleaned and cleaned ~= chatData.text then
        chatData.text = cleaned
        chatData.textLower = string.lower(cleaned)
    end
end

function addon:InitDuplicateFilterMiddleware()
    local function EnableDuplicateFilter()
        if addon.EventDispatcher and not addon.EventDispatcher:IsMiddlewareRegistered("FILTER", "DuplicateFilterBlock") then
            addon.EventDispatcher:RegisterMiddleware("FILTER", 30, "DuplicateFilterBlock", DuplicateFilterBlockMiddleware)
        end
        if addon.EventDispatcher and not addon.EventDispatcher:IsMiddlewareRegistered("ENRICH", "DuplicateFilterEnrich") then
            addon.EventDispatcher:RegisterMiddleware("ENRICH", 30, "DuplicateFilterEnrich", DuplicateFilterEnrichMiddleware)
        end
    end

    local function DisableDuplicateFilter()
        if addon.EventDispatcher then
            addon.EventDispatcher:UnregisterMiddleware("FILTER", "DuplicateFilterBlock")
            addon.EventDispatcher:UnregisterMiddleware("ENRICH", "DuplicateFilterEnrich")
        end
    end

    if addon.RegisterFeature then
        addon:RegisterFeature("DuplicateFilter", {
            requires = { "READ_CHAT_EVENT", "PROCESS_CHAT_DATA" },
            onEnable = EnableDuplicateFilter,
            onDisable = DisableDuplicateFilter,
        })
    else
        EnableDuplicateFilter()
    end
end

addon:RegisterModule("DuplicateFilterMiddleware", addon.InitDuplicateFilterMiddleware)
