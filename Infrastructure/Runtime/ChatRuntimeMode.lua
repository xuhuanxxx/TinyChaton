local addonName, addon = ...

addon.CHAT_RUNTIME_MODE = addon.CHAT_RUNTIME_MODE or {
    ACTIVE = "ACTIVE",
    BYPASS = "BYPASS",
}

addon.RUNTIME_PLANES = addon.RUNTIME_PLANES or {
    CHAT_DATA = "CHAT_DATA",
    USER_ACTION = "USER_ACTION",
    UI_ONLY = "UI_ONLY",
}

local state = addon.ChatRuntimeModeState or {
    mode = addon.CHAT_RUNTIME_MODE.ACTIVE,
    reason = "normal",
}
addon.ChatRuntimeModeState = state

function addon:GetChatRuntimeMode()
    return state.mode or addon.CHAT_RUNTIME_MODE.ACTIVE
end

function addon:IsChatBypassed()
    return self:GetChatRuntimeMode() == addon.CHAT_RUNTIME_MODE.BYPASS
end

function addon:IsPlaneAllowed(plane, enabledWhenBypass)
    if not self:IsChatBypassed() then
        return true
    end
    if enabledWhenBypass == true then
        return true
    end
    local normalized = plane or addon.RUNTIME_PLANES.UI_ONLY
    return normalized ~= addon.RUNTIME_PLANES.CHAT_DATA
end

function addon:SetChatRuntimeMode(mode, reason)
    local nextMode = (mode == addon.CHAT_RUNTIME_MODE.BYPASS) and addon.CHAT_RUNTIME_MODE.BYPASS or addon.CHAT_RUNTIME_MODE.ACTIVE
    local oldMode = state.mode
    local oldReason = state.reason
    if oldMode == nextMode and oldReason == reason then
        return false
    end
    state.mode = nextMode
    state.reason = reason or "normal"

    if self.FireEvent then
        self:FireEvent("CHAT_RUNTIME_MODE_CHANGED", oldMode, nextMode, state.reason)
    end
    return true
end

function addon:GetChatRuntimeReason()
    return state.reason
end

function addon:CanExecuteAction(actionKey)
    if not actionKey then
        return false, "missing_action"
    end
    local action = self.ACTION_REGISTRY and self.ACTION_REGISTRY[actionKey]
    if not action then
        return false, "missing_action"
    end
    if self:IsPlaneAllowed(action.actionPlane, action.enabledWhenBypass) then
        return true
    end
    return false, "bypass_blocked"
end

function addon:InitChatRuntimeMode()
    if not state.mode then
        state.mode = addon.CHAT_RUNTIME_MODE.ACTIVE
        state.reason = "normal"
    end
end
