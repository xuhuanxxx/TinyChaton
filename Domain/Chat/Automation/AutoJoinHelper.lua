local addonName, addon = ...

-- Module: AutoJoinHelper
-- Helper functions for social automation settings (auto-join channels etc.)
-- Note: Welcome message logic has been moved to Domain/Chat/Automation/AutoWelcome.lua

addon.AutoJoinService = addon.AutoJoinService or {}

local AUTO_JOIN_READY_EVENT = "PLAYER_ENTERING_WORLD"
local AUTO_JOIN_DEFAULT_DELAY_SECONDS = 3
local AUTO_JOIN_MAX_DELAY_SECONDS = 30
local AUTO_JOIN_RETRY_DELAY_SECONDS = 2
local AUTO_JOIN_MAX_RETRIES = 3

local state = {
    featureEnabled = false,
    loginReady = false,
    generation = 0,
    pendingTimer = nil,
}

-- =========================================================================
-- Auto Join Logic
-- =========================================================================
local function NormalizeChannelName(name)
    if type(name) ~= "string" then return nil end
    local trimmed = name:match("^%s*(.-)%s*$")
    if not trimmed or trimmed == "" then return nil end
    return trimmed
end

local function GetDynamicJoinSelectionDB()
    if not addon.db or not addon.db.profile or not addon.db.profile.automation then
        return nil
    end
    local auto = addon.db.profile.automation
    if type(auto.autoJoinDynamicChannels) ~= "table" then
        auto.autoJoinDynamicChannels = {}
    end
    return auto.autoJoinDynamicChannels
end

local function ResolveDynamicChannelName(stream)
    if type(stream) ~= "table" then return nil end
    local dynamic = addon.ResolveDynamicActiveName and addon:ResolveDynamicActiveName(stream, {}) or nil
    if dynamic and dynamic.activeName then
        return NormalizeChannelName(dynamic.activeName)
    end
    local identity = addon.ResolveStreamIdentity and addon:ResolveStreamIdentity(stream, {}) or nil
    return NormalizeChannelName(identity and identity.label or stream.key)
end

function addon:GetAutoJoinDynamicChannelsItems()
    local items = {}
    for _, stream in self:IterateCompiledStreams() do
        local kind = addon:GetStreamKind(stream.key)
        local group = addon:GetStreamGroup(stream.key)
        local caps = addon:GetStreamCapabilities(stream.key)
        if kind == "channel" and group == "dynamic" and type(caps) == "table" and caps.supportsAutoJoin == true then
            local identity = addon.ResolveStreamIdentity and addon:ResolveStreamIdentity(stream, {}) or nil
            local label = (identity and identity.label) or ResolveDynamicChannelName(stream) or stream.key
            table.insert(items, {
                key = stream.key,
                value = stream.key,
                label = label,
                text = label,
            })
        end
    end
    return items
end

local function getAutomationConfig()
    if not addon.db or not addon.db.profile then
        return nil
    end
    return addon.db.profile.automation
end

local function getAutoJoinDelaySeconds()
    local automation = getAutomationConfig() or {}
    local delay = tonumber(automation.autoJoinDelaySeconds)
    if not delay then
        delay = AUTO_JOIN_DEFAULT_DELAY_SECONDS
    end
    if delay < 0 then
        delay = 0
    elseif delay > AUTO_JOIN_MAX_DELAY_SECONDS then
        delay = AUTO_JOIN_MAX_DELAY_SECONDS
    end
    return delay
end

local function isAutoJoinEnabled()
    return addon.db
        and addon.db.enabled
        and state.featureEnabled
        and state.loginReady
        and not (addon.IsChatBypassed and addon:IsChatBypassed())
        and not (addon.Can and not addon:Can(addon.CAPABILITIES.EMIT_CHAT_ACTION))
end

local function cancelPendingTimer()
    local timer = state.pendingTimer
    if timer and timer.Cancel then
        timer:Cancel()
    end
    state.pendingTimer = nil
end

local function getTimerApi()
    return _G.C_Timer
end

local function getChannelNameApi()
    return _G.GetChannelName
end

local function getJoinChannelApi()
    return _G.JoinChannelByName
end

local function scheduleTimer(delaySeconds, callback)
    local timerApi = getTimerApi()
    if timerApi and type(timerApi.NewTimer) == "function" then
        return timerApi.NewTimer(delaySeconds, callback)
    end
    callback()
    return nil
end

function addon:GetAutoJoinDynamicChannelSelection()
    local selectionDB = GetDynamicJoinSelectionDB() or {}
    local selection = {}
    for _, item in ipairs(self:GetAutoJoinDynamicChannelsItems()) do
        selection[item.key] = selectionDB[item.key] == true
    end
    return selection
end

function addon:SetAutoJoinDynamicChannelSelection(selection, opts)
    local selectionDB = GetDynamicJoinSelectionDB()
    if not selectionDB then return end
    table.wipe(selectionDB)
    if type(selection) == "table" then
        for key, enabled in pairs(selection) do
            if enabled == true then
                selectionDB[key] = true
            end
        end
    end
    if not (opts and opts.skipApply) and addon.ExecuteSettingsIntent then
        addon:ExecuteSettingsIntent("auto_join_selection", "automation")
    end
end

local function collectDesiredChannels(self)
    local desired = {}
    local seen = {}

    local function addChannel(channelName)
        local normalized = NormalizeChannelName(channelName)
        if not normalized then return end
        local key = string.lower(normalized)
        if seen[key] then return end
        seen[key] = true
        desired[#desired + 1] = normalized
    end

    local selectedDynamic = self:GetAutoJoinDynamicChannelSelection()
    for _, stream in self:IterateCompiledStreams() do
        local kind = addon:GetStreamKind(stream.key)
        local group = addon:GetStreamGroup(stream.key)
        local caps = addon:GetStreamCapabilities(stream.key)
        if kind == "channel" and group == "dynamic" and type(caps) == "table" and caps.supportsAutoJoin == true and selectedDynamic[stream.key] then
            addChannel(ResolveDynamicChannelName(stream))
        end
    end

    local automation = getAutomationConfig()
    local custom = automation and automation.customAutoJoinChannels
    if type(custom) == "table" then
        for _, rawName in ipairs(custom) do
            addChannel(rawName)
        end
    end

    return desired
end

local function TryJoinChannel(channelName)
    local normalized = NormalizeChannelName(channelName)
    if not normalized then return false end

    local getChannelName = getChannelNameApi()
    local joinChannel = getJoinChannelApi()
    if type(getChannelName) ~= "function" or type(joinChannel) ~= "function" then
        return false
    end

    local joinedId = getChannelName(normalized)
    if not joinedId or joinedId == 0 then
        joinChannel(normalized)
        joinedId = getChannelName(normalized)
    end
    return joinedId and joinedId ~= 0 or false
end

local function performJoinAttempt(self, attempt, generation)
    if generation ~= state.generation then
        return
    end

    state.pendingTimer = nil

    if not isAutoJoinEnabled() then
        return
    end

    local unresolved = {}
    for _, channelName in ipairs(collectDesiredChannels(self)) do
        if not TryJoinChannel(channelName) then
            unresolved[#unresolved + 1] = channelName
        end
    end

    if #unresolved > 0 and attempt < AUTO_JOIN_MAX_RETRIES then
        state.pendingTimer = scheduleTimer(AUTO_JOIN_RETRY_DELAY_SECONDS, function()
            performJoinAttempt(self, attempt + 1, generation)
        end)
    end
end

local function scheduleJoin(self, delaySeconds)
    cancelPendingTimer()

    if not isAutoJoinEnabled() then
        return
    end

    state.generation = state.generation + 1
    local generation = state.generation
    local delay = delaySeconds
    if delay == nil then
        delay = getAutoJoinDelaySeconds()
    end

    if delay <= 0 then
        performJoinAttempt(self, 1, generation)
        return
    end

    state.pendingTimer = scheduleTimer(delay, function()
        performJoinAttempt(self, 1, generation)
    end)
end

local function CommitAutoJoinSettings(self)
    if not self.db or not self.db.profile.automation then
        cancelPendingTimer()
        return
    end

    if not state.loginReady then
        cancelPendingTimer()
        return
    end

    scheduleJoin(self)
end

local function HandleLoginReady()
    if state.loginReady then
        return
    end
    state.loginReady = true
    local service = addon:ResolveRequiredService("AutoJoinService")
    service:Commit()
end

local function RegisterLoginReadyEvent()
    if not addon.RegisterEvent then
        return
    end
    addon:RegisterEvent(AUTO_JOIN_READY_EVENT, HandleLoginReady)
end

local function ResetStateForDisable()
    cancelPendingTimer()
    state.generation = state.generation + 1
end

function addon:GetAutoJoinDelaySeconds()
    return getAutoJoinDelaySeconds()
end

function addon:SetAutoJoinDelaySeconds(value, opts)
    local automation = getAutomationConfig()
    if not automation then return end
    local numeric = tonumber(value) or AUTO_JOIN_DEFAULT_DELAY_SECONDS
    if numeric < 0 then
        numeric = 0
    elseif numeric > AUTO_JOIN_MAX_DELAY_SECONDS then
        numeric = AUTO_JOIN_MAX_DELAY_SECONDS
    end
    automation.autoJoinDelaySeconds = numeric
    if not (opts and opts.skipApply) and addon.ExecuteSettingsIntent then
        addon:ExecuteSettingsIntent("auto_join_delay_change", "automation")
    end
end

function addon.AutoJoinService:HandleLoginReady()
    HandleLoginReady()
end

function addon.AutoJoinService:CancelPending()
    ResetStateForDisable()
end

function addon.AutoJoinService:DebugGetState()
    return {
        featureEnabled = state.featureEnabled,
        loginReady = state.loginReady,
        generation = state.generation,
        hasPendingTimer = state.pendingTimer ~= nil,
    }
end

function addon.AutoJoinService:DebugResetState()
    ResetStateForDisable()
    state.featureEnabled = false
    state.loginReady = false
end

function addon.AutoJoinService:DebugRunPendingTimer()
    local timer = state.pendingTimer
    if not timer or type(timer.callback) ~= "function" then
        return false
    end
    local callback = timer.callback
    state.pendingTimer = nil
    callback()
    return true
end

function addon.AutoJoinService:DebugSetLoginReady(ready)
    state.loginReady = ready == true
    if not state.loginReady then
        ResetStateForDisable()
    end
end

function addon.AutoJoinService:DebugSetFeatureEnabled(enabled)
    state.featureEnabled = enabled == true
    if not state.featureEnabled then
        ResetStateForDisable()
    end
end

local function EnableAutoJoin()
    state.featureEnabled = true
    if state.loginReady then
        local service = addon:ResolveRequiredService("AutoJoinService")
        service:Commit()
    end
end

local function DisableAutoJoin()
    state.featureEnabled = false
    ResetStateForDisable()
    if addon.Debug then
        addon:Debug("AutoJoinHelper disabled; pending auto-join work is cancelled.")
    end
end

function addon:InitAutoJoinHelper()
    RegisterLoginReadyEvent()

    addon:RegisterSettingsSubscriber({
        key = "settings.automation.auto_join",
        phase = "automation",
        priority = 10,
        apply = function(ctx)
            local service = addon:ResolveRequiredService("AutoJoinService")
            service:Commit(ctx)
        end,
    })

    addon:RegisterFeature("AutoJoinHelper", {
        requires = { "EMIT_CHAT_ACTION" },
        plane = addon.RUNTIME_PLANES and addon.RUNTIME_PLANES.CHAT_DATA or "CHAT_DATA",
        onEnable = EnableAutoJoin,
        -- Intentionally no teardown for joined channels:
        -- this feature controls auto-join behavior only and does not roll back player channel state.
        onDisable = DisableAutoJoin,
    })
end

function addon.AutoJoinService:Commit()
    CommitAutoJoinSettings(addon)
end

addon:RegisterModule("AutoJoinHelper", addon.InitAutoJoinHelper)
