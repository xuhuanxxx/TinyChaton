local addonName, addon = ...

-- =========================================================================
-- Middleware: CopyCache
-- Stage: LOG
-- Priority: 20
-- Description: Adds timestamp and prepares copy link
-- =========================================================================

-- Runs AFTER SnapshotLogger, so Snapshot saves text WITHOUT this timestamp.
-- This middleware MODIFIES text to include the timestamp for display.

addon.messageCache = addon.messageCache or {}

local function PruneMessageCache()
    -- Simplified prune
    local count = 0
    for _ in pairs(addon.messageCache) do count = count + 1 end
    if count > (addon.COPY_MESSAGE_LIMIT or 200) then
         addon.messageCache = {} -- Brutal clear for simplicity in middleware
    end
end

local function CopyCacheMiddleware(chatData)
    if not addon.db or not addon.db.enabled then return end
    
    local interaction = addon.db.plugin and addon.db.plugin.chat and addon.db.plugin.chat.interaction
    if not interaction or not interaction.timestampEnabled then return end
    
    local fmt = interaction.timestampFormat or "%H:%M:%S"
    local ts = date(fmt)
    local tsColor = interaction.timestampColor or "FF888888"
    
    local clickEnabled = (interaction.clickToCopy ~= false)
    
    if clickEnabled then
        local id = tostring(GetTime()) .. "_" .. tostring(math.random(10000, 99999))
        
        -- Cache the CLEAN text (what Snapshot also saved)
        -- Actually, we want to copy the *text* that is displayed.
        -- Only difference is we don't copy the timestamp itself usually?
        -- Original Copy.lua: cached the text passed to transformer.
        -- Here, chatData.text is the enriched text.
        
        PruneMessageCache()
        addon.messageCache[id] = { msg = chatData.text, time = GetTime() }
        
        -- Construct link
        -- Format: |cColor|Htinychat:copy:ID|h[Timestamp]|h|r Space Message
        local timestamp = string.format("|c%s|Htinychat:copy:%s|h[%s]|h|r", tsColor, id, ts)
        
        -- Prepend to text
        chatData.text = timestamp .. " " .. chatData.text
    else
        -- Just static timestamp
        local timestamp = string.format("|c%s[%s]|r", tsColor, ts)
        chatData.text = timestamp .. " " .. chatData.text
    end
end

addon.EventDispatcher:RegisterMiddleware("LOG", 20, "CopyCache", CopyCacheMiddleware)
