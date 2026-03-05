local addonName, addon = ...

addon.TinyCoreSettingsSchemaRegistry = addon.TinyCoreSettingsSchemaRegistry or {}
local SchemaRegistry = addon.TinyCoreSettingsSchemaRegistry
SchemaRegistry.__index = SchemaRegistry

function SchemaRegistry:New(opts)
    local options = type(opts) == "table" and opts or {}
    return setmetatable({
        getStaticRegistry = options.getStaticRegistry,
        getRuntimeRegistry = options.getRuntimeRegistry,
    }, self)
end

function SchemaRegistry:_static()
    if type(self.getStaticRegistry) == "function" then
        local reg = self.getStaticRegistry()
        return type(reg) == "table" and reg or {}
    end
    return {}
end

function SchemaRegistry:_runtime()
    if type(self.getRuntimeRegistry) == "function" then
        local reg = self.getRuntimeRegistry()
        return type(reg) == "table" and reg or {}
    end
    return {}
end

function SchemaRegistry:GetByKey(key)
    local staticReg = self:_static()[key]
    if staticReg ~= nil then
        return staticReg
    end
    return self:_runtime()[key]
end

function SchemaRegistry:GetAll()
    local merged = {}
    for k, reg in pairs(self:_static()) do
        merged[k] = reg
    end
    for k, reg in pairs(self:_runtime()) do
        if merged[k] == nil then
            merged[k] = reg
        end
    end
    return merged
end
