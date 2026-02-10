local addonName, addon = ...
local L = addon.L

-- =========================================================================
-- CleanMessage Module (was CleanChat)
-- Description: Cleans up real-time chat messages for better aesthetics.
--              Primarily removes the space after the full-width colon in zhCN.
-- =========================================================================

addon.CleanMessage = {}

function addon.CleanMessage.Process(frame, text, r, g, b, ...)
    if not addon.db or not addon.db.enabled then return text, r, g, b, ... end
    if type(text) ~= "string" or text == "" then return text, r, g, b, ... end

    -- Use localized keys for cleaning
    local dirty = L["CHAT_MESSAGE_SEPARATOR_DIRTY"]
    local clean = L["CHAT_MESSAGE_SEPARATOR"]

    if dirty and clean and dirty ~= clean then
        -- Replace dirty separator with clean one
        -- e.g. "： " -> "："
        -- Using gsub for simplicity (matches pattern or string)
        text = text:gsub(dirty, clean)
    end

    return text, r, g, b, ...
end

function addon:InitCleanMessage()
    -- Register as a transformer
    -- We want this to run BEFORE visual processors but AFTER copy/link logic?
    -- Actually, it changes the text content length/indices.
    -- If ClickToCopy relies on indices (it does somewhat), we should clean FIRST?
    -- ClickToCopy (copy transformer) runs looking for timestamps.
    -- If we remove space, it shouldn't affect timestamp at the start.

    addon:RegisterChatFrameTransformer("clean_message", addon.CleanMessage.Process)
end

-- P1: Register Module
addon:RegisterModule("CleanMessage", addon.InitCleanMessage)
