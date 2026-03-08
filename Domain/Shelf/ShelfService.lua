local addonName, addon = ...
local L = addon.L

-- Shelf Core - Logic Layer

addon.Shelf = addon.Shelf or {}

local GetTime = GetTime
local ipairs = ipairs
local pairs = pairs
local table = table
local type = type
local tostring = tostring

local lastActionBlockedAt = 0

local function ResolveActionLabel(actionKey, itemKey)
    if not actionKey or not addon.ACTION_REGISTRY then
        return nil
    end

    local action = addon.ACTION_REGISTRY[actionKey]
    if not action then
        return nil
    end

    if type(action.getLabel) == "function" then
        return action.getLabel(itemKey)
    end
    return action.label
end

local function ResolveActionTooltip(actionKey, itemKey)
    if not actionKey or not addon.ACTION_REGISTRY then
        return nil
    end

    local action = addon.ACTION_REGISTRY[actionKey]
    if not action then
        return nil
    end

    if type(action.getTooltip) == "function" then
        return action.getTooltip(itemKey)
    end
    return action.tooltip
end

local function ResolveStreamFullLabel(streamKey, channelNumber, fallbackLabel)
    local stream = addon:GetStreamByKey(streamKey)
    local identity = stream and addon.ResolveDisplayIdentity and addon:ResolveDisplayIdentity(stream, "channel", {
        streamMeta = { channelId = channelNumber },
    }) or nil
    if identity and identity.fullName then
        return identity.fullName
    end
    if identity and identity.label then
        return identity.label
    end
    return fallbackLabel or streamKey
end

local function ResolveKitFullLabel(item, fallbackLabel)
    local identity = item and addon.ResolveDisplayIdentity and addon:ResolveDisplayIdentity(item, "kit", {}) or nil
    if identity and identity.fullName then
        return identity.fullName
    end
    if identity and identity.label then
        return identity.label
    end
    return fallbackLabel or (item and item.key) or nil
end

function addon:GetShelfThemeProperties(themeKey)
    if addon.ThemeProvider and addon.ThemeProvider.GetShelfThemeProperties then
        return addon.ThemeProvider:GetShelfThemeProperties(themeKey)
    end
    return {}
end

function addon.Shelf:GetThemeProperty(prop)
    if addon.ThemeProvider and addon.ThemeProvider.GetThemeProperty then
        return addon.ThemeProvider:GetThemeProperty(prop)
    end
    return nil
end

function addon.Shelf:SetThemeProperty(prop, val)
    if addon.ThemeProvider and addon.ThemeProvider.SetThemeProperty then
        addon.ThemeProvider:SetThemeProperty(prop, val)
    end
end

function addon.Shelf:GetOrder()
    if addon.db.profile.buttons.buttonOrder and #addon.db.profile.buttons.buttonOrder > 0 then
        return addon.db.profile.buttons.buttonOrder
    end

    local items = {}

    local hasStreamRegistry = addon.IterateCompiledStreams ~= nil
    local hasKitRegistry = addon.KIT_REGISTRY

    if not hasStreamRegistry or not hasKitRegistry then
        return {}
    end

    for _, stream in addon:IterateCompiledStreams() do
        if addon:IsChannelStream(stream.key) then
            local group = addon:GetStreamGroup(stream.key)
            if group == "system" or group == "dynamic" then
                table.insert(items, { key = stream.key, priority = stream.priority, type = "channel", group = string.upper(group) })
            end
        end
    end

    for _, reg in ipairs(addon.KIT_REGISTRY) do
        table.insert(items, { key = reg.key, priority = reg.priority, type = "kit", group = "KIT" })
    end

    table.sort(items, function(a, b)
        if addon.Utils and addon.Utils.CompareByPriority then
            return addon.Utils.CompareByPriority(a, b, {
                groupRankByValue = { SYSTEM = 1, DYNAMIC = 2, KIT = 3 },
            })
        end
        return (a.priority or 0) < (b.priority or 0)
    end)

    local order = {}
    for _, item in ipairs(items) do
        table.insert(order, item.key)
    end
    return order
end

function addon.Shelf:GetItemConfig(key)
    local bindings = (addon.db and addon.db.profile and addon.db.profile.buttons and addon.db.profile.buttons.bindings) or {}
    local customBind = bindings[key]

    local stream = addon:GetStreamByKey(key)
    if stream and addon:IsChannelStream(key) then
        local leftAction
        local rightAction

        if customBind and customBind.left ~= nil then
            leftAction = customBind.left
        else
            leftAction = addon.ResolveStreamBindingActionKey and addon.ResolveStreamBindingActionKey(key, "left") or nil
        end

        if customBind and customBind.right ~= nil then
            rightAction = customBind.right
        else
            rightAction = addon.ResolveStreamBindingActionKey and addon.ResolveStreamBindingActionKey(key, "right") or nil
        end

        local isDynamic = addon:GetStreamGroup(key) == "dynamic"
        local identity = addon.ResolveStreamIdentity and addon:ResolveStreamIdentity(stream, {}) or nil

        return {
            type = "channel",
            key = stream.key,
            label = (identity and identity.label) or stream.key,
            shortOne = identity and identity.shortOne or nil,
            shortTwo = identity and identity.shortTwo or nil,
            colors = stream.colors,
            isDynamic = isDynamic,
            leftClick = leftAction,
            rightClick = rightAction,
        }
    end

    for _, reg in ipairs(addon.KIT_REGISTRY) do
        if reg.key == key then
            local defBindings = reg.defaultBindings or {}

            local function MapKitAction(actionKey, itemKey)
                if not actionKey then return nil end
                if actionKey == false then return false end

                if addon.ACTION_REGISTRY and addon.ACTION_REGISTRY[actionKey] then
                    return actionKey
                end

                return "kit_" .. itemKey .. "_" .. actionKey
            end

            local leftAction
            local rightAction

            if customBind and customBind.left ~= nil then
                leftAction = customBind.left
            else
                leftAction = MapKitAction(defBindings.left, key)
            end

            if customBind and customBind.right ~= nil then
                rightAction = customBind.right
            else
                rightAction = MapKitAction(defBindings.right, key)
            end

            local identity = addon.ResolveDisplayIdentity and addon:ResolveDisplayIdentity(reg, "kit", {}) or nil
            return {
                type = "kit",
                key = reg.key,
                label = (identity and identity.label) or reg.key,
                shortOne = identity and identity.shortOne or nil,
                shortTwo = identity and identity.shortTwo or nil,
                colors = reg.colors,
                leftClick = leftAction,
                rightClick = rightAction,
                tooltip = reg.tooltip,
            }
        end
    end

    return nil
end

function addon.Shelf:BuildItemDescriptors()
    local descriptors = {}

    if not addon.db or not addon.db.profile.buttons then
        return descriptors
    end

    local buttonOrder = self:GetOrder()
    local channelPins = addon.db.profile.buttons.channelPins or {}
    local kitPins = addon.db.profile.buttons.kitPins or {}
    local dynamicMode = addon.db.profile.buttons.dynamicMode or "hide"

    for _, key in ipairs(buttonOrder) do
        local item = self:GetItemConfig(key)
        if item then
            local isChannel = item.type == "channel"
            local isKit = item.type == "kit"
            local isEnabled = false

            if isChannel then
                isEnabled = channelPins[key] ~= false
            elseif isKit then
                if kitPins[key] ~= nil then
                    isEnabled = kitPins[key] == true
                else
                    isEnabled = item.item and item.item.defaultPinned
                end
            end

            if isEnabled then
                local isJoined = true
                local channelNumber = nil
                local shouldShow = true
                local channelState = "ready"
                local isBlocked = false

                if isChannel and addon.StreamVisibilityService and addon.StreamVisibilityService.IsStreamBlocked then
                    isBlocked = addon.StreamVisibilityService:IsStreamBlocked(item.key)
                end

                if isChannel and item.isDynamic then
                    local availability = addon.AvailabilityResolver and addon.AvailabilityResolver.Resolve
                        and addon.AvailabilityResolver.Resolve(item.key, "channel", {}) or nil
                    channelNumber = availability and availability.channelId or nil
                    isJoined = availability and availability.available == true or false
                    channelState = (availability and availability.state) or "unjoined"

                    if isJoined and isBlocked then
                        channelState = "muted"
                    end

                    if not isJoined and dynamicMode == "hide" then
                        shouldShow = false
                    end
                elseif isChannel then
                    channelState = isBlocked and "muted" or "ready"
                end

                if shouldShow then
                    local btnKey = channelNumber and tostring(channelNumber) or item.key
                    local displayText
                    local fullLabel
                    local tooltipMode = "label_only"
                    local sourceItem = item

                    if isChannel then
                        local displayStream = addon:GetStreamByKey(item.key)
                        sourceItem = displayStream or item
                        displayText = addon:FormatDisplayText(sourceItem, "channel", "shelf", {
                            streamMeta = { channelId = channelNumber },
                        })
                        fullLabel = ResolveStreamFullLabel(item.key, channelNumber, item.label)
                    else
                        local kitSpec = item
                        if item.key then
                            for _, reg in ipairs(addon.KIT_REGISTRY or {}) do
                                if reg.key == item.key then
                                    kitSpec = reg
                                    break
                                end
                            end
                        end
                        sourceItem = kitSpec
                        displayText = addon:FormatDisplayText(kitSpec, "kit", "shelf", {})
                        fullLabel = ResolveKitFullLabel(kitSpec, item.label)
                    end

                    local leftActionKey = item.leftClick
                    local rightActionKey = item.rightClick
                    local leftActionLabel = ResolveActionLabel(leftActionKey, item.key)
                    local rightActionLabel = ResolveActionLabel(rightActionKey, item.key)
                    local primaryActionKey = leftActionKey or rightActionKey
                    local tooltipDescription = item.tooltip
                        or ResolveActionTooltip(primaryActionKey, item.key)
                        or leftActionLabel
                        or rightActionLabel

                    if leftActionLabel or rightActionLabel then
                        tooltipMode = "bindings"
                    end

                    table.insert(descriptors, {
                        key = btnKey,
                        itemKey = item.key,
                        itemType = item.type,
                        displayText = displayText,
                        fullLabel = fullLabel,
                        channelState = channelState,
                        channelNumber = channelNumber,
                        isDynamic = item.isDynamic == true,
                        leftActionKey = leftActionKey,
                        rightActionKey = rightActionKey,
                        leftActionLabel = leftActionLabel,
                        rightActionLabel = rightActionLabel,
                        tooltipMode = tooltipMode,
                        tooltipDescription = tooltipDescription,
                        intentItem = {
                            key = item.key,
                            itemKey = item.key,
                            type = item.type,
                        },
                        sourceItem = sourceItem,
                    })
                end
            end
        end
    end

    return descriptors
end

function addon.Shelf:BuildRenderSpec(context)
    local descriptors = self:BuildItemDescriptors(context)
    if not addon.ShelfRenderSpecResolver or type(addon.ShelfRenderSpecResolver.Build) ~= "function" then
        return nil
    end
    return addon.ShelfRenderSpecResolver:Build(descriptors, context)
end

function addon.Shelf:BuildActionRegistry()
    local actions = {}

    if addon.BuildActionRegistryFromDefinitions then
        local newActions = addon:BuildActionRegistryFromDefinitions()
        if newActions and next(newActions) then
            for k, v in pairs(newActions) do
                actions[k] = v
            end
        end
    end
    return actions
end

function addon.Shelf:InitActionRegistry()
    addon.ACTION_REGISTRY = self:BuildActionRegistry()
end

function addon.Shelf:ExecuteAction(actionKey, ...)
    if not actionKey or not addon.ShelfButtonAdapter or not addon.ActionIntentOrchestrator then
        return
    end

    local result = addon.ShelfButtonAdapter:Execute(actionKey, ...)
    if type(result) == "table" and result.ok == false and result.reason == "plane_denied" then
        local now = GetTime()
        if (now - lastActionBlockedAt) >= 1 then
            lastActionBlockedAt = now
            local prefix = (L and L["LABEL_ADDON_NAME"]) or "TinyChaton"
            print("|cff00ff00" .. prefix .. "|r: Action unavailable in instance bypass mode.")
        end
    end
end
