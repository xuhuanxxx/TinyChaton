local addonName, addon = ...

addon.StreamHighlighter = addon.StreamHighlighter or {}
local Highlighter = addon.StreamHighlighter

Highlighter.kindHighlighters = Highlighter.kindHighlighters or {}

function Highlighter:RegisterKindHighlighter(kind, fn)
    if type(kind) ~= "string" or kind == "" or type(fn) ~= "function" then
        return false
    end
    self.kindHighlighters[kind] = fn
    return true
end

local function ResolveKind(streamKey)
    if type(streamKey) ~= "string" or streamKey == "" then
        return nil
    end
    if not addon.GetStreamKind then
        return nil
    end
    return addon:GetStreamKind(streamKey)
end

function Highlighter:Apply(context)
    if type(context) ~= "table" then
        return context
    end
    local kind = context.streamKind
    if (type(kind) ~= "string" or kind == "") and type(context.streamKey) == "string" then
        kind = ResolveKind(context.streamKey)
        context.streamKind = kind
    end

    local fn = type(kind) == "string" and self.kindHighlighters[kind] or nil
    if type(fn) ~= "function" then
        return context
    end

    local ok, out = pcall(fn, context)
    if ok and type(out) == "table" then
        return out
    end

    return context
end

function Highlighter:ApplyDisplayText(text, streamKey)
    local context = {
        text = text,
        streamKey = streamKey,
        streamKind = ResolveKind(streamKey),
    }
    local out = self:Apply(context)
    return out and out.text or text
end

local function DisplayTransformer(frame, text, r, g, b, extraArgs)
    if not addon.db or not addon.db.enabled then
        return text, r, g, b, extraArgs
    end

    local streamKey = type(extraArgs) == "table" and extraArgs.streamKey or nil
    if (type(streamKey) ~= "string" or streamKey == "") and type(text) == "string" then
        streamKey = text:match("|Htinychat:send:([^|]+)|h")
    end

    local nextText = addon.StreamHighlighter:ApplyDisplayText(text, streamKey)
    return nextText, r, g, b, extraArgs
end

function addon:InitStreamHighlight()
    local function EnableStreamHighlight()
        addon:RegisterChatFrameTransformer("display_highlight", DisplayTransformer)
    end

    local function DisableStreamHighlight()
        addon.chatFrameTransformers["display_highlight"] = nil
    end

    addon:RegisterFeature("StreamHighlight", {
        requires = { "MUTATE_CHAT_DISPLAY" },
        plane = addon.RUNTIME_PLANES and addon.RUNTIME_PLANES.CHAT_DATA or "CHAT_DATA",
        onEnable = EnableStreamHighlight,
        onDisable = DisableStreamHighlight,
    })
end

addon:RegisterModule("StreamHighlight", addon.InitStreamHighlight)
