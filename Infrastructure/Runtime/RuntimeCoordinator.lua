local addonName, addon = ...

addon.RuntimeCoordinator = addon.RuntimeCoordinator or {}
local Coordinator = addon.RuntimeCoordinator

local WATCHED_EVENTS = {
    "PLAYER_ENTERING_WORLD",
    "ZONE_CHANGED_NEW_AREA",
    "CHALLENGE_MODE_START",
    "CHALLENGE_MODE_COMPLETED",
    "CHALLENGE_MODE_RESET",
}

function Coordinator:RefreshMode()
    if not self.reconciler then
        if not addon.TinyCoreRuntimeReconciler or type(addon.TinyCoreRuntimeReconciler.New) ~= "function" then
            error("TinyCore Runtime Reconciler is not initialized")
        end
        self.reconciler = addon.TinyCoreRuntimeReconciler:New({
            resolveMode = function()
                if not addon.EnvGate or type(addon.EnvGate.ResolveMode) ~= "function" then
                    return nil, nil
                end
                return addon.EnvGate:ResolveMode()
            end,
            setMode = function(mode, reason)
                if not addon.SetChatRuntimeMode then
                    return false
                end
                return addon:SetChatRuntimeMode(mode, reason)
            end,
            onModeChanged = function()
                if addon.DisableFeaturesByPlane then
                    addon:DisableFeaturesByPlane(addon.RUNTIME_PLANES and addon.RUNTIME_PLANES.CHAT_DATA or "CHAT_DATA")
                end
                if addon.ReconcileFeatures then
                    addon:ReconcileFeatures()
                end
            end,
            onAfterReconcile = function()
                if addon.RefreshShelf then
                    addon:RefreshShelf()
                end
            end,
        })
    end
    self.reconciler:RefreshMode()
end

function Coordinator:OnEvent(event, ...)
    self:RefreshMode()
end

function addon:InitRuntimeCoordinator()
    local svc = self.RuntimeCoordinator
    if not svc then
        return
    end
    if not svc.frame then
        svc.frame = CreateFrame("Frame")
        svc.frame:SetScript("OnEvent", function(_, event, ...)
            svc:OnEvent(event, ...)
        end)
        for _, event in ipairs(WATCHED_EVENTS) do
            svc.frame:RegisterEvent(event)
        end
    end
    svc:RefreshMode()
end
