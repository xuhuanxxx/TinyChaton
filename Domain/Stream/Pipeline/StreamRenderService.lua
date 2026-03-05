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
    if type(normalized) ~= "table" then
        return nil, "invalid_normalized"
    end

    local displayText = normalized.text
    local extraArgs = addon.Utils.PackArgs()
    if type(normalized.streamKey) == "string" and normalized.streamKey ~= "" then
        extraArgs.streamKey = normalized.streamKey
    end

    if addon.Gateway and addon.Gateway.Display and addon.Gateway.Display.Transform then
        local ok, nextMsg = pcall(function()
            local outMsg = addon.Gateway.Display:Transform(frame, displayText, nil, nil, nil, extraArgs)
            return outMsg
        end)
        if ok and type(nextMsg) == "string" then
            displayText = nextMsg
        end
    end

    return {
        displayText = displayText,
        r = nil,
        g = nil,
        b = nil,
        extraArgs = extraArgs,
        line = nil,
    }, nil
end

function Service:RenderReplay(frame, normalized)
    if type(normalized) ~= "table" then
        return nil, "invalid_normalized"
    end

    local line = BuildLine(normalized)
    local displayText, r, g, b, extraArgs = addon:RenderChatLine(line, frame, { preferTimestampConfig = true })
    if type(displayText) ~= "string" then
        return nil, "render_failed"
    end

    return {
        displayText = displayText,
        r = r,
        g = g,
        b = b,
        extraArgs = extraArgs,
        line = line,
    }, nil
end
