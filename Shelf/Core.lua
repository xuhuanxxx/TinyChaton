local addonName, addon = ...
local L = addon.L

-- ============================================
-- Shelf Core - Logic Layer
-- Configuration generation and action management
-- No UI code here
-- ============================================

addon.Shelf = addon.Shelf or {}

-- ============================================
-- Channel List Cache (reduces GetChannelList() call frequency)
-- ============================================
local channelListCache = { data = nil, timestamp = 0, TTL = 1 }

local function GetCachedChannelList()
    local now = GetTime()
    if not channelListCache.data or (now - channelListCache.timestamp) > channelListCache.TTL then
        channelListCache.data = { GetChannelList() }
        channelListCache.timestamp = now
    end
    return channelListCache.data
end

-- ============================================
-- Configuration Generation (from Registries)
-- ============================================

-- ============================================
-- Configuration Generation (from Registries)
-- ============================================

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
    -- 1. If user has custom order, use it
    if addon.db.plugin.shelf.shelfOrder and #addon.db.plugin.shelf.shelfOrder > 0 then
        return addon.db.plugin.shelf.shelfOrder
    end
    
    -- 2. Fully dynamic generation from registries
    local items = {}
    
    -- Ensure registries are loaded
    if not addon.CHANNEL_REGISTRY or not addon.KIT_REGISTRY then
        return {}
    end
    
    -- Get all channels
    for _, reg in ipairs(addon.CHANNEL_REGISTRY) do
        if reg.isSystem or reg.isDynamic then
            table.insert(items, { key = reg.key, order = reg.order or 0, type = "channel" })
        end
    end
    
    -- Get all kits
    for _, reg in ipairs(addon.KIT_REGISTRY) do
        table.insert(items, { key = reg.key, order = reg.order or 0, type = "kit" })
    end
    
    -- Sort by order
    table.sort(items, function(a, b) return a.order < b.order end)
    
    -- Return key list
    local order = {}
    for _, item in ipairs(items) do
        table.insert(order, item.key)
    end
    return order
end

function addon.Shelf:GetItemConfig(key)
    -- Ensure registries are loaded
    if not addon.CHANNEL_REGISTRY or not addon.KIT_REGISTRY then
        return nil
    end
    
    local bindings = (addon.db and addon.db.plugin and addon.db.plugin.shelf and addon.db.plugin.shelf.bindings) or {}
    local customBind = bindings[key]
    
    -- Check CHANNEL_REGISTRY
    for _, reg in ipairs(addon.CHANNEL_REGISTRY) do
        if reg.key == key and (reg.isSystem or reg.isDynamic) then
            local defBindings = reg.defaultBindings or {}
            
            -- Resolve Actions
            local leftAction, rightAction
            
            -- Helper to map shorthand to full action key
            local function MapAction(actionKey, typePrefix, itemKey)
                if not actionKey then return nil end
                if actionKey == false then return false end -- Explicit Unbind
                
                -- Check if it's already a full key (from custom binding)
                if addon.ACTION_REGISTRY and addon.ACTION_REGISTRY[actionKey] then
                    return actionKey
                end
                
                -- Otherwise map short key
                if typePrefix == "channel" then
                    if actionKey == "send" then return "sendTo_" .. itemKey
                    elseif actionKey == "join" then return "join_" .. itemKey
                    elseif actionKey == "leave" then return "leave_" .. itemKey
                    else return "channel_" .. itemKey .. "_" .. actionKey end
                else
                     return "kit_" .. itemKey .. "_" .. actionKey
                end
            end
            
            -- 1. Left Click
            if customBind and customBind.left ~= nil then
                leftAction = customBind.left -- Can be false or string
            else
                leftAction = MapAction(defBindings.left, "channel", key)
            end
            
            -- 2. Right Click
            if customBind and customBind.right ~= nil then
                rightAction = customBind.right
            else
                rightAction = MapAction(defBindings.right, "channel", key)
            end
            
            return {
                type = "channel",
                key = reg.key,
                label = reg.label,
                shortKey = reg.shortKey,
                colors = reg.colors,
                isDynamic = reg.isDynamic,
                mappingKey = reg.mappingKey,
                leftClick = leftAction,
                rightClick = rightAction,
                actions = reg.actions,
            }
        end
    end
    
    -- Check KIT_REGISTRY
    for _, reg in ipairs(addon.KIT_REGISTRY) do
        if reg.key == key then
            local defBindings = reg.defaultBindings or {}
            local leftAction, rightAction
            
             -- Helper to map shorthand to full action key
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
                actions = reg.actions,
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
    local dynamicMode = addon.db.plugin.shelf.dynamicMode or "hide"
    
    -- Debug: Check initialization
    if #shelfOrder == 0 then
         -- print("Shelf Core Debug: WARNING - shelfOrder is EMPTY! Registry likely missing or config corrupt.")
    end

    -- Get joined channels for dynamic channel detection (using cache)
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
                -- Support registry fallback if DB not set
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
    
    local function ProcessRegistry(registry, prefix, typePrefix)
        if not registry then return end
        for _, item in ipairs(registry) do
            if item.actions then
                for _, actionSpec in ipairs(item.actions) do
                    local fullKey
                    local label = actionSpec.label
                    local category = "other"
                    
                    if typePrefix == "channel" then
                        if actionSpec.key == "send" then 
                            fullKey = "sendTo_" .. item.key
                            category = "channel"
                        elseif actionSpec.key == "join" then 
                            fullKey = "join_" .. item.key
                            category = "join"
                        elseif actionSpec.key == "leave" then 
                            fullKey = "leave_" .. item.key
                            category = "leave"
                        else 
                            fullKey = "channel_" .. item.key .. "_" .. actionSpec.key 
                            category = "channel"
                        end
                    else
                        fullKey = "kit_" .. item.key .. "_" .. actionSpec.key
                        label = L["ACTION_PREFIX_KIT"] .. actionSpec.label
                        category = "kit"
                    end

                    actions[fullKey] = {
                        key = fullKey,
                        label = label,
                        tooltip = actionSpec.tooltip,
                        kitKey = (typePrefix == "kit") and item.key or nil,
                        channelKey = (typePrefix == "channel") and item.key or nil,
                        execute = actionSpec.execute,
                        category = category
                    }
                end
            end
        end
    end
    
    ProcessRegistry(addon.CHANNEL_REGISTRY, "", "channel")
    ProcessRegistry(addon.KIT_REGISTRY, L["ACTION_PREFIX_KIT"], "kit")
    
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
