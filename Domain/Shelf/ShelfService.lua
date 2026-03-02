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

function addon:GetShelfThemeProperties(themeKey)
    if addon.ThemeProvider and addon.ThemeProvider.GetShelfThemeProperties then
        return addon.ThemeProvider:GetShelfThemeProperties(themeKey)
    end
    return {}
end

-- Configuration Generation

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

    local hasStreamRegistry = addon.STREAM_REGISTRY and addon.STREAM_REGISTRY.CHANNEL
    local hasKitRegistry = addon.KIT_REGISTRY

    if not hasStreamRegistry or not hasKitRegistry then
        return {}
    end

    for _, stream in ipairs(addon.STREAM_REGISTRY.CHANNEL.SYSTEM or {}) do
        table.insert(items, { key = stream.key, priority = stream.priority, type = "channel", group = "SYSTEM" })
    end

    for _, stream in ipairs(addon.STREAM_REGISTRY.CHANNEL.DYNAMIC or {}) do
        table.insert(items, { key = stream.key, priority = stream.priority, type = "channel", group = "DYNAMIC" })
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

    -- Try to find Stream first (new architecture)
    local stream = addon:GetStreamByKey(key)
    if stream and addon:IsChannelStream(key) then
        local defBindings = stream.defaultBindings or {}

        -- Resolve Actions
        local leftAction, rightAction

        -- Helper to map shorthand to full action key
        local function MapAction(actionKey, itemKey)
            if not actionKey then return nil end
            if actionKey == false then return false end -- Explicit Unbind

            -- Check if it's already a full key (from custom binding)
            if addon.ACTION_REGISTRY and addon.ACTION_REGISTRY[actionKey] then
                return actionKey
            end

            -- Map short key to full ACTION key
            if actionKey == "send" then
                -- Check if this is a special stream (whisper, emote)
                if itemKey == "whisper" or itemKey == "bn_whisper" then
                    return "whisper_send_" .. itemKey
                elseif itemKey == "emote" then
                    return "emote_send_" .. itemKey
                else
                    return "send_" .. itemKey
                end
            elseif actionKey == "mute_toggle" then
                return "mute_toggle_" .. itemKey
            else
                return "channel_" .. itemKey .. "_" .. actionKey
            end
        end

        if customBind and customBind.left ~= nil then
            leftAction = customBind.left
        else
            leftAction = MapAction(defBindings.left, key)
        end

        if customBind and customBind.right ~= nil then
            rightAction = customBind.right
        else
            rightAction = MapAction(defBindings.right, key)
        end

        local path = addon:GetStreamPath(key)
        local isDynamic = path and path:match("%.DYNAMIC$") ~= nil
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

    -- Check KIT_REGISTRY
    for _, reg in ipairs(addon.KIT_REGISTRY) do
        if reg.key == key then
            local defBindings = reg.defaultBindings or {}
            local leftAction, rightAction

             local function MapKitAction(actionKey, itemKey)
                if not actionKey then return nil end
                 if actionKey == false then return false end

                 if addon.ACTION_REGISTRY and addon.ACTION_REGISTRY[actionKey] then
                    return actionKey
                end

                return "kit_" .. itemKey .. "_" .. actionKey
            end

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

function addon.Shelf:GetVisibleItems()
    local visibleItems = {}

    if not addon.db or not addon.db.profile.buttons then return visibleItems end

    local buttonOrder = self:GetOrder()
    local channelPins = addon.db.profile.buttons.channelPins or {}
    local kitPins = addon.db.profile.buttons.kitPins or {}
    -- IMPORTANT: dynamicMode applies to CHANNEL.DYNAMIC only.
    -- System channels are not availability-checked and remain pin-driven.
    local dynamicMode = addon.db.profile.buttons.dynamicMode or "hide"

    -- Iterate by buttonOrder
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

                -- Availability detection is intentionally scoped to dynamic channels only.
                -- System channels do not have a unified joined/available API in this layer.
                if isChannel and item.isDynamic then
                    local availability = addon.AvailabilityResolver and addon.AvailabilityResolver.Resolve
                        and addon.AvailabilityResolver.Resolve(item.key, "channel", {}) or nil
                    channelNumber = availability and availability.channelId or nil
                    isJoined = availability and availability.available == true or false
                    channelState = (availability and availability.state) or "unjoined"

                    if not isJoined and dynamicMode == "hide" then
                        shouldShow = false
                    end
                elseif isChannel then
                    channelState = "ready"
                end

                if shouldShow then
                    local btnKey = channelNumber and tostring(channelNumber) or item.key
                    local displayText
                    if isChannel then
                        local displayStream = addon:GetStreamByKey(item.key)
                        displayText = addon:FormatDisplayText(displayStream or item, "channel", "shelf", { channelId = channelNumber })
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
                        displayText = addon:FormatDisplayText(kitSpec, "kit", "shelf", {})
                    end

                    local isMuted = (channelState == "muted")

                    table.insert(visibleItems, {
                        key = btnKey,
                        itemKey = item.key,
                        text = displayText,
                        label = item.label,
                        short = item.short,
                        color = item.color,
                        isDynamic = item.isDynamic,
                        isChannel = isChannel,
                        isKit = isKit,
                        isMuted = isMuted,
                        channelState = channelState,
                        item = item,
                        channelNumber = channelNumber,
                    })
                end
            end
        end
    end

    return visibleItems
end

-- ============================================
-- Action Registry
-- ============================================

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
    if not actionKey then return end
    local action = addon.ACTION_REGISTRY and addon.ACTION_REGISTRY[actionKey]
    if not action or not action.execute then
        return
    end

    if addon.CanExecuteAction then
        local allowed, reason = addon:CanExecuteAction(actionKey)
        if not allowed then
            if reason == "bypass_blocked" then
                local now = GetTime()
                if (now - lastActionBlockedAt) >= 1 then
                    lastActionBlockedAt = now
                    local prefix = (L and L["LABEL_ADDON_NAME"]) or "TinyChaton"
                    print("|cff00ff00" .. prefix .. "|r: Action unavailable in instance bypass mode.")
                end
            end
            return
        end
    end

    action.execute(...)
end
