local addonName, addon = ...
local L = addon.L

-- Display Module: CleanMessage
-- Description: Cleans up real-time chat messages for better aesthetics.
--              Primarily removes the space after the full-width colon in zhCN.

addon.CleanMessage = {}

function addon.CleanMessage.Process(frame, text, r, g, b, extraArgs)
    if not addon.db or not addon.db.enabled then return text, r, g, b, extraArgs end
    if type(text) ~= "string" or text == "" then return text, r, g, b, extraArgs end

    -- Use localized keys for cleaning
    local dirty = L["CHAT_MESSAGE_SEPARATOR_DIRTY"]
    local clean = L["CHAT_MESSAGE_SEPARATOR"]

    if dirty and clean and dirty ~= clean then
        -- Replace dirty separator with clean one
        -- e.g. "： " -> "："
        -- Using gsub for simplicity (matches pattern or string)
        text = text:gsub(dirty, clean)
    end

    return text, r, g, b, extraArgs
end

function addon:InitDisplayCleanMessage()
    local function EnableCleanMessage()
        addon:RegisterChatFrameTransformer("clean_message", addon.CleanMessage.Process)
    end

    local function DisableCleanMessage()
        addon.chatFrameTransformers["clean_message"] = nil
    end

    if addon.RegisterFeature then
        addon:RegisterFeature("CleanMessage", {
            requires = { "MUTATE_CHAT_DISPLAY" },
            plane = addon.RUNTIME_PLANES and addon.RUNTIME_PLANES.CHAT_DATA or "CHAT_DATA",
            onEnable = EnableCleanMessage,
            onDisable = DisableCleanMessage,
        })
    else
        EnableCleanMessage()
    end
end

addon:RegisterModule("DisplayCleanMessage", addon.InitDisplayCleanMessage)
