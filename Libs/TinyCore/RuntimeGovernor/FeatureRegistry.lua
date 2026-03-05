local addonName, addon = ...

addon.TinyCoreRuntimeFeatureRegistry = addon.TinyCoreRuntimeFeatureRegistry or {}
local FeatureRegistry = addon.TinyCoreRuntimeFeatureRegistry
FeatureRegistry.__index = FeatureRegistry

local function CanEnable(entry, deps)
    if not entry then
        return false
    end
    if deps.isPlaneAllowed and not deps.isPlaneAllowed(entry.plane, entry.enabledWhenBypass) then
        return false
    end
    local requires = entry.requires or {}
    for _, capability in ipairs(requires) do
        if deps.can and not deps.can(capability) then
            return false
        end
    end
    return true
end

local function GetSortedEntries(entries)
    local out = {}
    for _, entry in pairs(entries or {}) do
        out[#out + 1] = entry
    end
    table.sort(out, function(a, b)
        return tostring(a.name) < tostring(b.name)
    end)
    return out
end

local function EnableEntry(entry)
    if not entry or entry.enabled then
        return
    end
    if type(entry.onEnable) == "function" then
        local ok, err = pcall(entry.onEnable)
        if not ok then
            entry.enabled = false
            error(string.format("Feature %s enable failed: %s", tostring(entry.name), tostring(err)))
        end
    end
    entry.enabled = true
end

local function DisableEntry(entry)
    if not entry or not entry.enabled then
        return
    end
    if type(entry.onDisable) == "function" then
        local ok, err = pcall(entry.onDisable)
        if not ok then
            entry.enabled = true
            error(string.format("Feature %s disable failed: %s", tostring(entry.name), tostring(err)))
        end
    end
    entry.enabled = false
end

function FeatureRegistry:New(opts)
    local options = type(opts) == "table" and opts or {}
    return setmetatable({
        entries = options.entries or {},
    }, self)
end

function FeatureRegistry:Register(name, spec)
    if not name or name == "" or type(spec) ~= "table" then
        return
    end
    local entry = self.entries[name]
    if not entry then
        entry = {
            name = name,
            enabled = false,
        }
        self.entries[name] = entry
    end
    entry.requires = spec.requires or {}
    entry.plane = spec.plane or "UI_ONLY"
    entry.enabledWhenBypass = spec.enabledWhenBypass == true
    entry.onEnable = spec.onEnable
    entry.onDisable = spec.onDisable
end

function FeatureRegistry:DisableByPlane(plane)
    for _, entry in ipairs(GetSortedEntries(self.entries)) do
        if plane == nil or entry.plane == plane then
            DisableEntry(entry)
        end
    end
end

function FeatureRegistry:Reconcile(deps, options)
    local opts = type(options) == "table" and options or {}
    if opts.teardownAll == true then
        self:DisableByPlane(nil)
    elseif opts.teardownPlane then
        self:DisableByPlane(opts.teardownPlane)
    end

    local dependencyFns = type(deps) == "table" and deps or {}
    for _, entry in ipairs(GetSortedEntries(self.entries)) do
        if CanEnable(entry, dependencyFns) then
            EnableEntry(entry)
        else
            DisableEntry(entry)
        end
    end
end

function FeatureRegistry:IsEnabled(name)
    local entry = self.entries and self.entries[name]
    return entry and entry.enabled or false
end
