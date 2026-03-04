local addonName, addon = ...

-- StreamEventContext Object
-- Unified context object passed through the middleware pipeline
-- =========================================================================

---@class StreamEventContext
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
---@field streamKey string|nil
---@field wowChatType string|nil

addon.StreamEventContext = {}

--- Create a new stream event context object from chat event arguments
--- @param frame table|nil ChatFrame object (can be nil)
--- @param event string Event name (e.g., "CHAT_MSG_SAY")
--- @param ... any Event arguments
--- @return StreamEventContext|nil Stream event context object or nil if invalid
function addon.StreamEventContext:New(frame, event, ...)
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
    local streamContext = addon.Pool:Acquire("StreamEventContext")

    streamContext.frame = frame
    streamContext.event = event
    streamContext.rawText = text
    streamContext.rawAuthor = author
    streamContext.text = text
    streamContext.author = author
    streamContext.name = pureName
    streamContext.textLower = text and string.lower(text) or ""
    streamContext.authorLower = pureName and string.lower(pureName) or ""
    streamContext.isBlocked = false
    -- metadata should be empty from reset, but explicit init is safer if reset logic changes
    -- streamContext.metadata = {}
    streamContext.args = args
    streamContext.languageID = languageID
    streamContext.channelString = channelString
    streamContext.target = target
    streamContext.flags = flags
    streamContext.channelNumber = channelNumber
    streamContext.channelName = channelName
    streamContext.streamKey = nil
    streamContext.wowChatType = nil
    streamContext.streamKind = nil
    streamContext.streamGroup = nil

    if addon.ResolveStreamKey and addon.Utils and addon.Utils.UnpackArgs then
        local ok, streamKey = pcall(addon.ResolveStreamKey, addon, event, addon.Utils.UnpackArgs(args))
        if ok and type(streamKey) == "string" and streamKey ~= "" then
            streamContext.streamKey = streamKey
            if addon.GetStreamKind then
                streamContext.streamKind = addon:GetStreamKind(streamKey)
                streamContext.streamGroup = addon:GetStreamGroup(streamKey)
            end
        end
    end
    if addon.GetWowChatTypeByEvent then
        streamContext.wowChatType = addon:GetWowChatTypeByEvent(event)
    end

    if addon.ValidateContract then
        addon:ValidateContract("EventContext", streamContext)
    end
    return streamContext
end

--- Release stream event context object back to pool
function addon.StreamEventContext:Release(streamContext)
    if streamContext then
        addon.Pool:Release("StreamEventContext", streamContext)
    end
end

-- Initialize the pool
if addon.Pool then
    addon.Pool:Create("StreamEventContext",
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
