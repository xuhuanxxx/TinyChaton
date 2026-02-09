local addonName, addon = ...

-- =========================================================================
-- Middleware: EmoteParser
-- Stage: ENRICH
-- Priority: 50
-- Description: Replaces emote keys {smile} with textures
-- =========================================================================

-- Runs after Highlight to avoid breaking texture paths with highlights
-- (Assuming users don't highlight emote keys)

local function EmoteParserMiddleware(chatData)
    if not addon.db or not addon.db.enabled then return end
    
    -- Check if emote rendering is enabled
    local settings = addon.db.plugin and addon.db.plugin.chat and addon.db.plugin.chat.content
    if not settings or not settings.emoteRender then return end
    
    if addon.Emotes and addon.Emotes.Parse then
        local newText = addon.Emotes.Parse(chatData.text)
        if newText ~= chatData.text then
            chatData.text = newText
        end
    end
end

addon.EventDispatcher:RegisterMiddleware("ENRICH", 50, "EmoteParser", EmoteParserMiddleware)
