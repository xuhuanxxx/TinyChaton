local addonName, addon = ...

addon.DisplayEnvelope = addon.DisplayEnvelope or {}
local Envelope = addon.DisplayEnvelope

local function ResolveKinds(streamKey)
    if type(streamKey) ~= "string" or streamKey == "" then
        return nil, nil
    end
    local kind = addon.GetStreamKind and addon:GetStreamKind(streamKey) or nil
    local group = addon.GetStreamGroup and addon:GetStreamGroup(streamKey) or nil
    return kind, group
end

local function ResolveFrameName(frame)
    if addon.FrameResolver and type(addon.FrameResolver.GetFrameName) == "function" then
        return addon.FrameResolver:GetFrameName(frame)
    end
    return nil
end

function Envelope.FromRealtime(frame, event, streamContext)
    if type(streamContext) ~= "table" then
        return nil
    end

    local streamKey = type(streamContext.streamKey) == "string" and streamContext.streamKey or ""
    local streamKind, streamGroup = ResolveKinds(streamKey)
    local args = type(streamContext.args) == "table" and streamContext.args or nil

    local wowChatType = streamContext.wowChatType
    if (type(wowChatType) ~= "string" or wowChatType == "") and type(event) == "string" and addon.GetWowChatTypeByEvent then
        wowChatType = addon:GetWowChatTypeByEvent(event)
    end

    local channelBaseName = streamContext.channelName
    if wowChatType == "CHANNEL"
        and addon.ChannelSemanticResolver
        and type(addon.ChannelSemanticResolver.ResolveEventChannelName) == "function" then
        channelBaseName = addon.ChannelSemanticResolver.ResolveEventChannelName(
            streamContext.channelName,
            streamContext.channelString,
            streamContext.channelNumber
        )
    end

    local lineId = nil
    if args then
        lineId = args[11]
        if lineId == nil and args.n and args.n >= 12 then
            lineId = args[12]
        end
    end

    return {
        mode = "realtime",
        frameName = ResolveFrameName(frame),
        event = type(event) == "string" and event or "",
        streamKey = streamKey,
        streamKind = streamKind,
        streamGroup = streamGroup,
        wowChatType = type(wowChatType) == "string" and wowChatType or "",
        author = type(streamContext.author) == "string" and streamContext.author or "",
        channelMeta = {
            channelId = streamContext.channelNumber,
            channelBaseName = channelBaseName,
        },
        timestamp = time(),
        lineId = lineId,
        rawText = type(streamContext.text) == "string" and streamContext.text or "",
        classFilename = nil,
    }
end

function Envelope.FromReplayLine(line, frame)
    if type(line) ~= "table" then
        return nil
    end

    local streamKey = type(line.streamKey) == "string" and line.streamKey or ""
    local streamKind, streamGroup = ResolveKinds(streamKey)
    local streamMeta = type(line.streamMeta) == "table" and line.streamMeta or {}

    local wowChatType = line.wowChatType
    if (type(wowChatType) ~= "string" or wowChatType == "") and type(streamKey) == "string" and streamKey ~= "" then
        local stream = addon.GetStreamByKey and addon:GetStreamByKey(streamKey) or nil
        wowChatType = type(stream) == "table" and stream.wowChatType or ""
    end

    return {
        mode = "replay",
        frameName = ResolveFrameName(frame) or (type(line.frameName) == "string" and line.frameName or nil),
        event = type(line.event) == "string" and line.event or "",
        streamKey = streamKey,
        streamKind = streamKind,
        streamGroup = streamGroup,
        wowChatType = type(wowChatType) == "string" and wowChatType or "",
        author = type(line.author) == "string" and line.author or "",
        channelMeta = {
            channelId = streamMeta.channelId,
            channelBaseName = streamMeta.channelBaseName,
        },
        timestamp = line.time or time(),
        lineId = nil,
        rawText = type(line.text) == "string" and line.text or "",
        classFilename = line.classFilename,
    }
end

return Envelope
