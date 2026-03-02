local addonName, addon = ...

addon.FeatureRegistry = addon.FeatureRegistry or {
    entries = {},
}

local Registry = addon.FeatureRegistry

function addon:RegisterFeature(name, spec)
    if not name or name == "" or type(spec) ~= "table" then
        return
    end

    local entry = Registry.entries[name]
    if not entry then
        entry = {
            name = name,
            enabled = false,
        }
        Registry.entries[name] = entry
    end

    entry.requires = spec.requires or {}
    entry.plane = spec.plane or (addon.RUNTIME_PLANES and addon.RUNTIME_PLANES.UI_ONLY) or "UI_ONLY"
    entry.enabledWhenBypass = spec.enabledWhenBypass == true
    entry.onEnable = spec.onEnable
    entry.onDisable = spec.onDisable
end

local function CanEnable(entry)
    if not entry then return false end
    if addon.IsPlaneAllowed and not addon:IsPlaneAllowed(entry.plane, entry.enabledWhenBypass) then
        return false
    end
    local requires = entry.requires or {}
    for _, capability in ipairs(requires) do
        if not addon:Can(capability) then
            return false
        end
    end
    return true
end

local function GetSortedEntries()
    local entries = {}
    for _, entry in pairs(Registry.entries) do
        entries[#entries + 1] = entry
    end
    table.sort(entries, function(a, b)
        return tostring(a.name) < tostring(b.name)
    end)
    return entries
end

local function EnableEntry(entry)
    if not entry or entry.enabled then return end
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
    if not entry or not entry.enabled then return end
    if type(entry.onDisable) == "function" then
        local ok, err = pcall(entry.onDisable)
        if not ok then
            entry.enabled = true
            error(string.format("Feature %s disable failed: %s", tostring(entry.name), tostring(err)))
        end
    end
    entry.enabled = false
end

function addon:DisableFeaturesByPlane(plane)
    for _, entry in ipairs(GetSortedEntries()) do
        if plane == nil or entry.plane == plane then
            DisableEntry(entry)
        end
    end
end

function addon:ReconcileFeatures(options)
    local opts = type(options) == "table" and options or {}
    if opts.teardownAll == true then
        self:DisableFeaturesByPlane(nil)
    elseif opts.teardownPlane then
        self:DisableFeaturesByPlane(opts.teardownPlane)
    end

    for _, entry in ipairs(GetSortedEntries()) do
        if CanEnable(entry) then
            EnableEntry(entry)
        else
            DisableEntry(entry)
        end
    end
end

function addon:IsFeatureEnabled(name)
    local entry = Registry.entries and Registry.entries[name]
    return entry and entry.enabled or false
end

function addon:InitFeatureRegistry()
    self:RegisterCallback("CHAT_RUNTIME_MODE_CHANGED", function()
        if addon.ReconcileFeatures then
            addon:ReconcileFeatures()
        end
    end, "FeatureRegistry")

    self:ReconcileFeatures()
end
