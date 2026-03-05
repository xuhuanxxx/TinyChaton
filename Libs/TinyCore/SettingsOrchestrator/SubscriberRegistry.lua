local addonName, addon = ...

addon.TinyCoreSettingsSubscriberRegistry = addon.TinyCoreSettingsSubscriberRegistry or {}
local Registry = addon.TinyCoreSettingsSubscriberRegistry
Registry.__index = Registry

local DEFAULT_PHASE_ORDER = { "core", "chat", "automation", "shelf", "ui" }

local function BuildPhaseSet(order)
    local out = {}
    for i, phase in ipairs(order or {}) do
        out[phase] = i
    end
    return out
end

local function ValidateSpec(spec, phaseSet)
    if type(spec) ~= "table" then
        error("Settings subscriber spec must be a table")
    end
    if type(spec.key) ~= "string" or spec.key == "" then
        error("Settings subscriber key must be a non-empty string")
    end
    if type(spec.phase) ~= "string" or not phaseSet[spec.phase] then
        error(string.format("Settings subscriber '%s' has invalid phase '%s'", tostring(spec.key), tostring(spec.phase)))
    end
    if type(spec.priority) ~= "number" then
        error(string.format("Settings subscriber '%s' priority must be a number", tostring(spec.key)))
    end
    if type(spec.apply) ~= "function" then
        error(string.format("Settings subscriber '%s' apply must be a function", tostring(spec.key)))
    end
end

function Registry:New(opts)
    local options = type(opts) == "table" and opts or {}
    local phaseOrder = options.phaseOrder or DEFAULT_PHASE_ORDER
    return setmetatable({
        _byKey = {},
        _phaseOrder = phaseOrder,
        _phaseSet = BuildPhaseSet(phaseOrder),
    }, self)
end

function Registry:GetPhaseOrder()
    return self._phaseOrder
end

function Registry:Register(spec)
    ValidateSpec(spec, self._phaseSet)
    if self._byKey[spec.key] then
        error(string.format("Duplicate settings subscriber key: %s", spec.key))
    end

    self._byKey[spec.key] = {
        key = spec.key,
        phase = spec.phase,
        priority = spec.priority,
        apply = spec.apply,
    }
end

function Registry:Unregister(key)
    if type(key) ~= "string" or key == "" then
        error("Settings subscriber key must be a non-empty string")
    end
    self._byKey[key] = nil
end

function Registry:GetByPhase(phase)
    if type(phase) ~= "string" or not self._phaseSet[phase] then
        error(string.format("Invalid settings phase: %s", tostring(phase)))
    end

    local out = {}
    for _, spec in pairs(self._byKey) do
        if spec.phase == phase then
            out[#out + 1] = spec
        end
    end

    table.sort(out, function(a, b)
        if a.priority == b.priority then
            return a.key < b.key
        end
        return a.priority < b.priority
    end)

    return out
end

function Registry:Validate()
    for key, spec in pairs(self._byKey) do
        ValidateSpec(spec, self._phaseSet)
        if key ~= spec.key then
            error(string.format("Settings subscriber key mismatch: map='%s', spec='%s'", tostring(key), tostring(spec.key)))
        end
    end
end
