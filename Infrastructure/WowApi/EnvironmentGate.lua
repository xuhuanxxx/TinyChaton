local addonName, addon = ...

addon.EnvGate = addon.EnvGate or {}
local Gate = addon.EnvGate

Gate.rules = Gate.rules or {
    {
        key = "mythic_plus_active",
        enabled = true,
        evaluate = function()
            local inInstance, instanceType = IsInInstance()
            if not inInstance or instanceType ~= "party" then
                return false
            end
            local _, _, difficultyID = GetInstanceInfo()
            if difficultyID ~= 8 then
                return false
            end
            if C_ChallengeMode and C_ChallengeMode.IsChallengeModeActive then
                return C_ChallengeMode.IsChallengeModeActive() == true
            end
            return false
        end,
        mode = function()
            return addon.CHAT_RUNTIME_MODE.BYPASS, "mplus_active"
        end,
    },
    {
        key = "raid_instance",
        enabled = true,
        evaluate = function()
            local inInstance, instanceType = IsInInstance()
            return inInstance == true and instanceType == "raid"
        end,
        mode = function()
            return addon.CHAT_RUNTIME_MODE.BYPASS, "raid_instance"
        end,
    },
}

function Gate:ResolveMode()
    for _, rule in ipairs(self.rules or {}) do
        if rule and rule.enabled ~= false and type(rule.evaluate) == "function" then
            local ok, matched = pcall(rule.evaluate)
            if ok and matched == true then
                if type(rule.mode) == "function" then
                    local mode, reason = rule.mode()
                    return mode or addon.CHAT_RUNTIME_MODE.BYPASS, reason or rule.key
                end
                return addon.CHAT_RUNTIME_MODE.BYPASS, rule.key
            end
        end
    end
    return addon.CHAT_RUNTIME_MODE.ACTIVE, "normal"
end

function addon:InitEnvironmentGate()
    if not self.EnvGate then
        self.EnvGate = Gate
    end
end
