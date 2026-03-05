local addonName, addon = ...

addon.StreamRenderService = addon.StreamRenderService or {}
local Service = addon.StreamRenderService

local function BuildLine(msg)
    local streamMeta = nil
    if msg.wowChatType == "CHANNEL" then
        local normalized = msg.channelBaseName
        if normalized and addon.Utils and addon.Utils.NormalizeChannelBaseName then
            normalized = addon.Utils.NormalizeChannelBaseName(normalized)
        end
        streamMeta = {
            channelId = msg.channelId,
            channelBaseName = msg.channelBaseName,
            channelBaseNameNormalized = normalized,
        }
    end

    return {
        text = msg.text,
        author = msg.author,
        wowChatType = msg.wowChatType,
        streamKey = msg.streamKey,
        kind = msg.streamKind,
        group = msg.streamGroup,
        streamMeta = streamMeta,
        time = msg.timestamp,
        classFilename = msg.classFilename,
    }
end

function Service:RenderRealtime(frame, normalized)
    return nil, "realtime_render_disabled"
end

function Service:RenderReplay(frame, normalized)
    if type(normalized) ~= "table" then
        return nil, "invalid_normalized"
    end

    local envelope = {
        mode = "replay",
        frameName = normalized.frameName,
        event = normalized.event,
        streamKey = normalized.streamKey,
        streamKind = normalized.streamKind,
        streamGroup = normalized.streamGroup,
        wowChatType = normalized.wowChatType,
        author = normalized.author,
        channelMeta = {
            channelId = normalized.channelId,
            channelBaseName = normalized.channelBaseName,
        },
        timestamp = normalized.timestamp,
        rawText = normalized.text,
        classFilename = normalized.classFilename,
    }

    local rendered, err = addon.DisplayAugmentPipeline:Render(frame, envelope)
    if type(rendered) ~= "table" or type(rendered.displayText) ~= "string" then
        return nil, "render_failed"
    end

    rendered.line = BuildLine(normalized)
    return rendered, err
end
