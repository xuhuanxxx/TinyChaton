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

function addon:InitStreamHighlight()
    addon:RegisterFeature("StreamHighlight", {
        requires = { "MUTATE_CHAT_DISPLAY" },
        plane = addon.RUNTIME_PLANES and addon.RUNTIME_PLANES.CHAT_DATA or "CHAT_DATA",
        onEnable = function() end,
        onDisable = function() end,
    })
end

addon:RegisterModule("StreamHighlight", addon.InitStreamHighlight)
