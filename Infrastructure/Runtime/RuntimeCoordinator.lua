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
    if not addon.EnvGate or not addon.SetChatRuntimeMode then
        return
    end
    local mode, reason = addon.EnvGate:ResolveMode()
    local changed = addon:SetChatRuntimeMode(mode, reason)
    if changed and addon.DisableFeaturesByPlane then
        addon:DisableFeaturesByPlane(addon.RUNTIME_PLANES and addon.RUNTIME_PLANES.CHAT_DATA or "CHAT_DATA")
    end
    if changed and addon.ReconcileFeatures then
        addon:ReconcileFeatures()
    end
    if changed and addon.RefreshShelf then
        addon:RefreshShelf()
    end
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
