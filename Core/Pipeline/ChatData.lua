local addonName, addon = ...

-- =========================================================================
-- ChatData Object
-- Unified context object passed through the middleware pipeline
-- =========================================================================

addon.ChatData = {}

--- Create a new ChatData object from chat event arguments
--- @param event string Event name (e.g., "CHAT_MSG_SAY")
--- @param ... Event arguments
--- @return table ChatData object
function addon.ChatData:New(event, ...)
    local text, author, languageID, channelString, target, flags, unknown, channelNumber, channelName, unknown2, counter = ...
    
    -- Extract pure name (without realm suffix)
    local pureName = author and string.match(author, "([^%-]+)") or author
    -- Store arguments with count to handle nils safely
    local n = select('#', ...)
    local args = { ... }
    args.n = n

    local chatData = {
        -- Metadata (read-only)
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
    -- Replace text and author with potentially modified versions
    local args = chatData.args
    local n = args.n or #args
    
    -- Create a copy to avoid modifying the original args table (though we create a new one each time)
    -- But essential to handle the replacement logic safely without losing n
    -- Actually we can just modify the table? No, better safe.
    
    -- We need to return ALL arguments, replacing 1 and 2.
    -- Since we can't easily modify varargs, we construct a table.
    -- Note: We can modify 'args' directly since ChatData is transient.
    
    args[1] = chatData.text
    args[2] = chatData.author
    
    return unpack(args, 1, n)
end
