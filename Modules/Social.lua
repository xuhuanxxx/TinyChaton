local addonName, addon = ...

-- =========================================================================
-- Social Module
-- Helper functions for social automation settings (auto-join channels etc.)
-- Note: Welcome message logic has been moved to Core/Middleware/Greeting.lua
-- =========================================================================

addon.Social = {}

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
    if not self.db or not self.db.plugin.automation or not self.db.plugin.automation.autoJoinChannels then 
        return {}
    end
    local ajc = self.db.plugin.automation.autoJoinChannels
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
