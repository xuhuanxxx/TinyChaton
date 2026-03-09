local addonName, addon = ...
local L = addon.L

addon.StreamSelectionSupport = addon.StreamSelectionSupport or {}
local Support = addon.StreamSelectionSupport

function Support:IsStreamInFilter(stream, filter)
    if type(stream) ~= "table" then
        return false
    end

    local group = addon:GetStreamGroup(stream.key)
    local kind = addon:GetStreamKind(stream.key)
    if filter == "private" then
        return group == "private"
    end
    if filter == "system" then
        return kind == "channel" and group == "system"
    end
    if filter == "dynamic" then
        return kind == "channel" and group == "dynamic"
    end
    if filter == "notice" then
        return kind == "notice"
    end
    return filter == nil
end

function Support:BuildItems(filter, includePredicate)
    local items = {}
    for _, stream in addon:IterateCompiledStreams() do
        if includePredicate(stream) and self:IsStreamInFilter(stream, filter) then
            local identity = addon.ResolveStreamIdentity and addon:ResolveStreamIdentity(stream, {}) or nil
            local label = (identity and identity.label) or stream.key
            table.insert(items, {
                key = stream.key,
                label = label,
                value = stream.key,
                text = label,
            })
        end
    end

    return items
end

function addon:GetCopyStreamsItems(filter)
    return Support:BuildItems(filter, function(stream)
        return addon:GetStreamCapabilities(stream.key) ~= nil
    end)
end

function addon:GetCopyStreamSelection(filter)
    local interaction = self.db and self.db.profile and self.db.profile.chat and self.db.profile.chat.interaction
    local configured = interaction and interaction.copyStreams or nil
    local items = self:GetCopyStreamsItems(filter)
    local selection = {}
    for _, item in ipairs(items) do
        selection[item.key] = addon:ResolveStreamToggle(item.key, configured, "copyDefault", true)
    end
    return selection
end

function addon:SetCopyStreamSelection(filter, selection, opts)
    if not self.db or not self.db.profile or not self.db.profile.chat or not self.db.profile.chat.interaction then
        return
    end

    local interaction = self.db.profile.chat.interaction
    if type(interaction.copyStreams) ~= "table" then
        interaction.copyStreams = {}
    end

    local copyStreams = interaction.copyStreams
    local items = self:GetCopyStreamsItems(filter)
    for _, item in ipairs(items) do
        copyStreams[item.key] = selection[item.key] and true or false
    end

    if not (opts and opts.skipApply) and addon.ExecuteSettingsIntent then
        addon:ExecuteSettingsIntent()
    end
end

function addon:GetCopyStreamsSummary()
    local interaction = self.db and self.db.profile and self.db.profile.chat and self.db.profile.chat.interaction
    if not interaction then
        return L["LABEL_SNAPSHOT_CHANNELS_ALL"]
    end

    local configured = interaction.copyStreams
    local items = self:GetCopyStreamsItems()
    local selected = {}
    for _, item in ipairs(items) do
        local enabled = addon:ResolveStreamToggle(item.key, configured, "copyDefault", true)
        if enabled then
            selected[#selected + 1] = item.label
        end
    end

    if #selected >= #items then return L["LABEL_SNAPSHOT_CHANNELS_ALL"] end
    if #selected == 0 then return L["LABEL_SNAPSHOT_CHANNELS_NONE"] end
    return table.concat(selected, "、")
end
