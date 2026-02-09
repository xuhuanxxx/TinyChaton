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
local CLEANUP_INTERVAL = 100  -- 每100条消息清理一次
local MAX_IDLE_TIME = 300     -- 5分钟未活动的玩家数据将被清理

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

local function DuplicateFilterMiddleware(chatData)
    if not addon.db or not addon.db.enabled then return end
    local filterSettings = addon.db.plugin and addon.db.plugin.filter
    if not filterSettings or not filterSettings.repeatFilter then return end
    
    local author = chatData.author
    local msg = chatData.text
    local t = GetTime()
    
    -- 定期清理
    cleanupCounter = cleanupCounter + 1
    if cleanupCounter >= CLEANUP_INTERVAL then
        CleanupOldEntries()
        cleanupCounter = 0
    end
    
    local last = lastMessage[author]
    local window = addon.REPEAT_FILTER_WINDOW or 10
    
    -- 1. Exact match check
    if last and last.msg == msg and (t - last.time) < window then
        lastAccess[author] = t  -- 更新访问时间
        return true -- Block duplicate
    end
    
    -- 2. Clean repeated characters (spam reduction)
    local len = #msg
    if len > 4 then
        local cleanMsg = msg
        -- Replace repetitive sequences of non-space characters
        cleanMsg = cleanMsg:gsub("([^%s]+)%s+%1", "%1")
        cleanMsg = cleanMsg:gsub("([^%s]+)%s+%1", "%1")
        
        if cleanMsg ~= msg then
            -- Update text in pipeline
            chatData.text = cleanMsg
            
            -- Store as last message with current time
            lastMessage[author] = { msg = cleanMsg, time = t }
            lastAccess[author] = t
            return false
        end
    end
    
    -- Update history
    lastMessage[author] = { msg = msg, time = t }
    lastAccess[author] = t
    
    return false
end

addon.EventDispatcher:RegisterMiddleware("FILTER", 30, "DuplicateFilter", DuplicateFilterMiddleware)
