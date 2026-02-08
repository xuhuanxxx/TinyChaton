local addonName, addon = ...

-- =========================================================================
-- Middleware: SnapshotLogger
-- Stage: LOG
-- Priority: 10
-- Description: Records message to history (Snapshot)
-- =========================================================================

-- Runs FIRST in LOG stage to capture text *before* Display timestamps are added

local EVENT_TO_CHANNEL_KEY = {
    ["CHAT_MSG_GUILD"] = "GUILD",
    ["CHAT_MSG_OFFICER"] = "OFFICER",
    ["CHAT_MSG_SAY"] = "SAY",
    ["CHAT_MSG_YELL"] = "YELL",
    ["CHAT_MSG_PARTY"] = "PARTY",
    ["CHAT_MSG_PARTY_LEADER"] = "PARTY",
    ["CHAT_MSG_RAID"] = "RAID",
    ["CHAT_MSG_RAID_LEADER"] = "RAID",
    ["CHAT_MSG_INSTANCE_CHAT"] = "INSTANCE_CHAT",
    ["CHAT_MSG_INSTANCE_CHAT_LEADER"] = "INSTANCE_CHAT",
    ["CHAT_MSG_WHISPER"] = "WHISPER",
    ["CHAT_MSG_WHISPER_INFORM"] = "WHISPER",
    ["CHAT_MSG_EMOTE"] = "EMOTE",
    ["CHAT_MSG_TEXT_EMOTE"] = "EMOTE",
    ["CHAT_MSG_SYSTEM"] = "SYSTEM",
    ["CHAT_MSG_BATTLEGROUND"] = "BATTLEGROUND",
    ["CHAT_MSG_BATTLEGROUND_LEADER"] = "BATTLEGROUND",
    ["CHAT_MSG_RAID_WARNING"] = "RAID_WARNING",
}

local function GetCharKey()
    local name = UnitName("player")
    local realm = GetRealmName()
    if not name or name == "" or not realm or realm == "" or realm == "?" then
        return "Default"
    end
    return name .. "-" .. realm
end

local function GetChannelKey(event, ...)
    local key = EVENT_TO_CHANNEL_KEY[event]
    if key then 
        if key == "INSTANCE_CHAT" then return "instance" end
        return string.lower(key) 
    end
    if event == "CHAT_MSG_CHANNEL" then
        -- Logic to find registry key would go here (omitted for brevity in middleware, relying on simple key)
        local channelBaseName = select(7, ...)
        return "channel_" .. (channelBaseName and string.lower(tostring(channelBaseName)) or "?")
    end
    return string.lower(event or "?")
end

local function SnapshotLoggerMiddleware(chatData)
    if not addon.db or not addon.db.enabled then return end
    
    -- Check if snapshot enabled
    local contentSettings = addon.db.plugin and addon.db.plugin.chat and addon.db.plugin.chat.content
    if not contentSettings or contentSettings.snapshotEnabled == false then return end
    
    local charKey = GetCharKey()
    if charKey == "Default" then return end
    
    -- Ensure global DB exists
    if not addon.db.global.chatSnapshot then addon.db.global.chatSnapshot = {} end
    if not addon.db.global.chatSnapshot[charKey] then addon.db.global.chatSnapshot[charKey] = {} end
    
    local event = chatData.event
    local channelKey = GetChannelKey(event, unpack(chatData.args))
    
    -- Check specific channel enabled
    local sc = contentSettings.snapshotChannels
    if sc then
        local legacyKey = ({ instance = "INSTANCE_CHAT" })[channelKey] or channelKey:upper()
        if sc[channelKey] == false or sc[legacyKey] == false then
            return
        end
    end
    
    local perChannel = addon.db.global.chatSnapshot[charKey]
    if not perChannel[channelKey] then perChannel[channelKey] = {} end
    
    -- Capture data
    -- We use chatData.text which includes Highlights/Emotes/ShortChannels
    
    -- Extract info similar to original Snapshot.lua
    local chatType = EVENT_TO_CHANNEL_KEY[event] or "CHANNEL"
    local channelId, channelBaseName
    if event == "CHAT_MSG_CHANNEL" then
        channelId = chatData.args[8] -- arg8 is channelNumber in event args? No.
        -- args: text, author, lang, chanString, target, flags, zone, chanNum, chanName
        -- arg8 is channelNumber. arg9 is channelName.
        channelId = chatData.channelNumber
        channelBaseName = chatData.channelName
    end
    
    -- Store
    -- Extract Class Color info from GUID (arg 12)
    local guid = chatData.args[12]
    local classFilename
    if guid then
        _, classFilename = GetPlayerInfoByGUID(guid)
    end

    table.insert(perChannel[channelKey], {
        text = chatData.text,
        author = chatData.author,
        channelKey = channelKey,
        chatType = chatType,
        channelId = channelId,
        channelBaseName = channelBaseName,
        time = time(),
        classFilename = classFilename,
        frameName = nil, -- Middleware doesn't know frame
        -- Colors (r,g,b) usually come from ChatTypeInfo, Snapshot restores them.
        -- We don't store them here to save space, rely on restoration logic.
    })
    
    -- Maintenance (Trimming) - simplified for middleware
    local maxPerChannel = contentSettings.maxPerChannel or 500
    while #perChannel[channelKey] > maxPerChannel do
        table.remove(perChannel[channelKey], 1)
    end
    
    -- We skip the complex EvictOldest logic here for performance, 
    -- assume Snapshot.lua on login handles bulk cleanup or run it periodically.
end

addon.EventDispatcher:RegisterMiddleware("LOG", 10, "SnapshotLogger", SnapshotLoggerMiddleware)
