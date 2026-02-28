local addonName, addon = ...

-- =========================================================================
-- ChatData Object
-- Unified context object passed through the middleware pipeline
-- =========================================================================

---@class ChatData
---@field frame table|nil ChatFrame object
---@field event string Event name
---@field rawText string Original message text
---@field rawAuthor string Original author string
---@field text string Processed message text (can be modified)
---@field author string Processed author name (can be modified)
---@field name string Pure name (without realm suffix)
---@field textLower string Lowercase text for matching
---@field authorLower string Lowercase author for matching
---@field isBlocked boolean Whether the message should be blocked
---@field metadata table Shared metadata for modules
---@field args table Original arguments with n count
---@field languageID number|nil
---@field channelString string|nil
---@field target string|nil
---@field flags string|nil
---@field channelNumber number|nil
---@field channelName string|nil

addon.ChatData = {}

--- Create a new ChatData object from chat event arguments
--- @param frame table|nil ChatFrame object (can be nil)
--- @param event string Event name (e.g., "CHAT_MSG_SAY")
--- @param ... any Event arguments
--- @return ChatData|nil ChatData object or nil if invalid
function addon.ChatData:New(frame, event, ...)
    local text, author, languageID, channelString, target, flags, unknown, channelNumber, channelName, unknown2, counter = ...

    -- Protect against secret values (Blizzard marks certain messages as inaccessible)
    -- Check both text and author as they can both be secret values during boss fights
    -- If either is not a string (e.g., secret value), return nil to skip this message
    -- Also validate event type to prevent pipeline errors
    if event ~= nil and type(event) ~= "string" then
        return nil
    end
    if text ~= nil and type(text) ~= "string" then
        return nil
    end
    if author ~= nil and type(author) ~= "string" then
        return nil
    end

    -- Extract pure name (without realm suffix)
    local pureName = author and string.match(author, "([^%-]+)") or author
    -- Store arguments with count to handle nils safely
    local n = select('#', ...)
    local args = { ... }
    args.n = n

    -- Try to acquire from pool
    local chatData = addon.Pool:Acquire("ChatData")
    
    chatData.frame = frame
    chatData.event = event
    chatData.rawText = text
    chatData.rawAuthor = author
    chatData.text = text
    chatData.author = author
    chatData.name = pureName
    chatData.textLower = text and string.lower(text) or ""
    chatData.authorLower = pureName and string.lower(pureName) or ""
    chatData.isBlocked = false
    -- metadata should be empty from reset, but explicit init is safer if reset logic changes
    -- chatData.metadata = {} 
    chatData.args = args
    chatData.languageID = languageID
    chatData.channelString = channelString
    chatData.target = target
    chatData.flags = flags
    chatData.channelNumber = channelNumber
    chatData.channelName = channelName

    if addon.ValidateContract then
        addon:ValidateContract("EventContext", chatData)
    end
    return chatData
end

--- Release ChatData object back to pool
function addon.ChatData:Release(chatData)
    if chatData then
        addon.Pool:Release("ChatData", chatData)
    end
end

-- Initialize the pool
if addon.Pool then
    addon.Pool:Create("ChatData", 
        -- Factory
        function() 
            return { metadata = {} } 
        end,
        -- Reset
        function(obj)
            table.wipe(obj.metadata)
            -- We don't need to wipe other fields as they are overwritten in New
            -- keeping structure is good for JIT
            obj.args = nil 
            obj.frame = nil
        end
    )
end
