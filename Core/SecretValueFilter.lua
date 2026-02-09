local addonName, addon = ...

-- =========================================================================
-- Secret Value Protection Filter
-- Prevents Blizzard's chat system from crashing when encountering secret values
-- in MONSTER_* events during boss fights
-- =========================================================================

-- Events that may contain secret values during combat
local PROTECTED_EVENTS = {
    "CHAT_MSG_MONSTER_YELL",
    "CHAT_MSG_MONSTER_SAY",
    "CHAT_MSG_MONSTER_WHISPER",
    "CHAT_MSG_MONSTER_PARTY",
    "CHAT_MSG_MONSTER_EMOTE",
    "CHAT_MSG_RAID_BOSS_EMOTE",
}

--- Filter function that blocks messages with secret values
--- @param frame table The chat frame
--- @param event string The event name
--- @param ... any Event arguments (text, author, etc.)
--- @return boolean true to block the message, false to allow it
local function SecretValueFilter(frame, event, ...)
    local text, author = ...
    
    -- If text or author is not a string (e.g., secret value), block the message
    -- This prevents Blizzard's HistoryKeeper from crashing when trying to process it
    if text ~= nil and type(text) ~= "string" then
        return true  -- Block message
    end
    if author ~= nil and type(author) ~= "string" then
        return true  -- Block message
    end
    
    return false  -- Allow message
end

--- Register the secret value filter for all protected events
local function RegisterSecretValueFilters()
    for _, event in ipairs(PROTECTED_EVENTS) do
        ChatFrame_AddMessageEventFilter(event, SecretValueFilter)
    end
end

-- Register filters immediately on module load
RegisterSecretValueFilters()
