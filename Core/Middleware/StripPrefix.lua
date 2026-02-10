local addonName, addon = ...
local L = addon.L

-- =========================================================================
-- Middleware: StripPrefix
-- Stage: PRE_PROCESS
-- Priority: 10
-- Description: Removes redundant sender prefix like "[[1] Player] says:"
-- =========================================================================

local function StripPrefixMiddleware(chatData)
    -- Skip if disabled (using global switch for simplified logic, or could be a specific setting)
    if not addon.db or not addon.db.enabled then return end

    local msg = chatData.text
    if not msg or msg == "" then return end

    -- Check for standard chat frames patterns
    -- "[[1] Player] says: Message" -> "Message"
    -- This handles some specific UI addons or settings that double-print headers

    local sayColon = L["LABEL_PATTERN_STRIP_SAY"] or "says:"
    local colon = L["LABEL_PATTERN_STRIP_COLON"] or ":"

    -- Pattern 1: "[[123] Player] says: ..."
    local rest = msg:match("^%[%[%d+%] [^%]]+%]" .. sayColon .. " ?(.*)$")
    if rest then
        chatData.text = rest
        return
    end

    -- Pattern 2: "[[123] Player]: ..."
    rest = msg:match("^%[%[%d+%] [^%]]+%]" .. colon .. " ?(.*)$")
    if rest then
        chatData.text = rest
        return
    end
end

addon.EventDispatcher:RegisterMiddleware("PRE_PROCESS", 10, "StripPrefix", StripPrefixMiddleware)
