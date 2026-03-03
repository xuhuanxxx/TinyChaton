local addonName, addon = ...

-- Module: AutoJoinHelper
-- Helper functions for social automation settings (auto-join channels etc.)
-- Note: Welcome message logic has been moved to Domain/Chat/Automation/AutoWelcome.lua

addon.AutoJoinHelper = {}

-- =========================================================================
-- Auto Join Logic
-- =========================================================================
local GetChannelName = GetChannelName
local JoinChannelByName = JoinChannelByName

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
    if not (opts and opts.skipApply) and addon.ApplyAllSettings then
        addon:ApplyAllSettings()
    end
end

local function TryJoinChannel(channelName, joinedByName)
    local normalized = NormalizeChannelName(channelName)
    if not normalized then return end

    local key = string.lower(normalized)
    if joinedByName[key] then return end
    joinedByName[key] = true

    local joinedId = GetChannelName(normalized)
    if not joinedId or joinedId == 0 then
        JoinChannelByName(normalized)
    end
end

function addon:ApplyAutoJoinSettings()
    if not self.db or not self.db.profile.automation then return end
    if addon.IsChatBypassed and addon:IsChatBypassed() then
        return
    end
    if addon.Can and not addon:Can(addon.CAPABILITIES.EMIT_CHAT_ACTION) then
        return
    end

    local joinedByName = {}

    local selectedDynamic = self:GetAutoJoinDynamicChannelSelection()
    for _, stream in self:IterateCompiledStreams() do
        local kind = addon:GetStreamKind(stream.key)
        local group = addon:GetStreamGroup(stream.key)
        local caps = addon:GetStreamCapabilities(stream.key)
        if kind == "channel" and group == "dynamic" and type(caps) == "table" and caps.supportsAutoJoin == true and selectedDynamic[stream.key] then
            TryJoinChannel(ResolveDynamicChannelName(stream), joinedByName)
        end
    end

    local custom = self.db.profile.automation.customAutoJoinChannels
    if type(custom) == "table" then
        for _, rawName in ipairs(custom) do
            TryJoinChannel(rawName, joinedByName)
        end
    end
end

function addon:InitAutoJoinHelper()
    local function EnableAutoJoin()
        addon:ApplyAutoJoinSettings()
    end

    local function DisableAutoJoin()
        if addon.Debug then
            addon:Debug("AutoJoinHelper disabled; joined channels are left unchanged by design.")
        end
    end

    addon:RegisterFeature("AutoJoinHelper", {
        requires = { "EMIT_CHAT_ACTION" },
        plane = addon.RUNTIME_PLANES and addon.RUNTIME_PLANES.CHAT_DATA or "CHAT_DATA",
        onEnable = EnableAutoJoin,
        -- Intentionally no teardown for joined channels:
        -- this feature controls auto-join behavior only and does not roll back player channel state.
        onDisable = DisableAutoJoin,
    })
end

addon:RegisterModule("AutoJoinHelper", addon.InitAutoJoinHelper)
