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

function Service:NormalizeRealtime(frame, event, streamContext)
    if type(streamContext) ~= "table" then
        return nil, "invalid_stream_context"
    end

    local streamKey = streamContext.streamKey
    local kind, group = ResolveKinds(streamKey)

    local wowChatType = streamContext.wowChatType
    if (type(wowChatType) ~= "string" or wowChatType == "") and type(event) == "string" and addon.GetWowChatTypeByEvent then
        wowChatType = addon:GetWowChatTypeByEvent(event)
    end

    local channelBaseName = streamContext.channelName
    if wowChatType == "CHANNEL" and addon.ChannelSemanticResolver and type(addon.ChannelSemanticResolver.ResolveEventChannelName) == "function" then
        channelBaseName = addon.ChannelSemanticResolver.ResolveEventChannelName(
            streamContext.channelName,
            streamContext.channelString,
            streamContext.channelNumber
        )
    end

    return {
        mode = "realtime",
        event = type(event) == "string" and event or "",
        frameName = addon.FrameResolver and addon.FrameResolver.GetFrameName and addon.FrameResolver:GetFrameName(frame) or nil,
        streamKey = type(streamKey) == "string" and streamKey or "",
        streamKind = kind,
        streamGroup = group,
        wowChatType = type(wowChatType) == "string" and wowChatType or "",
        text = type(streamContext.text) == "string" and streamContext.text or "",
        author = type(streamContext.author) == "string" and streamContext.author or "",
        channelId = streamContext.channelNumber,
        channelBaseName = channelBaseName,
        timestamp = time(),
        classFilename = nil,
    }, nil
end

function Service:NormalizeReplay(line, frame)
    if type(line) ~= "table" then
        return nil, "invalid_snapshot_line"
    end

    local streamKey = type(line.streamKey) == "string" and line.streamKey or ""
    local kind, group = ResolveKinds(streamKey)

    local wowChatType = line.wowChatType
    if (type(wowChatType) ~= "string" or wowChatType == "") and type(streamKey) == "string" and streamKey ~= "" then
        local stream = addon.GetStreamByKey and addon:GetStreamByKey(streamKey) or nil
        wowChatType = type(stream) == "table" and stream.wowChatType or ""
    end

    local streamMeta = type(line.streamMeta) == "table" and line.streamMeta or nil

    return {
        mode = "replay",
        event = type(line.event) == "string" and line.event or "",
        frameName = addon.FrameResolver and addon.FrameResolver.GetFrameName and addon.FrameResolver:GetFrameName(frame)
            or (type(line.frameName) == "string" and line.frameName or nil),
        streamKey = streamKey,
        streamKind = kind,
        streamGroup = group,
        wowChatType = type(wowChatType) == "string" and wowChatType or "",
        text = type(line.text) == "string" and line.text or "",
        author = type(line.author) == "string" and line.author or "",
        channelId = streamMeta and streamMeta.channelId or nil,
        channelBaseName = streamMeta and streamMeta.channelBaseName or nil,
        timestamp = line.time or time(),
        classFilename = line.classFilename,
    }, nil
end
