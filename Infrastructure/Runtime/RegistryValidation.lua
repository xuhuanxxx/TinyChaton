local addonName, addon = ...

local function AssertNonEmptyString(value, label)
    if type(value) ~= "string" or value == "" then
        error(string.format("%s must be a non-empty string", tostring(label)))
    end
end

local function AssertPriority(item, label)
    if type(item) ~= "table" then
        error(string.format("%s must be a table", tostring(label)))
    end
    if type(item.priority) ~= "number" then
        error(string.format("%s.priority must be a number", tostring(label)))
    end
end

local function AssertBooleanField(value, label)
    if type(value) ~= "boolean" then
        error(string.format("%s must be boolean", tostring(label)))
    end
end

local function ValidateStreamCapabilities(capabilities, sourceLabel)
    if type(capabilities) ~= "table" then
        error(sourceLabel .. ".capabilities must be table")
    end
    AssertBooleanField(capabilities.inbound, sourceLabel .. ".capabilities.inbound")
    AssertBooleanField(capabilities.outbound, sourceLabel .. ".capabilities.outbound")
    AssertBooleanField(capabilities.snapshotDefault, sourceLabel .. ".capabilities.snapshotDefault")
    AssertBooleanField(capabilities.copyDefault, sourceLabel .. ".capabilities.copyDefault")
    AssertBooleanField(capabilities.supportsMute, sourceLabel .. ".capabilities.supportsMute")
    AssertBooleanField(capabilities.supportsAutoJoin, sourceLabel .. ".capabilities.supportsAutoJoin")
    AssertBooleanField(capabilities.pinnable, sourceLabel .. ".capabilities.pinnable")
end

local ALLOWED_KIND = {
    channel = true,
    notice = true,
}

local ALLOWED_GROUP = {
    system = true,
    dynamic = true,
    private = true,
    alert = true,
    log = true,
}

local function ResolveChannelBindingActionKey(streamKey, bindingKey, actionSet)
    if actionSet[bindingKey] then
        return bindingKey
    end
    if bindingKey == "send" then
        return "send_" .. streamKey
    end
    if bindingKey == "mute_toggle" then
        return "mute_toggle_" .. streamKey
    end
    return "channel_" .. streamKey .. "_" .. bindingKey
end

local function ResolveKitBindingActionKey(kitKey, bindingKey, actionSet)
    if actionSet[bindingKey] then
        return bindingKey
    end
    return "kit_" .. kitKey .. "_" .. bindingKey
end

local function BuildActionKeySet()
    local actionSet = {}
    if addon.BuildActionRegistryFromDefinitions then
        local registry = addon:BuildActionRegistryFromDefinitions() or {}
        for actionKey in pairs(registry) do
            actionSet[actionKey] = true
        end
    end
    return actionSet
end

local function WarnDuplicatePriority(groupKey, priority, firstKey, secondKey)
    if addon.WarnOnce then
        addon:WarnOnce(
            "registry_validation:dup_priority:" .. tostring(groupKey) .. ":" .. tostring(priority),
            "Duplicate priority %s in %s (%s vs %s)",
            tostring(priority),
            tostring(groupKey),
            tostring(firstKey),
            tostring(secondKey)
        )
    elseif addon.Warn then
        addon:Warn(
            "Duplicate priority %s in %s (%s vs %s)",
            tostring(priority),
            tostring(groupKey),
            tostring(firstKey),
            tostring(secondKey)
        )
    end
end

local function ValidateBindings(bindings, resolveFn, itemKey, itemLabel, actionSet)
    if bindings == nil then
        return
    end
    if type(bindings) ~= "table" then
        error(string.format("%s.defaultBindings must be table", tostring(itemLabel)))
    end
    for clickType, bindingKey in pairs(bindings) do
        if bindingKey ~= nil and bindingKey ~= false then
            AssertNonEmptyString(bindingKey, itemLabel .. ".defaultBindings." .. tostring(clickType))
            local resolvedKey = resolveFn(itemKey, bindingKey, actionSet)
            if not actionSet[resolvedKey] then
                error(string.format(
                    "%s default binding '%s' resolved to missing action '%s'",
                    tostring(itemLabel),
                    tostring(bindingKey),
                    tostring(resolvedKey)
                ))
            end
        end
    end
end

function addon:ValidateRegistryDefinitions()
    local seenKeys = {}
    local seenPriorityByGroup = {}
    local actionSet = BuildActionKeySet()

    local function RegisterKey(globalKey, sourceLabel)
        AssertNonEmptyString(globalKey, sourceLabel .. ".key")
        if seenKeys[globalKey] then
            error(string.format("Duplicate registry key '%s': %s vs %s", tostring(globalKey), tostring(seenKeys[globalKey]), tostring(sourceLabel)))
        end
        seenKeys[globalKey] = sourceLabel
    end

    local function RegisterPriority(groupKey, priority, itemKey)
        if not seenPriorityByGroup[groupKey] then
            seenPriorityByGroup[groupKey] = {}
        end
        local seen = seenPriorityByGroup[groupKey]
        if seen[priority] and seen[priority] ~= itemKey then
            WarnDuplicatePriority(groupKey, priority, seen[priority], itemKey)
            return
        end
        seen[priority] = itemKey
    end

    for categoryKey, category in pairs(addon.STREAM_REGISTRY or {}) do
        if type(category) == "table" then
            for subKey, streams in pairs(category) do
                if type(streams) == "table" then
                    for index, stream in ipairs(streams) do
                        local sourceLabel = string.format("STREAM_REGISTRY.%s.%s[%d]", tostring(categoryKey), tostring(subKey), index)
                        if type(stream) ~= "table" then
                            error(sourceLabel .. " must be table")
                        end
                        RegisterKey(stream.key, sourceLabel)
                        AssertPriority(stream, sourceLabel)
                        RegisterPriority(categoryKey .. "." .. subKey, stream.priority, stream.key)

                        if categoryKey == "CHANNEL" or categoryKey == "NOTICE" then
                            AssertNonEmptyString(stream.chatType, sourceLabel .. ".chatType")
                            AssertBooleanField(stream.defaultPinned, sourceLabel .. ".defaultPinned")
                            AssertBooleanField(stream.defaultSnapshotted, sourceLabel .. ".defaultSnapshotted")
                            AssertBooleanField(stream.defaultCopyable, sourceLabel .. ".defaultCopyable")
                            AssertBooleanField(stream.isInboundOnly, sourceLabel .. ".isInboundOnly")
                            AssertNonEmptyString(stream.kind, sourceLabel .. ".kind")
                            AssertNonEmptyString(stream.group, sourceLabel .. ".group")
                            if not ALLOWED_KIND[stream.kind] then
                                error(sourceLabel .. ".kind must be 'channel'|'notice'")
                            end
                            if not ALLOWED_GROUP[stream.group] then
                                error(sourceLabel .. ".group is invalid")
                            end
                            ValidateStreamCapabilities(stream.capabilities, sourceLabel)

                            if stream.events ~= nil and type(stream.events) ~= "table" then
                                error(sourceLabel .. ".events must be table")
                            end
                            if type(stream.events) == "table" then
                                for eventIndex, eventName in ipairs(stream.events) do
                                    AssertNonEmptyString(eventName, sourceLabel .. ".events[" .. tostring(eventIndex) .. "]")
                                end
                            end

                            if stream.kind == "notice" then
                                if stream.capabilities.outbound ~= false then
                                    error(sourceLabel .. ".capabilities.outbound must be false for notice kind")
                                end
                                if stream.capabilities.supportsAutoJoin ~= false then
                                    error(sourceLabel .. ".capabilities.supportsAutoJoin must be false for notice kind")
                                end
                            end

                            if stream.capabilities.outbound == true then
                                ValidateBindings(stream.defaultBindings, ResolveChannelBindingActionKey, stream.key, sourceLabel, actionSet)
                            elseif stream.defaultBindings ~= nil then
                                error(sourceLabel .. ".defaultBindings is not allowed when capabilities.outbound=false")
                            end

                            if stream.defaultAutoJoin ~= nil then
                                AssertBooleanField(stream.defaultAutoJoin, sourceLabel .. ".defaultAutoJoin")
                                if stream.capabilities.supportsAutoJoin ~= true then
                                    error(sourceLabel .. ".defaultAutoJoin is only allowed when capabilities.supportsAutoJoin=true")
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    for index, kit in ipairs(addon.KIT_REGISTRY or {}) do
        local sourceLabel = string.format("KIT_REGISTRY[%d]", index)
        if type(kit) ~= "table" then
            error(sourceLabel .. " must be table")
        end
        RegisterKey(kit.key, sourceLabel)
        AssertPriority(kit, sourceLabel)
        RegisterPriority("KIT", kit.priority, kit.key)
        ValidateBindings(kit.defaultBindings, ResolveKitBindingActionKey, kit.key, sourceLabel, actionSet)
    end

    if addon.Colors and addon.Colors.themes then
        for themeKey, themeDef in pairs(addon.Colors.themes) do
            local sourceLabel = "COLORSET." .. tostring(themeKey)
            AssertNonEmptyString(themeKey, sourceLabel .. ".key")
            AssertPriority(themeDef, sourceLabel)
            RegisterPriority("COLORSET", themeDef.priority, themeKey)
        end
    end

    return true
end
