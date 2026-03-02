local addonName, addon = ...
local L = addon.L

-- Shelf Core - Logic Layer

addon.Shelf = addon.Shelf or {}

-- Channel List Cache
local GetChannelList = GetChannelList
local GetTime = GetTime
local ipairs = ipairs
local pairs = pairs
local table = table
local type = type
local tostring = tostring

local channelListCache = { data = nil, timestamp = 0, TTL = 1 }
local lastActionBlockedAt = 0

local function GetCachedChannelList()
    local now = GetTime()
    if not channelListCache.data or (now - channelListCache.timestamp) > channelListCache.TTL then
        channelListCache.data = { GetChannelList() }
        channelListCache.timestamp = now
    end
    return channelListCache.data
end

function addon.Shelf:InvalidateChannelListCache()
    channelListCache.data = nil
    channelListCache.timestamp = 0
end

function addon:GetShelfThemeProperties(themeKey)
    themeKey = themeKey or (addon.db and addon.db.profile and addon.db.profile.shelf and addon.db.profile.shelf.theme) or addon.CONSTANTS.SHELF_DEFAULT_THEME

    local props = {}
    if not addon.ThemeRegistry or not addon.ThemeRegistry.GetPreset then
        return props
    end

    local preset = addon.ThemeRegistry:GetPreset(themeKey)
    if not preset then
        preset = addon.ThemeRegistry:GetPreset(addon.CONSTANTS.SHELF_DEFAULT_THEME)
    end

    if preset and preset.properties then
        for k, v in pairs(preset.properties) do
            props[k] = v
        end

        local db = addon.db and addon.db.profile and addon.db.profile.shelf
        if db and db.themes and db.themes[themeKey] then
            for k, v in pairs(db.themes[themeKey]) do
                if type(v) ~= "table" or k == "bgColor" or k == "borderColor" or k == "hoverBorderColor" or k == "textColor" then
                    props[k] = v
                end
            end
        end
    end

    return props
end

-- Configuration Generation

function addon.Shelf:GetThemeProperty(prop)
    if not addon.db or not addon.db.profile or not addon.db.profile.shelf then return nil end
    local db = addon.db.profile.shelf
    local theme = db.theme or addon.CONSTANTS.SHELF_DEFAULT_THEME
    if not db.themes then db.themes = {} end
    if not db.themes[theme] then db.themes[theme] = {} end

    local val = db.themes[theme][prop]
    if val == nil then
        -- Fallback to theme default
        local preset = addon.ThemeRegistry and addon.ThemeRegistry:GetPreset(theme)
        if preset and preset.properties then val = preset.properties[prop] end
    end
    return val
end

function addon.Shelf:SetThemeProperty(prop, val)
    if not addon.db or not addon.db.profile or not addon.db.profile.shelf then return end
    local db = addon.db.profile.shelf
    local theme = db.theme or addon.CONSTANTS.SHELF_DEFAULT_THEME
    if not db.themes then db.themes = {} end
    if not db.themes[theme] then db.themes[theme] = {} end

    db.themes[theme][prop] = val
    addon:RefreshShelf()
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
        table.insert(items, { key = stream.key, order = stream.order or 0, type = "channel" })
    end

    for _, stream in ipairs(addon.STREAM_REGISTRY.CHANNEL.DYNAMIC or {}) do
        table.insert(items, { key = stream.key, order = stream.order or 0, type = "channel" })
    end

    for _, reg in ipairs(addon.KIT_REGISTRY) do
        table.insert(items, { key = reg.key, order = reg.order or 0, type = "kit" })
    end

    table.sort(items, function(a, b) return a.order < b.order end)

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

        return {
            type = "channel",
            key = stream.key,
            label = stream.label,
            shortKey = stream.shortKey,
            colors = stream.colors,
            isDynamic = isDynamic,
            mappingKey = stream.mappingKey,
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

            return {
                type = "kit",
                key = reg.key,
                label = reg.label,
                short = reg.short,
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

    local channelList = GetCachedChannelList()
    local joinedChannels = {}
    for i = 1, #channelList, 3 do
        local id, name = channelList[i], channelList[i + 1]
        if id and name then
            joinedChannels[#joinedChannels + 1] = { id = id, name = name }
        end
    end

    local function findChannelByBaseName(baseName)
        if not baseName or baseName == "" then return nil end
        for _, entry in ipairs(joinedChannels) do
            local name = entry.name
            if name == baseName then
                return entry.id
            end
            if name:sub(1, #baseName) == baseName then
                local nextChar = name:sub(#baseName + 1, #baseName + 1)
                if nextChar == "" or nextChar == " " or nextChar == "-" then
                    return entry.id
                end
            end
        end
        return nil
    end

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

                -- Availability detection is intentionally scoped to dynamic channels only.
                -- System channels do not have a unified joined/available API in this layer.
                if isChannel and item.isDynamic then
                    local realName = item.mappingKey and L[item.mappingKey]
                    channelNumber = realName and findChannelByBaseName(realName) or nil
                    isJoined = channelNumber ~= nil

                    if not isJoined and dynamicMode == "hide" then
                        shouldShow = false
                    end
                end

                if shouldShow then
                    local btnKey = channelNumber and tostring(channelNumber) or item.key
                    local displayText = isChannel and addon:GetChannelLabel(item, channelNumber, "SHORT") or (item.short or item.label or key)

                    local isMuted = false
                    if item.isDynamic and isJoined and addon.VisibilityPolicy and addon.VisibilityPolicy.IsDynamicChannelMuted then
                        isMuted = addon.VisibilityPolicy:IsDynamicChannelMuted(item.key)
                    end

                    local channelState = "joined"
                    if isChannel and item.isDynamic then
                        if not isJoined then
                            channelState = "unjoined"
                        elseif isMuted then
                            channelState = "muted"
                        end
                    end

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
