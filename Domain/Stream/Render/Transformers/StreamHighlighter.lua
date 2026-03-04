local addonName, addon = ...

addon.StreamHighlighter = addon.StreamHighlighter or {}
local Highlighter = addon.StreamHighlighter

local function ResolveKindFromContext(context)
    local streamKey = type(context) == "table" and context.streamKey or nil
    if type(streamKey) ~= "string" or streamKey == "" then
        return nil
    end
    return addon.GetStreamKind and addon:GetStreamKind(streamKey) or nil
end

local function EnsureKindPlugins()
    if addon._tinyCoreStreamKindPlugins then
        return addon._tinyCoreStreamKindPlugins
    end
    if not addon.TinyCoreStreamKindPlugins or type(addon.TinyCoreStreamKindPlugins.New) ~= "function" then
        error("TinyCore Stream KindPlugins is not initialized")
    end
    addon._tinyCoreStreamKindPlugins = addon.TinyCoreStreamKindPlugins:New({
        resolveKind = ResolveKindFromContext,
    })
    return addon._tinyCoreStreamKindPlugins
end

Highlighter.kindHighlighters = EnsureKindPlugins().highlighters

function Highlighter:RegisterKindHighlighter(kind, fn)
    return EnsureKindPlugins():RegisterHighlighter(kind, fn)
end

function Highlighter:Apply(context)
    return EnsureKindPlugins():ApplyHighlighter(context)
end

function Highlighter:ApplyDisplayText(text, streamKey)
    local context = {
        text = text,
        streamKey = streamKey,
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
