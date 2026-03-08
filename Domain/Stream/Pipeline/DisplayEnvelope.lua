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

local function Validate(envelope)
    if addon.ValidateContract then
        addon:ValidateContract("DisplayEnvelope", envelope)
    end
    return envelope
end

function Envelope.FromRealtime(frame, event, streamContext)
    if type(streamContext) ~= "table" then
        return nil
    end

    local normalized, err = addon.StreamNormalizeService and addon.StreamNormalizeService.NormalizeRealtime
        and addon.StreamNormalizeService:NormalizeRealtime(frame, event, streamContext)
        or nil, nil
    if type(normalized) ~= "table" then
        return nil, err or "normalize_realtime_failed"
    end

    local streamKey = normalized.streamKey
    local streamKind, streamGroup = ResolveKinds(streamKey)
    local args = type(streamContext.args) == "table" and streamContext.args or nil

    local lineId = nil
    local classFilename = nil
    if args then
        lineId = args[11]
        if lineId == nil and args.n and args.n >= 12 then
            lineId = args[12]
        end

        local guid = args[12]
        if guid then
            local _, resolvedClass = GetPlayerInfoByGUID(guid)
            classFilename = resolvedClass
        end
    end

    return Validate({
        mode = normalized.mode or "realtime",
        frameName = normalized.frameName or ResolveFrameName(frame),
        event = normalized.event or (type(event) == "string" and event or ""),
        streamKey = streamKey,
        streamKind = streamKind,
        streamGroup = streamGroup,
        wowChatType = normalized.wowChatType or "",
        author = normalized.author or "",
        channelMeta = {
            channelId = normalized.channelId,
            channelBaseName = normalized.channelBaseName,
        },
        timestamp = normalized.timestamp or time(),
        lineId = lineId,
        rawText = normalized.text or "",
        classFilename = classFilename,
    })
end

function Envelope.FromReplayLine(line, frame)
    if type(line) ~= "table" then
        return nil
    end

    local normalized, err = addon.StreamNormalizeService and addon.StreamNormalizeService.NormalizeReplay
        and addon.StreamNormalizeService:NormalizeReplay(line, frame)
        or nil, nil
    if type(normalized) ~= "table" then
        return nil, err or "normalize_replay_failed"
    end

    local streamKey = normalized.streamKey
    local streamKind, streamGroup = ResolveKinds(streamKey)

    return Validate({
        mode = normalized.mode or "replay",
        frameName = normalized.frameName or ResolveFrameName(frame) or (type(line.frameName) == "string" and line.frameName or nil),
        event = normalized.event or (type(line.event) == "string" and line.event or ""),
        streamKey = streamKey,
        streamKind = streamKind,
        streamGroup = streamGroup,
        wowChatType = normalized.wowChatType or "",
        author = normalized.author or "",
        channelMeta = {
            channelId = normalized.channelId,
            channelBaseName = normalized.channelBaseName,
        },
        timestamp = normalized.timestamp or line.time or time(),
        lineId = nil,
        rawText = normalized.text or "",
        classFilename = normalized.classFilename,
    })
end

return Envelope
