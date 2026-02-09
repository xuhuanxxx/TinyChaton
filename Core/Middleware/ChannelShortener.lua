local addonName, addon = ...

-- =========================================================================
-- Middleware: ChannelShortener
-- Stage: ENRICH
-- Priority: 60
-- Description: Shortens channel names in connection messages (e.g., [1. General] -> [1. Gen])
-- =========================================================================

local function ChannelShortenerMiddleware(chatData)
    if not addon.db or not addon.db.enabled then return end
    
    local fmt = addon.db.plugin and addon.db.plugin.chat and addon.db.plugin.chat.visual and addon.db.plugin.chat.visual.channelNameFormat or "SHORT"
    if fmt == "NONE" then return end
    
    local msg = chatData.text
    if not msg then return end
    
    -- Skip if contains hyperlinks or timestamps (safety check)
    if msg:find("|H", 1, true) then return end
    if msg:match("^%[%d+:%d+") then return end
    
    local newMsg = (msg:gsub("^()%[([^%]]+)%]", function(_, inner)
        local short = addon.Utils.ShortenChannelString(inner, fmt)
        return "[" .. (short and short ~= inner and short or inner) .. "]"
    end, 1))
    
    if newMsg ~= msg then
        chatData.text = newMsg
    end
end

addon.EventDispatcher:RegisterMiddleware("ENRICH", 60, "ChannelShortener", ChannelShortenerMiddleware)
