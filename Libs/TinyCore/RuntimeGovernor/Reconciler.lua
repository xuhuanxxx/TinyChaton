local addonName, addon = ...

addon.TinyCoreRuntimeReconciler = addon.TinyCoreRuntimeReconciler or {}
local Reconciler = addon.TinyCoreRuntimeReconciler
Reconciler.__index = Reconciler

function Reconciler:New(opts)
    local options = type(opts) == "table" and opts or {}
    return setmetatable({
        resolveMode = options.resolveMode,
        setMode = options.setMode,
        onModeChanged = options.onModeChanged,
        onAfterReconcile = options.onAfterReconcile,
    }, self)
end

function Reconciler:RefreshMode()
    if type(self.resolveMode) ~= "function" or type(self.setMode) ~= "function" then
        return false
    end
    local mode, reason = self.resolveMode()
    local changed = self.setMode(mode, reason) == true
    if changed and type(self.onModeChanged) == "function" then
        self.onModeChanged(mode, reason)
    end
    if changed and type(self.onAfterReconcile) == "function" then
        self.onAfterReconcile(mode, reason)
    end
    return changed
end
