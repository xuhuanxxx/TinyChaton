local addonName, addon = ...

addon.PolicyEngine = addon.PolicyEngine or {}
local Policy = addon.PolicyEngine

local POLICY_DEFAULT_CONFIG = {
    mplusPostCompleteMode = "INSTANCE_RELAXED",
    raidOutOfCombatMode = "INSTANCE_RELAXED",
}

addon.CAPABILITIES = {
    READ_CHAT_EVENT = "READ_CHAT_EVENT",
    PROCESS_CHAT_DATA = "PROCESS_CHAT_DATA",
    PERSIST_CHAT_DATA = "PERSIST_CHAT_DATA",
    MUTATE_CHAT_DISPLAY = "MUTATE_CHAT_DISPLAY",
    EMIT_CHAT_ACTION = "EMIT_CHAT_ACTION",
}

addon.POLICY_MODES = {
    OPEN = "OPEN",
    INSTANCE_RELAXED = "INSTANCE_RELAXED",
    INSTANCE_LOCKDOWN = "INSTANCE_LOCKDOWN",
}

Policy.matrix = {
    OPEN = {
        READ_CHAT_EVENT = true,
        PROCESS_CHAT_DATA = true,
        PERSIST_CHAT_DATA = true,
        MUTATE_CHAT_DISPLAY = true,
        EMIT_CHAT_ACTION = true,
    },
    INSTANCE_RELAXED = {
        READ_CHAT_EVENT = true,
        PROCESS_CHAT_DATA = true,
        PERSIST_CHAT_DATA = true,
        MUTATE_CHAT_DISPLAY = true,
        EMIT_CHAT_ACTION = false,
    },
    INSTANCE_LOCKDOWN = {
        READ_CHAT_EVENT = false,
        PROCESS_CHAT_DATA = false,
        PERSIST_CHAT_DATA = false,
        MUTATE_CHAT_DISPLAY = false,
        EMIT_CHAT_ACTION = false,
    },
}

Policy.currentMode = Policy.currentMode or addon.POLICY_MODES.OPEN

local function NormalizePolicyMode(mode, fallback)
    if mode == addon.POLICY_MODES.INSTANCE_LOCKDOWN or mode == addon.POLICY_MODES.INSTANCE_RELAXED then
        return mode
    end
    return fallback
end

local function NormalizePolicyConfig(policyTable)
    policyTable = policyTable or {}
    policyTable.mplusPostCompleteMode = NormalizePolicyMode(
        policyTable.mplusPostCompleteMode,
        POLICY_DEFAULT_CONFIG.mplusPostCompleteMode
    )
    policyTable.raidOutOfCombatMode = NormalizePolicyMode(
        policyTable.raidOutOfCombatMode,
        POLICY_DEFAULT_CONFIG.raidOutOfCombatMode
    )
    return policyTable
end

function addon:GetPolicyConfig()
    local globalDb = self.db and self.db.account
    if not globalDb then
        return {
            mplusPostCompleteMode = POLICY_DEFAULT_CONFIG.mplusPostCompleteMode,
            raidOutOfCombatMode = POLICY_DEFAULT_CONFIG.raidOutOfCombatMode,
        }
    end

    return globalDb.policy or {
        mplusPostCompleteMode = POLICY_DEFAULT_CONFIG.mplusPostCompleteMode,
        raidOutOfCombatMode = POLICY_DEFAULT_CONFIG.raidOutOfCombatMode,
    }
end

function Policy:SetMode(mode)
    if not mode or not self.matrix[mode] then
        return false
    end

    local oldMode = self.currentMode
    if oldMode == mode then
        return false
    end

    self.currentMode = mode

    if addon.FireEvent then
        addon:FireEvent("POLICY_MODE_CHANGED", oldMode, mode)
    end

    return true
end

function Policy:GetMode()
    return self.currentMode or addon.POLICY_MODES.OPEN
end

function Policy:Can(capability)
    local mode = self:GetMode()
    local row = self.matrix[mode]
    if not row then
        return true
    end

    return row[capability] == true
end

function addon:Can(capability)
    if not capability then
        return true
    end
    if not self.PolicyEngine then
        return true
    end
    return self.PolicyEngine:Can(capability)
end

function addon:EmitChatMessage(text, chatType, language, target)
    if self.Gateway and self.Gateway.Outbound and self.Gateway.Outbound.SendChat then
        return self.Gateway.Outbound:SendChat(text, chatType, language, target)
    end

    if not self:Can(self.CAPABILITIES.EMIT_CHAT_ACTION) then
        return false
    end

    SendChatMessage(text, chatType, language, target)
    return true
end

function addon:InitPolicyEngine()
    if not self.PolicyEngine then
        return
    end

    local mode = self.PolicyEngine:GetMode()
    if not self.PolicyEngine.matrix[mode] then
        self.PolicyEngine.currentMode = addon.POLICY_MODES.OPEN
    end

    -- Ensure policy config exists and normalize once at init time.
    if self.db and self.db.account then
        self.db.account.policy = NormalizePolicyConfig(self.db.account.policy)
    end
end
