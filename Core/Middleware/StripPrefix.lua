local addonName, addon = ...
local L = addon.L

-- =========================================================================
-- Display Transformer: StripPrefix
-- Priority: 10
-- Description: Removes redundant sender prefix like "[[1] Player] says:"
-- =========================================================================

addon.StripPrefix = addon.StripPrefix or {}

function addon.StripPrefix.Apply(msg)
    if type(msg) ~= "string" or msg == "" then return msg end

    -- Check for standard chat frames patterns
    -- "[[1] Player] says: Message" -> "Message"
    -- This handles some specific UI addons or settings that double-print headers

    local sayColon = L["LABEL_PATTERN_STRIP_SAY"] or "says:"
    local colon = L["LABEL_PATTERN_STRIP_COLON"] or ":"

    -- Pattern 1: "[[123] Player] says: ..."
    local rest = msg:match("^%[%[%d+%] [^%]]+%]" .. sayColon .. " ?(.*)$")
    if rest then
        return rest
    end

    -- Pattern 2: "[[123] Player]: ..."
    rest = msg:match("^%[%[%d+%] [^%]]+%]" .. colon .. " ?(.*)$")
    if rest then
        return rest
    end

    return msg
end

local function StripPrefixTransformer(frame, text, ...)
    if not addon.db or not addon.db.enabled then return text, ... end
    return addon.StripPrefix.Apply(text), ...
end

function addon:InitStripPrefix()
    local function EnableStripPrefix()
        addon:RegisterChatFrameTransformer("display_strip_prefix", StripPrefixTransformer)
    end

    local function DisableStripPrefix()
        addon.chatFrameTransformers["display_strip_prefix"] = nil
    end

    if addon.RegisterFeature then
        addon:RegisterFeature("StripPrefix", {
            requires = { "MUTATE_CHAT_DISPLAY" },
            onEnable = EnableStripPrefix,
            onDisable = DisableStripPrefix,
        })
    else
        EnableStripPrefix()
    end
end

addon:RegisterModule("StripPrefix", addon.InitStripPrefix)
