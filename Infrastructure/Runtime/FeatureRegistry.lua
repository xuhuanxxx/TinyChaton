local addonName, addon = ...

if not addon.TinyCoreRuntimeFeatureRegistry or type(addon.TinyCoreRuntimeFeatureRegistry.New) ~= "function" then
    error("TinyCore Runtime FeatureRegistry is not initialized")
end

addon.FeatureRegistry = addon.FeatureRegistry or addon.TinyCoreRuntimeFeatureRegistry:New({
    entries = {},
})
local Registry = addon.FeatureRegistry

function addon:RegisterFeature(name, spec)
    local finalSpec = type(spec) == "table" and spec or {}
    if finalSpec.plane == nil then
        finalSpec.plane = (addon.RUNTIME_PLANES and addon.RUNTIME_PLANES.UI_ONLY) or "UI_ONLY"
    end
    Registry:Register(name, finalSpec)
end

function addon:DisableFeaturesByPlane(plane)
    Registry:DisableByPlane(plane)
end

function addon:ReconcileFeatures(options)
    Registry:Reconcile({
        can = function(capability)
            return addon:Can(capability)
        end,
        isPlaneAllowed = function(plane, enabledWhenBypass)
            if addon.IsPlaneAllowed then
                return addon:IsPlaneAllowed(plane, enabledWhenBypass)
            end
            return true
        end,
    }, options)
end

function addon:IsFeatureEnabled(name)
    return Registry:IsEnabled(name)
end

function addon:InitFeatureRegistry()
    self:RegisterCallback("CHAT_RUNTIME_MODE_CHANGED", function()
        if addon.ReconcileFeatures then
            addon:ReconcileFeatures()
        end
    end, "FeatureRegistry")

    self:ReconcileFeatures()
end
