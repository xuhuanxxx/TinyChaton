local addonName, addon = ...
local L = addon.L

-- Helper function to get localized welcome templates
local function GetDefaultWelcomeTemplates(scene)
    local templates = {}
    for i = 1, 5 do
        local key = "WELCOME_TEMPLATE_" .. scene:upper() .. "_" .. i
        local text = L[key]
        if text and text ~= key then
            table.insert(templates, text)
        end
    end
    -- Fallback to empty table if no translations found
    return #templates > 0 and templates or {}
end

-- NOTE: Registries moved to Libs/Registry/ directory:
--   - CHANNEL_REGISTRY -> Libs/Registry/Channels.lua
--   - KIT_REGISTRY -> Libs/Registry/Kits.lua
--   - SETTING_REGISTRY -> Libs/Registry/Settings.lua
--   - ThemeRegistry -> Libs/Registry/Themes.lua

-- Storage mode switching removed - only global database is used
TinyChatonDB = TinyChatonDB or {}

addon.CONSTANTS = {
    SNAP_THRESHOLD = 50,
    MIN_BUTTON_SIZE = 20,
    MAX_BUTTON_SIZE = 60,
    SHELF_ANCHOR_OFFSET_TAB_Y = 6,
    SHELF_ANCHOR_OFFSET_EDITBOX_Y = 0,
    EMOTE_PAGE_SIZE = 40,
    EMOTE_COLS = 8,
    EMOTE_ROWS = 5,
    
    -- Shelf Defaults
    SHELF_DEFAULT_BUTTON_SIZE = 30,
    SHELF_DEFAULT_SPACING = 2,
    SHELF_DEFAULT_ALPHA = 1.0,
    SHELF_DEFAULT_SCALE = 1.0,
    SHELF_DEFAULT_FONT_SIZE = 14,
    SHELF_DEFAULT_FONT = "STANDARD",
    SHELF_DEFAULT_THEME = "Modern",
    SHELF_DEFAULT_COLORSET = "rainbow",
    SHELF_DEFAULT_ANCHOR = "chat_top",
    
    -- Chat Defaults
    CHAT_DEFAULT_FONT = "STANDARD",
    CHAT_DEFAULT_SIZE = 16, -- Added from instruction
    
    -- Snapshot Defaults
    SNAPSHOT_MAX_TOTAL_DEFAULT = 5000, -- Added from instruction
    SNAPSHOT_MAX_TOTAL_MIN = 1000, -- Added from instruction
    SNAPSHOT_MAX_TOTAL_MAX = 20000, -- Added from instruction
    SNAPSHOT_MAX_TOTAL_STEP = 500, -- Added from instruction
    
    -- Profile Defaults
    PROFILE_DEFAULT_NAME = "Default",
    PROFILE_NAME_MAX_LENGTH = 32,
}

-- =========================================================================
-- Stream Helper Functions
-- Used for registry traversal and property derivation
-- These are defined here to be available for DEFAULTS construction
-- =========================================================================

function addon:GetStreamPath(key)
    if not self.STREAM_REGISTRY then return nil end
    
    for categoryKey, category in pairs(self.STREAM_REGISTRY) do
        for subKey, subCategory in pairs(category) do
            for _, stream in ipairs(subCategory) do
                if stream.key == key then
                    return categoryKey .. "." .. subKey
                end
            end
        end
    end
    
    return nil
end

function addon:GetStreamByKey(key)
    if not self.STREAM_REGISTRY then return nil end
    
    for categoryKey, category in pairs(self.STREAM_REGISTRY) do
        for subKey, subCategory in pairs(category) do
            for _, stream in ipairs(subCategory) do
                if stream.key == key then
                    return stream
                end
            end
        end
    end
    
    return nil
end

function addon:IsChannelStream(key)
    local path = self:GetStreamPath(key)
    return path and path:match("^CHANNEL%.") ~= nil
end

function addon:IsNoticeStream(key)
    local path = self:GetStreamPath(key)
    return path and path:match("^NOTICE%.") ~= nil
end

function addon:GetStreamDefaults(key)
    local path = self:GetStreamPath(key)
    if not path then return {} end
    
    local defaults = {}
    
    -- CHANNEL 下的项默认值
    if path:match("^CHANNEL%.") then
        defaults.defaultPinned = true
        defaults.defaultSnapshotted = true
        defaults.defaultAutoJoin = false
    end
    
    -- NOTICE 下的项默认值
    if path:match("^NOTICE%.") then
        defaults.defaultPinned = false
        defaults.defaultSnapshotted = false
        defaults.defaultAutoJoin = false
    end
    
    return defaults
end

function addon:GetStreamProperty(stream, propertyName, fallbackValue)
    if stream[propertyName] ~= nil then
        return stream[propertyName]
    end
    
    if stream.key then
        local defaults = self:GetStreamDefaults(stream.key)
        if defaults[propertyName] ~= nil then
            return defaults[propertyName]
        end
    end
    
    return fallbackValue
end

--- 扁平化遍历所有 Stream 的迭代器
--- 包含所有 CHANNEL 和 NOTICE 类别的项
--- @return function 迭代函数
function addon:IterateAllStreams()
    if not self.STREAM_REGISTRY then return function() end end
    
    local categories = { "CHANNEL", "NOTICE" }
    local catIdx = 1
    local subIdx = 1
    local itemIdx = 0
    
    -- 获取当前的 subGroups 列表
    local function getSubGroups(catKey)
        local cat = self.STREAM_REGISTRY[catKey]
        if not cat then return {} end
        local keys = {}
        for k in pairs(cat) do table.insert(keys, k) end
        table.sort(keys) -- 保证稳定顺序
        return keys
    end
    
    local subGroups = getSubGroups(categories[catIdx])
    
    return function()
        while catIdx <= #categories do
            local catKey = categories[catIdx]
            local subKey = subGroups[subIdx]
            
            if subKey then
                local items = self.STREAM_REGISTRY[catKey][subKey]
                itemIdx = itemIdx + 1
                
                if items[itemIdx] then
                    return itemIdx, items[itemIdx], catKey, subKey
                else
                    -- Move to next subGroup
                    subIdx = subIdx + 1
                    itemIdx = 0
                end
            else
                -- Move to next category
                catIdx = catIdx + 1
                if catIdx <= #categories then
                    subGroups = getSubGroups(categories[catIdx])
                    subIdx = 1
                    itemIdx = 0
                end
            end
        end
    end
end

-- =========================================================================
-- Dynamic CHAT_EVENTS Construction
-- 从 STREAM_REGISTRY 或 CHANNEL_REGISTRY 动态构建事件列表
-- =========================================================================
local function BuildChatEvents()
    local events = {}
    local eventSet = {}  -- 用于去重
    
    if addon.STREAM_REGISTRY and addon.STREAM_REGISTRY.CHANNEL then
        for categoryKey, category in pairs(addon.STREAM_REGISTRY.CHANNEL) do
            for subKey, subCategory in pairs(category) do
                for _, stream in ipairs(subCategory) do
                    if stream.events then
                        for _, event in ipairs(stream.events) do
                            if not eventSet[event] then
                                eventSet[event] = true
                                table.insert(events, event)
                            end
                        end
                    end
                end
            end
        end
    end
    
    return events
end

-- 初始化 CHAT_EVENTS（会在 InitConfig 时调用）
addon.CHAT_EVENTS = BuildChatEvents()

local function BuildChannelPins()
    local pins = {}
    
    if addon.STREAM_REGISTRY and addon.STREAM_REGISTRY.CHANNEL then
        for categoryKey, category in pairs(addon.STREAM_REGISTRY.CHANNEL) do
            for subKey, subCategory in pairs(category) do
                for _, stream in ipairs(subCategory) do
                    pins[stream.key] = addon:GetStreamProperty(stream, "defaultPinned", false)
                end
            end
        end
    end
    
    return pins
end

local function BuildKitPins()
    local pins = {}
    for _, reg in ipairs(addon.KIT_REGISTRY) do
        pins[reg.key] = reg.defaultPinned or false
    end
    return pins
end

local function BuildSnapshotChannels()
    local channels = {}
    
    if addon.STREAM_REGISTRY and addon.STREAM_REGISTRY.CHANNEL then
        for categoryKey, category in pairs(addon.STREAM_REGISTRY.CHANNEL) do
            for subKey, subCategory in pairs(category) do
                for _, stream in ipairs(subCategory) do
                    channels[stream.key] = addon:GetStreamProperty(stream, "defaultSnapshotted", false)
                end
            end
        end
    end
    
    return channels
end

local function BuildAutoJoinChannels()
    local channels = {}
    
    if addon.STREAM_REGISTRY and addon.STREAM_REGISTRY.CHANNEL and addon.STREAM_REGISTRY.CHANNEL.DYNAMIC then
        for _, stream in ipairs(addon.STREAM_REGISTRY.CHANNEL.DYNAMIC) do
            channels[stream.key] = addon:GetStreamProperty(stream, "defaultAutoJoin", false)
        end
    end
    
    return channels
end

addon.DEFAULTS = {
    __version = 10,
    enabled = true,
    system = {
        timestampEnabled = true,
        timestampFormat = true,
    },
    plugin = {
        shelf = {
            enabled = true,
            theme = addon.CONSTANTS.SHELF_DEFAULT_THEME,
            themes = {},
            colorSet = addon.CONSTANTS.SHELF_DEFAULT_COLORSET,
            anchor = addon.CONSTANTS.SHELF_DEFAULT_ANCHOR,
            direction = "horizontal",
            savedPoint = false,
            dynamicMode = "mark",
            channelPins = BuildChannelPins(),
            kitPins = BuildKitPins(),
            shelfOrder = nil,
            bindings = {},
            kitOptions = {
                countdown = { primary = 10, secondary = 5 },
            },
        },
        chat = {
            font = {
                managed = false,
                font = addon.CONSTANTS.CHAT_DEFAULT_FONT,
                size = 16,
                outline = "NONE",
            },
            visual = {
                channelNameFormat = "SHORT",
            },
            content = {
                emoteRender = true,
                snapshotEnabled = true,
                snapshotChannels = BuildSnapshotChannels(),
                maxPerChannel = 500,
            },
            interaction = {
                clickToCopy = true,
                linkHover = true,
                timestampColor = "FF888888",
                sticky = true,
                tabCycle = true,
            },
        },
        filter = {
            enabled = false,
            repeatFilter = true,
            block = {
                enabled = false,
                names = {},
                keywords = {},
            },
            highlight = {
                enabled = true,
                names = {},
                keywords = {},
                color = "FF00FF00",
            },
        },
        automation = {
            autoWelcome = false,
            welcomeCooldownMinutes = 5,
            currentSocialTab = "guild",
            welcomeGuild  = { enabled = false, sendMode = "channel", templates = function() return GetDefaultWelcomeTemplates("guild") end },
            welcomeParty  = { enabled = false, sendMode = "channel", templates = function() return GetDefaultWelcomeTemplates("party") end },
            welcomeRaid   = { enabled = false, sendMode = "channel", templates = function() return GetDefaultWelcomeTemplates("raid") end },
            autoJoinChannels = BuildAutoJoinChannels(),
        },
    },
    global = {
        chatSnapshot = {},
        chatSnapshotLineCount = 0,
        chatSnapshotMaxTotal = addon.CONSTANTS.SNAPSHOT_MAX_TOTAL_DEFAULT,
    },
}

-- SETTING_REGISTRY moved to Libs/Registry/Settings.lua

function addon:GetSettingInfo(key)
    return addon.SETTING_REGISTRY[key]
end

function addon:GetSettingDefault(key)
    local reg = addon:GetSettingInfo(key)
    if not reg then return nil end
    
    if type(reg.default) == "function" then
        return reg.default()
    else
        return reg.default
    end
end

function addon:GetSettingValue(key)
    local reg = addon:GetSettingInfo(key)
    if not reg then return nil end
    
    if reg.get then return reg.get() end
    if reg.getValue then return reg.getValue() end
    
    if reg.category == "system" then return addon:GetSettingDefault(key) end
    return nil
end

function addon:SetSettingValue(key, value)
    local reg = addon:GetSettingInfo(key)
    if not reg then return end
    
    if reg.set then reg.set(value) end
    if reg.setValue then reg.setValue(value) end
end

function addon:IsSystemSetting(key)
    local reg = addon:GetSettingInfo(key)
    return reg and reg.category == "system"
end
