local addonName, addon = ...

-- =========================================================================
-- Middleware: ChannelShortener
-- Stage: ENRICH
-- Priority: 60
-- Description: Shortens channel names in connection messages (e.g., [1. General] -> [1. Gen])
-- =========================================================================

local function ShortenChannelString(str, fmt)
    -- Simplified version of Visual.lua's ShortenChannelString
    -- We assume Visual.lua is still loaded and Utils are available
    if not str or str == "" then return str end
    
    -- Reuse the robust logic from Visual.lua if exposed, or re-implement?
    -- Visual.lua functions are local. We need to re-implement or expose.
    -- For now, let's implement the core logic which is usually just the regex replacer
    
    -- NOTE: Proper re-implementation requires access to GetChannelName, etc.
    -- Given this is "Optimization", code duplication is minor compared to correctness.
    -- I will implement the regex replacement part.
    
    local num, name = str:match("^(%d+)%.%s*(.*)")
    if not num then
        num = str:match("^(%d+)%.?$")
        name = ""
    end
    
    local id = tonumber(num)
    local fallbackName = (name and name ~= "") and name or (num or str)
    
    if fmt == "NUMBER" then
        return num or fallbackName
    elseif fmt == "SHORT" then
        if fallbackName and fallbackName ~= "" then
            return fallbackName:match("[%z\1-\127\194-\244][\128-\191]*") or fallbackName:sub(1,3)
        end
        return str
    elseif fmt == "NUMBER_SHORT" then
        local short = fallbackName:match("[%z\1-\127\194-\244][\128-\191]*") or fallbackName:sub(1,3)
        return num and (num .. "." .. short) or short
    elseif fmt == "FULL" then
        return fallbackName
    end
    
    return str
end

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
        local short = ShortenChannelString(inner, fmt)
        return "[" .. (short and short ~= inner and short or inner) .. "]"
    end, 1))
    
    if newMsg ~= msg then
        chatData.text = newMsg
    end
end

addon.EventDispatcher:RegisterMiddleware("ENRICH", 60, "ChannelShortener", ChannelShortenerMiddleware)
