local addonName, addon = ...

addon.TinyCoreStreamKindPlugins = addon.TinyCoreStreamKindPlugins or {}
local KindPlugins = addon.TinyCoreStreamKindPlugins
KindPlugins.__index = KindPlugins

function KindPlugins:New(opts)
    local options = type(opts) == "table" and opts or {}
    return setmetatable({
        formatters = {},
        highlighters = {},
        resolveKind = options.resolveKind,
    }, self)
end

function KindPlugins:SetKindResolver(fn)
    if type(fn) ~= "function" then
        error("KindPlugins kind resolver must be a function")
    end
    self.resolveKind = fn
end

function KindPlugins:RegisterFormatter(kind, fn)
    if type(kind) ~= "string" or kind == "" or type(fn) ~= "function" then
        return false
    end
    self.formatters[kind] = fn
    return true
end

function KindPlugins:RegisterHighlighter(kind, fn)
    if type(kind) ~= "string" or kind == "" or type(fn) ~= "function" then
        return false
    end
    self.highlighters[kind] = fn
    return true
end

function KindPlugins:GetFormatter(kind)
    if type(kind) ~= "string" or kind == "" then
        return nil
    end
    return self.formatters[kind]
end

function KindPlugins:ResolveKind(context)
    if type(context) ~= "table" then
        return nil
    end
    if type(context.streamKind) == "string" and context.streamKind ~= "" then
        return context.streamKind
    end
    if type(self.resolveKind) ~= "function" then
        return nil
    end
    local ok, kind = pcall(self.resolveKind, context)
    if ok and type(kind) == "string" and kind ~= "" then
        context.streamKind = kind
        return kind
    end
    return nil
end

function KindPlugins:ApplyHighlighter(context)
    if type(context) ~= "table" then
        return context
    end

    local kind = self:ResolveKind(context)
    local fn = type(kind) == "string" and self.highlighters[kind] or nil
    if type(fn) ~= "function" then
        return context
    end

    local ok, out = pcall(fn, context)
    if ok and type(out) == "table" then
        return out
    end
    return context
end
