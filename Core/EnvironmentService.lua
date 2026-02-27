local addonName, addon = ...

addon.EnvironmentService = addon.EnvironmentService or {}
local Env = addon.EnvironmentService

local RAID_DIFFICULTIES = {
    [3] = true,   -- 10 Player (legacy)
    [4] = true,   -- 25 Player (legacy)
    [5] = true,   -- 10 Player Heroic (legacy)
    [6] = true,   -- 25 Player Heroic (legacy)
    [14] = true,  -- Normal Raid
    [15] = true,  -- Heroic Raid
    [16] = true,  -- Mythic Raid
    [17] = true,  -- LFR
    [23] = true,  -- Mythic (legacy alias)
    [33] = true,  -- Timewalking Raid
}

local function IsRaidDifficulty(difficultyID)
    return RAID_DIFFICULTIES[difficultyID] == true
end

local function IsMPlusDifficulty(difficultyID)
    return difficultyID == 8
end

function Env:ResolveBaseMode()
    local inInstance, instanceType = IsInInstance()
    if not inInstance then
        return addon.POLICY_MODES.OPEN
    end

    if instanceType == "raid" then
        local config = addon:GetPolicyConfig()
        return config.raidOutOfCombatMode or addon.POLICY_MODES.INSTANCE_RELAXED
    end

    if instanceType == "party" then
        local _, _, difficultyID = GetInstanceInfo()
        if IsMPlusDifficulty(difficultyID) then
            return addon.POLICY_MODES.INSTANCE_LOCKDOWN
        end
        return addon.POLICY_MODES.INSTANCE_RELAXED
    end

    return addon.POLICY_MODES.INSTANCE_RELAXED
end

function Env:OnEvent(event, ...)
    if not addon.PolicyEngine then
        return
    end

    if event == "CHALLENGE_MODE_START" then
        addon.PolicyEngine:SetMode(addon.POLICY_MODES.INSTANCE_LOCKDOWN)
        return
    end

    if event == "CHALLENGE_MODE_COMPLETED" or event == "CHALLENGE_MODE_RESET" then
        local config = addon:GetPolicyConfig()
        addon.PolicyEngine:SetMode(config.mplusPostCompleteMode or addon.POLICY_MODES.INSTANCE_RELAXED)
        return
    end

    if event == "ENCOUNTER_START" then
        local difficultyID = select(3, ...)
        if IsRaidDifficulty(difficultyID) then
            addon.PolicyEngine:SetMode(addon.POLICY_MODES.INSTANCE_LOCKDOWN)
            return
        end
        -- Explicitly return for non-raid encounters to avoid implicit fallthrough.
        return
    end

    if event == "ENCOUNTER_END" then
        local difficultyID = select(3, ...)
        if IsRaidDifficulty(difficultyID) then
            local config = addon:GetPolicyConfig()
            addon.PolicyEngine:SetMode(config.raidOutOfCombatMode or addon.POLICY_MODES.INSTANCE_RELAXED)
            return
        end
        -- Explicitly return for non-raid encounters to avoid implicit fallthrough.
        return
    end

    addon.PolicyEngine:SetMode(self:ResolveBaseMode())
end

function addon:InitEnvironmentService()
    local svc = self.EnvironmentService
    if not svc then
        return
    end

    if not svc.frame then
        svc.frame = CreateFrame("Frame")
        svc.frame:SetScript("OnEvent", function(_, event, ...)
            svc:OnEvent(event, ...)
        end)

        svc.frame:RegisterEvent("PLAYER_ENTERING_WORLD")
        svc.frame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
        svc.frame:RegisterEvent("CHALLENGE_MODE_START")
        svc.frame:RegisterEvent("CHALLENGE_MODE_COMPLETED")
        svc.frame:RegisterEvent("CHALLENGE_MODE_RESET")
        svc.frame:RegisterEvent("ENCOUNTER_START")
        svc.frame:RegisterEvent("ENCOUNTER_END")
    end

    self.PolicyEngine:SetMode(svc:ResolveBaseMode())
end
