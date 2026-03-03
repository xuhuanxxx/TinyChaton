local addonName, addon = ...

local UNKNOWN_DYNAMIC = "unknown_dynamic"

function addon:GetCharacterKey()
    local name = UnitName("player")
    local realm = GetRealmName()
    if not name or name == "" or not realm or realm == "" or realm == "?" then
        return "Default"
    end
    return name .. "-" .. realm
end

function addon:ResolveStreamKey(event, ...)
    local streamMap = addon.EVENT_TO_STREAM_KEY
    local mappedStreamKey = streamMap and streamMap[event]
    if type(mappedStreamKey) == "string" and mappedStreamKey ~= "" and event ~= "CHAT_MSG_CHANNEL" then
        return mappedStreamKey
    end

    local chatType = addon.GetChatTypeByEvent and addon:GetChatTypeByEvent(event) or nil

    if event == "CHAT_MSG_CHANNEL" then
        local channelNumber = select(8, ...)
        local channelBaseName = select(9, ...)
        local channelString = select(4, ...)

        local resolver = addon.ChannelSemanticResolver
        local parsedName = (resolver and type(resolver.ResolveEventChannelName) == "function")
            and resolver.ResolveEventChannelName(channelBaseName, channelString, channelNumber)
            or channelBaseName

        if resolver and type(resolver.ResolveStreamKey) == "function" then
            local streamKey = resolver.ResolveStreamKey({
                chatType = "CHANNEL",
                channelId = channelNumber,
                channelName = parsedName,
            })
            if type(streamKey) == "string" and streamKey ~= "" then
                return streamKey
            end
        end

        return UNKNOWN_DYNAMIC
    end

    if mappedStreamKey then
        return mappedStreamKey
    end

    error("Unmapped chat event in ResolveStreamKey: " .. tostring(event))
end
