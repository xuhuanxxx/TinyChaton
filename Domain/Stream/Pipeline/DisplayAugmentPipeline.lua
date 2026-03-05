local addonName, addon = ...

addon.DisplayAugmentPipeline = addon.DisplayAugmentPipeline or {}
local Pipeline = addon.DisplayAugmentPipeline

local function BuildLine(envelope)
    if type(envelope) ~= "table" then
        return nil
    end

    local meta = type(envelope.channelMeta) == "table" and envelope.channelMeta or {}
    local normalized = meta.channelBaseName
    if normalized and addon.Utils and addon.Utils.NormalizeChannelBaseName then
        normalized = addon.Utils.NormalizeChannelBaseName(normalized)
    end

    local streamMeta = nil
    if envelope.wowChatType == "CHANNEL" then
        streamMeta = {
            channelId = meta.channelId,
            channelBaseName = meta.channelBaseName,
            channelBaseNameNormalized = normalized,
        }
    end

    return {
        text = type(envelope.rawText) == "string" and envelope.rawText or "",
        author = type(envelope.author) == "string" and envelope.author or "",
        wowChatType = envelope.wowChatType,
        streamKey = envelope.streamKey,
        kind = envelope.streamKind,
        group = envelope.streamGroup,
        streamMeta = streamMeta,
        time = envelope.timestamp or time(),
        classFilename = envelope.classFilename,
    }
end

local function ApplyHighlight(displayText, streamKey)
    if type(displayText) ~= "string" or displayText == "" then
        return displayText
    end
    if not addon.StreamHighlighter or type(addon.StreamHighlighter.ApplyDisplayText) ~= "function" then
        return displayText
    end
    return addon.StreamHighlighter:ApplyDisplayText(displayText, streamKey)
end

function Pipeline:Render(frame, envelope, opts)
    if type(envelope) ~= "table" then
        return nil, "invalid_envelope"
    end

    local line = BuildLine(envelope)
    if type(line) ~= "table" then
        return nil, "invalid_line"
    end

    local policy = addon.DisplayPolicyService
    local streamKey = envelope.streamKey
    local enableSend = policy and policy.CanInjectSend and policy:CanInjectSend(streamKey) or false
    local enableCopy = policy and policy.CanInjectCopy and policy:CanInjectCopy(streamKey) or false

    local renderOpts = {
        preferTimestampConfig = envelope.mode == "replay",
        enableSendLink = enableSend,
        enableCopyLink = enableCopy,
    }

    local displayText, r, g, b, extraArgs = addon:RenderChatLine(line, frame, renderOpts)
    if type(displayText) ~= "string" then
        return nil, "render_failed"
    end

    displayText = ApplyHighlight(displayText, streamKey)

    return {
        displayText = displayText,
        r = r,
        g = g,
        b = b,
        extraArgs = extraArgs,
        line = line,
    }, nil
end

return Pipeline
