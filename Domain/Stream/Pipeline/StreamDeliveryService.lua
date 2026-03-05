local addonName, addon = ...

addon.StreamDeliveryService = addon.StreamDeliveryService or {}
local Service = addon.StreamDeliveryService

local WOW_CHAT_TYPE_TO_STREAM_KEY = {}

local function EnsureWowChatTypeIndex()
    if next(WOW_CHAT_TYPE_TO_STREAM_KEY) ~= nil then
        return WOW_CHAT_TYPE_TO_STREAM_KEY
    end
    for _, stream in addon:IterateCompiledStreams() do
        if type(stream) == "table"
            and type(stream.wowChatType) == "string"
            and stream.wowChatType ~= ""
            and type(stream.key) == "string"
            and stream.key ~= ""
            and addon:GetStreamKind(stream.key) == "channel"
            and WOW_CHAT_TYPE_TO_STREAM_KEY[stream.wowChatType] == nil then
            WOW_CHAT_TYPE_TO_STREAM_KEY[stream.wowChatType] = stream.key
        end
    end
    return WOW_CHAT_TYPE_TO_STREAM_KEY
end

local function ExtractLabelFromDisplay(displayText)
    if type(displayText) ~= "string" then
        return nil
    end
    local label = displayText:match("^%[(.-)%]%s*$")
    return label
end

local function ResolveConfiguredLabel(linkTarget, rawLabel)
    if type(linkTarget) ~= "string" or linkTarget == "" then
        return nil
    end

    if linkTarget:find("^CHANNEL", 1, true) == 1 then
        local channelId = tonumber(linkTarget:match("^CHANNEL:(%d+)"))
        local display = addon.Utils.ResolveChannelDisplay({
            wowChatType = "CHANNEL",
            streamMeta = {
                channelId = channelId,
                channelBaseName = rawLabel,
            },
        })
        return ExtractLabelFromDisplay(display)
    end

    local streamKey = EnsureWowChatTypeIndex()[linkTarget]
    if type(streamKey) ~= "string" or streamKey == "" then
        return nil
    end
    local stream = addon:GetStreamByKey(streamKey)
    if type(stream) ~= "table" then
        return nil
    end
    return addon:FormatDisplayText(stream, "channel", "chat", {
        streamKey = streamKey,
        streamMeta = {},
    })
end

local function RewriteDisplayChannelPrefix(msg)
    if type(msg) ~= "string" then
        return msg
    end

    local rewritten = msg:gsub("(|Hchannel:([^|]+)|h%[)([^%]]+)(%]|h)", function(prefix, linkTarget, label, suffix)
        local shortLabel = ResolveConfiguredLabel(linkTarget, label)
        if type(shortLabel) == "string" and shortLabel ~= "" then
            return prefix .. shortLabel .. suffix
        end
        return prefix .. label .. suffix
    end)
    return rewritten
end

function Service:EnsureFrameHook(frame)
    if type(frame) ~= "table" or type(frame.AddMessage) ~= "function" then
        return false
    end
    if type(frame._TinyChatonOrigAddMessage) == "function" then
        return true
    end

    local original = frame.AddMessage
    frame._TinyChatonOrigAddMessage = original
    frame.AddMessage = function(self, msg, ...)
        local nextMsg = RewriteDisplayChannelPrefix(msg)
        return original(self, nextMsg, ...)
    end
    return true
end

function Service:DeliverRealtime(frame, event, streamContext, packedArgs, options)
    local shouldHide = type(options) == "table" and options.shouldHide == true
    if shouldHide then
        return true
    end

    if not packedArgs or type(packedArgs[1]) ~= "string" then
        return false, addon.Utils.UnpackArgs(packedArgs)
    end

    local targetFrame = addon.FrameResolver:ResolveRealtime(frame, event)
    if type(targetFrame) == "table" then
        self:EnsureFrameHook(targetFrame)
        local normalized = addon.StreamNormalizeService:NormalizeRealtime(targetFrame, event, streamContext)
        local rendered = normalized and addon.StreamRenderService:RenderRealtime(targetFrame, normalized) or nil
        if type(rendered) == "table" and type(rendered.displayText) == "string" then packedArgs[1] = rendered.displayText end
    end
    return false, addon.Utils.UnpackArgs(packedArgs)
end

function Service:DeliverReplay(line, options)
    local frame = type(options) == "table" and options.frame or nil
    if not frame then frame = addon.FrameResolver:ResolveReplay(line) end
    if type(frame) ~= "table" then
        return false
    end
    self:EnsureFrameHook(frame)

    local normalized = addon.StreamNormalizeService:NormalizeReplay(line, frame)
    if type(normalized) ~= "table" then
        return false
    end

    local rendered = addon.StreamRenderService:RenderReplay(frame, normalized)
    if type(rendered) ~= "table" or type(rendered.displayText) ~= "string" then
        return false
    end

    local addMessageFn = frame.AddMessage
    if type(addMessageFn) ~= "function" then
        return false
    end

    addMessageFn(frame, rendered.displayText, addon.Utils.UnpackArgs(rendered.extraArgs))
    return true
end
