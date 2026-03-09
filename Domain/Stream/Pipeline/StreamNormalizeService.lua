local addonName, addon = ...

addon.StreamNormalizeService = addon.StreamNormalizeService or {}
local Service = addon.StreamNormalizeService

local function ResolveKinds(streamKey)
    if type(streamKey) ~= "string" or streamKey == "" then
        return nil, nil
    end
    local kind = addon.GetStreamKind and addon:GetStreamKind(streamKey) or nil
    local group = addon.GetStreamGroup and addon:GetStreamGroup(streamKey) or nil
    return kind, group
end

local function ResolveFrameName(frame, fallbackName)
    if addon.FrameResolver and addon.FrameResolver.GetFrameName then
        local name = addon.FrameResolver:GetFrameName(frame)
        if type(name) == "string" and name ~= "" then
            return name
        end
    end
    if type(fallbackName) == "string" and fallbackName ~= "" then
        return fallbackName
    end
    return nil
end

local function ResolveChannelName(wowChatType, channelName, channelString, channelId)
    if wowChatType ~= "CHANNEL" then
        return nil
    end

    if addon.ChannelSemanticResolver and type(addon.ChannelSemanticResolver.ResolveEventChannelName) == "function" then
        return addon.ChannelSemanticResolver.ResolveEventChannelName(channelName, channelString, channelId)
    end

    return channelName
end

local function ResolveLineId(args, fallback)
    if fallback ~= nil then
        return fallback
    end
    if type(args) ~= "table" then
        return nil
    end

    local lineId = args[11]
    if lineId == nil and args.n and args.n >= 12 then
        lineId = args[12]
    end
    return lineId
end

local function ResolveClassFilename(args, fallback)
    if type(fallback) == "string" and fallback ~= "" then
        return fallback
    end
    if type(args) ~= "table" then
        return nil
    end

    local guid = args[12]
    if guid then
        local _, resolvedClass = GetPlayerInfoByGUID(guid)
        return resolvedClass
    end

    return nil
end

local function BuildDisplayMessage(sourceMode, frame, frameName, event, streamKey, wowChatType, author, rawText, timestamp, channelId,
                                   channelNameObserved, lineId, classFilename)
    local streamKind, streamGroup = ResolveKinds(streamKey)
    local message = {
        sourceMode = sourceMode,
        frameName = ResolveFrameName(frame, frameName),
        event = type(event) == "string" and event or "",
        streamKey = type(streamKey) == "string" and streamKey or "",
        streamKind = streamKind,
        streamGroup = streamGroup,
        wowChatType = type(wowChatType) == "string" and wowChatType or "",
        author = type(author) == "string" and author or "",
        rawText = type(rawText) == "string" and rawText or "",
        timestamp = tonumber(timestamp) or time(),
        lineId = lineId,
        channelId = tonumber(channelId),
        channelNameObserved = type(channelNameObserved) == "string" and channelNameObserved or nil,
        classFilename = classFilename,
    }

    if addon.ValidateContract then
        addon:ValidateContract("DisplayMessage", message)
    end

    return message
end

function Service:NormalizeRealtime(frame, event, streamContext)
    if type(streamContext) ~= "table" then
        return nil, "invalid_stream_context"
    end

    local streamKey = streamContext.streamKey
    local wowChatType = streamContext.wowChatType
    if (type(wowChatType) ~= "string" or wowChatType == "") and type(event) == "string" and addon.GetWowChatTypeByEvent then
        wowChatType = addon:GetWowChatTypeByEvent(event)
    end

    local args = type(streamContext.args) == "table" and streamContext.args or nil
    local channelId = streamContext.channelNumber
    local channelNameObserved = ResolveChannelName(
        wowChatType,
        streamContext.channelName,
        streamContext.channelString,
        channelId
    )

    return BuildDisplayMessage(
        "realtime",
        frame,
        nil,
        event,
        streamKey,
        wowChatType,
        streamContext.author,
        streamContext.text,
        time(),
        channelId,
        channelNameObserved,
        ResolveLineId(args, streamContext.lineId),
        ResolveClassFilename(args, streamContext.classFilename)
    ), nil
end

function Service:NormalizeReplay(line, frame)
    if type(line) ~= "table" then
        return nil, "invalid_snapshot_line"
    end

    local streamKey = type(line.streamKey) == "string" and line.streamKey or ""
    local wowChatType = line.wowChatType
    if (type(wowChatType) ~= "string" or wowChatType == "") and type(streamKey) == "string" and streamKey ~= "" then
        local stream = addon.GetStreamByKey and addon:GetStreamByKey(streamKey) or nil
        wowChatType = type(stream) == "table" and stream.wowChatType or ""
    end

    local rawText = line.rawText
    if type(rawText) ~= "string" then
        rawText = line.text
    end

    local channelId = line.channelId
    if channelId == nil and type(line.streamMeta) == "table" then
        channelId = line.streamMeta.channelId
    end

    local channelNameObserved = line.channelNameObserved
    if type(channelNameObserved) ~= "string" and type(line.streamMeta) == "table" then
        channelNameObserved = line.streamMeta.channelBaseName
    end

    return BuildDisplayMessage(
        "replay",
        frame,
        line.frameName,
        line.event,
        streamKey,
        wowChatType,
        line.author,
        rawText,
        line.time or line.timestamp,
        channelId,
        channelNameObserved,
        line.lineId,
        ResolveClassFilename(nil, line.classFilename)
    ), nil
end
