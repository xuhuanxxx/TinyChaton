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

-- Configuration Generation

function addon.Shelf:GetThemeProperty(prop)
    if not addon.db or not addon.db.plugin or not addon.db.plugin.shelf then return nil end
    local db = addon.db.plugin.shelf
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
    if not addon.db or not addon.db.plugin or not addon.db.plugin.shelf then return end
    local db = addon.db.plugin.shelf
    local theme = db.theme or addon.CONSTANTS.SHELF_DEFAULT_THEME
    if not db.themes then db.themes = {} end
    if not db.themes[theme] then db.themes[theme] = {} end

    db.themes[theme][prop] = val
    addon:RefreshShelf()
end

function addon.Shelf:GetOrder()
    if addon.db.plugin.shelf.shelfOrder and #addon.db.plugin.shelf.shelfOrder > 0 then
        return addon.db.plugin.shelf.shelfOrder
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
    local bindings = (addon.db and addon.db.plugin and addon.db.plugin.shelf and addon.db.plugin.shelf.bindings) or {}
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
            elseif actionKey == "join" then
                return "join_" .. itemKey
            elseif actionKey == "leave" then
                return "leave_" .. itemKey
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

    if not addon.db or not addon.db.plugin.shelf then return visibleItems end

    local shelfOrder = self:GetOrder()
    local channelPins = addon.db.plugin.shelf.channelPins or {}
    local kitPins = addon.db.plugin.shelf.kitPins or {}
    -- IMPORTANT: dynamicMode applies to CHANNEL.DYNAMIC only.
    -- System channels are not availability-checked and remain pin-driven.
    local dynamicMode = addon.db.plugin.shelf.dynamicMode or "hide"

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

    -- Iterate by shelfOrder
    for _, key in ipairs(shelfOrder) do
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

                    table.insert(visibleItems, {
                        key = btnKey,
                        itemKey = item.key,
                        text = displayText,
                        label = item.label,
                        short = item.short,
                        color = item.color,
                        isDynamic = item.isDynamic,
                        isActive = (not isChannel) or isJoined,
                        isChannel = isChannel,
                        isKit = isKit,
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
    if action and action.execute then
        action.execute(...)
    end
end
