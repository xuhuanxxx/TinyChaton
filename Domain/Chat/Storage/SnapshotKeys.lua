local addonName, addon = ...

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
    local chatType = addon.GetChatTypeByEvent and addon:GetChatTypeByEvent(event) or nil
    if chatType and chatType ~= "CHANNEL" then
        if chatType == "INSTANCE_CHAT" then
            return "instance"
        end
        return string.lower(chatType)
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

    error("Unmapped chat event in GetChannelKey: " .. tostring(event))
end
