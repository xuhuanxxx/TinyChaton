local addonName, addon = ...

-- =========================================================================
-- ChatData Object
-- Unified context object passed through the middleware pipeline
-- =========================================================================

addon.ChatData = {}

--- Create a new ChatData object from chat event arguments
--- @param frame table ChatFrame object (can be nil)
--- @param event string Event name (e.g., "CHAT_MSG_SAY")
--- @param ... Event arguments
--- @return table ChatData object
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

    local chatData = {
        -- Metadata (read-only)
        frame = frame,
        event = event,
        rawText = text,
        rawAuthor = author,
        
        -- Processing data (read-write)
        text = text,
        author = author,
        
        -- Pre-processed data (for performance)
        name = pureName,
        textLower = text and string.lower(text) or "",
        authorLower = pureName and string.lower(pureName) or "",
        
        -- State flags
        isBlocked = false,
        
        -- Metadata for modules to share information
        metadata = {},
        
        -- Original arguments (for passthrough to WoW API)
        args = args,
        
        -- Additional context
        languageID = languageID,
        channelString = channelString,
        target = target,
        flags = flags,
        channelNumber = channelNumber,
        channelName = channelName,
    }
    
    return chatData
end

--- Get the final modified arguments to pass to WoW API
--- @return ... Modified event arguments
function addon.ChatData:GetArgs(chatData)
    -- Create a copy of args to avoid side effects
    local original = chatData.args
    local n = original.n or #original
    
    -- Create a new args table (copy all arguments)
    local args = {}
    for i = 1, n do
        args[i] = original[i]
    end
    
    -- Replace text, author, and channelString with potentially modified versions
    args[1] = chatData.text
    args[2] = chatData.author
    
    -- Update channelString (arg4) if available
    -- This allows middleware to modify channel names directly
    if n >= 4 and chatData.channelString then
        args[4] = chatData.channelString
    end
    
    return unpack(args, 1, n)
end
