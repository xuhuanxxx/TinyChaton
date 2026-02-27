local addonName, addon = ...

-- =========================================================================
-- Module: AutoJoinHelper (formerly Social)
-- Helper functions for social automation settings (auto-join channels etc.)
-- Note: Welcome message logic has been moved to Core/Middleware/Greeting.lua
-- =========================================================================

addon.AutoJoinHelper = {}

-- =========================================================================
-- Auto Join Logic
-- =========================================================================

local function NormalizeChannelName(name)
    if type(name) ~= "string" then return nil end
    local trimmed = name:match("^%s*(.-)%s*$")
    if not trimmed or trimmed == "" then return nil end
    return trimmed
end

function addon:ApplyAutomationSettings()
    if not self.db or not self.db.plugin.automation then return end
    if addon.Can and not addon:Can(addon.CAPABILITIES.EMIT_CHAT_ACTION) then
        return
    end

    -- Auto-join is intentionally narrowed to explicit custom channel names only.
    local custom = self.db.plugin.automation.customAutoJoinChannels
    if type(custom) == "table" then
        for _, rawName in ipairs(custom) do
            local channelName = NormalizeChannelName(rawName)
            if channelName then
                if addon.ActionJoin then
                    addon:ActionJoin(channelName)
                else
                    JoinChannelByName(channelName)
                end
            end
        end
    end
end

function addon:InitAutoJoinHelper()
    local function EnableAutoJoin()
        addon:ApplyAutomationSettings()
    end

    if addon.RegisterFeature then
        addon:RegisterFeature("AutoJoinHelper", {
            requires = { "EMIT_CHAT_ACTION" },
            onEnable = EnableAutoJoin,
            -- Intentionally no teardown for joined channels:
            -- this feature controls auto-join behavior only and does not roll back player channel state.
            onDisable = function() end,
        })
    else
        EnableAutoJoin()
    end
end

-- P0: Register Module
addon:RegisterModule("AutoJoinHelper", addon.InitAutoJoinHelper)
