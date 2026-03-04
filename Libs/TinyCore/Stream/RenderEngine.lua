local addonName, addon = ...

addon.TinyCoreStreamRenderEngine = addon.TinyCoreStreamRenderEngine or {}
local RenderEngine = addon.TinyCoreStreamRenderEngine
RenderEngine.__index = RenderEngine

function RenderEngine:New(opts)
    local options = type(opts) == "table" and opts or {}
    return setmetatable({
        resolveKind = options.resolveKind,
        getFormatter = options.getFormatter,
        fallbackRenderer = options.fallbackRenderer,
    }, self)
end

function RenderEngine:BuildDisplayLine(line, options, helpers)
    if type(line) ~= "table" then
        return nil, 1, 1, 1
    end

    local kind = line.kind
    if (type(kind) ~= "string" or kind == "") and type(self.resolveKind) == "function" then
        local ok, resolvedKind = pcall(self.resolveKind, line)
        if ok and type(resolvedKind) == "string" and resolvedKind ~= "" then
            kind = resolvedKind
            line.kind = resolvedKind
        end
    end

    local formatter = nil
    if type(kind) == "string" and type(self.getFormatter) == "function" then
        formatter = self.getFormatter(kind)
    end

    if type(formatter) ~= "function" then
        if type(self.fallbackRenderer) == "function" then
            return self.fallbackRenderer(line, options)
        end
        return line.text, 1, 1, 1
    end

    return formatter(line, options, helpers)
end
