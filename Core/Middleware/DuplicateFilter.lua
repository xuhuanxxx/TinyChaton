local addonName, addon = ...

-- =========================================================================
-- Middleware: DuplicateFilter
-- Stage: FILTER
-- Priority: 30
-- Description: Filters repeated messages and cleans character spam
-- =========================================================================

local lastMessage = {}

local function DuplicateFilterMiddleware(chatData)
    if not addon.db or not addon.db.enabled then return end
    local filterSettings = addon.db.plugin and addon.db.plugin.filter
    if not filterSettings or not filterSettings.repeatFilter then return end
    
    local author = chatData.author
    local msg = chatData.text
    local t = GetTime()
    
    local last = lastMessage[author]
    local window = addon.REPEAT_FILTER_WINDOW or 10
    
    -- 1. Exact match check
    if last and last.msg == msg and (t - last.time) < window then
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
            return false
        end
    end
    
    -- Update history
    lastMessage[author] = { msg = msg, time = t }
    
    return false
end

addon.EventDispatcher:RegisterMiddleware("FILTER", 30, "DuplicateFilter", DuplicateFilterMiddleware)
