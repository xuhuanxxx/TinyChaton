local addonName, addon = ...

addon.EVENT_TO_CHANNEL_KEY = addon.EVENT_TO_CHANNEL_KEY or {
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

local channelNameCache = {}

function addon:InvalidateChannelKeyCache()
    table.wipe(channelNameCache)
end

local function FindRegistryKeyByChannelBaseName(baseName)
    if type(baseName) ~= "string" or baseName == "" then return nil end

    if channelNameCache[baseName] ~= nil then
        return channelNameCache[baseName] or nil
    end

    local normalized = addon.Utils and addon.Utils.NormalizeChannelBaseName
        and addon.Utils.NormalizeChannelBaseName(baseName) or baseName

    for _, stream, _, subKey in addon:IterateAllStreams() do
        if subKey == "DYNAMIC" and stream.mappingKey then
            local realName = addon.L and addon.L[stream.mappingKey]
            if realName and (
                realName == normalized
                or normalized:find(realName, 1, true) == 1
                or realName:find(normalized, 1, true) == 1
            ) then
                channelNameCache[baseName] = stream.key
                return stream.key
            end
        end
    end

    channelNameCache[baseName] = false
    return nil
end

function addon:GetCharacterKey()
    local name = UnitName("player")
    local realm = GetRealmName()
    if not name or name == "" or not realm or realm == "" or realm == "?" then
        return "Default"
    end
    return name .. "-" .. realm
end

function addon:GetChannelKey(event, ...)
    local key = addon.EVENT_TO_CHANNEL_KEY[event]
    if key then
        if key == "INSTANCE_CHAT" then
            return "instance"
        end
        return string.lower(key)
    end

    if event == "CHAT_MSG_CHANNEL" then
        local channelBaseName = select(9, ...)
        if type(channelBaseName) == "string" and channelBaseName ~= "" then
            local registryKey = FindRegistryKeyByChannelBaseName(channelBaseName)
            if registryKey then
                return registryKey
            end
            return "channel_" .. string.lower(channelBaseName)
        end

        local channelNumber = select(8, ...)
        if type(channelNumber) == "number" then
            return "channel_" .. tostring(channelNumber)
        end

        local channelString = select(4, ...)
        if type(channelString) == "string" and channelString ~= "" then
            local parsedName = channelString:match("^%d+%.%s*(.+)$")
            if parsedName and parsedName ~= "" then
                local registryKey = FindRegistryKeyByChannelBaseName(parsedName)
                if registryKey then
                    return registryKey
                end
                return "channel_" .. string.lower(parsedName)
            end
        end

        return "channel_?"
    end

    return string.lower(event or "?")
end
