local addonName, addon = ...

-- =========================================================================
-- Module: AutoJoinHelper (formerly Social)
-- Helper functions for social automation settings (auto-join channels etc.)
-- Note: Welcome message logic has been moved to Core/Middleware/Greeting.lua
-- =========================================================================

addon.AutoJoinHelper = {}

-- Auto Join Channels Configuration Helpers

function addon:GetAutoJoinChannelsItems()
    local items = {}
    for _, stream, catKey, subKey in addon:IterateAllStreams() do
        if subKey == "DYNAMIC" then
            table.insert(items, { 
                key = stream.key, 
                label = stream.label or stream.key,
                value = stream.key,
                text = stream.label or stream.key,
            })
        end
    end
    return items
end

function addon:GetAutoJoinChannelSelection()
    local ajc = self:GetConfig("plugin.automation.autoJoinChannels")
    if not ajc then 
        return {}
    end
    local items = self:GetAutoJoinChannelsItems()
    local selection = {}
    for _, item in ipairs(items) do
        selection[item.key] = (ajc[item.key] ~= false)
    end
    return selection
end

function addon:SetAutoJoinChannelSelection(selection)
    if not self.db or not self.db.plugin.automation then 
        return
    end
    if not self.db.plugin.automation.autoJoinChannels then
        self.db.plugin.automation.autoJoinChannels = {}
    end
    local ajc = self.db.plugin.automation.autoJoinChannels
    local items = self:GetAutoJoinChannelsItems()
    
    for _, item in ipairs(items) do
        ajc[item.key] = selection[item.key] and true or false
    end
    
    if addon.ApplyAllSettings then addon:ApplyAllSettings() end
end

-- =========================================================================
-- Auto Join Logic
-- =========================================================================

local function GetStreamChannelName(stream)
    if not stream then return nil end
    -- Check for mapping key (localized channel name key)
    if stream.mappingKey and addon.L and addon.L[stream.mappingKey] then
        return addon.L[stream.mappingKey]
    end
    return stream.key
end

function addon:ApplyAutomationSettings()
    if not self.db or not self.db.plugin.automation then return end
    
    -- Auto Join Channels
    local ajc = self.db.plugin.automation.autoJoinChannels
    if ajc then
        for _, stream, _, subKey in self:IterateAllStreams() do
            if subKey == "DYNAMIC" then
                -- Join if explicitly enabled (true) or simplified check
                -- Default behavior is handled by Config.lua populating the DB
                if ajc[stream.key] then
                    local channelName = GetStreamChannelName(stream)
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
    end
end

function addon:InitAutoJoinHelper()
    addon:ApplyAutomationSettings()
end

-- P0: Register Module
addon:RegisterModule("AutoJoinHelper", addon.InitAutoJoinHelper)
