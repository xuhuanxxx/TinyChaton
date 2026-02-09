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

-- Standalone Frame for safe logging (Observer Pattern)
-- Decoupled from EventDispatcher to prevent Taint in combat
local loggerFrame = CreateFrame("Frame")

local function OnSnapshotEvent(self, event, ...)
    -- Safety: Disable all recording during combat to prevent Taint
    if InCombatLockdown() then return end

    if not addon.db or not addon.db.enabled then return end
    
    -- Check if snapshot enabled
    local contentSettings = addon.db.plugin and addon.db.plugin.chat and addon.db.plugin.chat.content
    if not contentSettings or contentSettings.snapshotEnabled == false then return end
    
    local charKey = GetCharKey()
    if charKey == "Default" then return end
    
    -- We can safely reuse ChatData parser since it only reads args
    -- But we must be careful not to modify anything
    local chatData = addon.ChatData and addon.ChatData:New(nil, event, ...)
    if not chatData then return end

    -- Ensure global DB exists
    if not addon.db.global.chatSnapshot then addon.db.global.chatSnapshot = {} end
    if not addon.db.global.chatSnapshot[charKey] then addon.db.global.chatSnapshot[charKey] = {} end
    
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
    local chatType = EVENT_TO_CHANNEL_KEY[event] or "CHANNEL"
    local channelId, channelBaseName
    if event == "CHAT_MSG_CHANNEL" then
        channelId = chatData.channelNumber
        channelBaseName = chatData.channelName
    end
    
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
        -- frameName is less relevant in background logging, nil is fine
        frameName = nil 
    })
    
    -- Maintenance (Trimming)
    local maxPerChannel = contentSettings.maxPerChannel or 500
    while #perChannel[channelKey] > maxPerChannel do
        table.remove(perChannel[channelKey], 1)
    end
end

loggerFrame:SetScript("OnEvent", OnSnapshotEvent)

-- Register events independently
-- This ensures we catch everything even if filters are blocked/bypassed
for event in pairs(EVENT_TO_CHANNEL_KEY) do
    loggerFrame:RegisterEvent(event)
end
loggerFrame:RegisterEvent("CHAT_MSG_CHANNEL")

