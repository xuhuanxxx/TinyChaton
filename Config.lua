local addonName, addon = ...
local L = addon.L

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
    SHELF_DEFAULT_FONT = "Fonts\\FRIZQT__.TTF",
    SHELF_DEFAULT_FONT_SIZE = 14,
    SHELF_DEFAULT_FONT = "Fonts\\FRIZQT__.TTF",
    SHELF_DEFAULT_THEME = "Modern",
    SHELF_DEFAULT_COLORSET = "rainbow",
    SHELF_DEFAULT_ANCHOR = "chat_top",
}

addon.CHAT_EVENTS = {
    "CHAT_MSG_SAY", "CHAT_MSG_YELL", "CHAT_MSG_GUILD", "CHAT_MSG_OFFICER",
    "CHAT_MSG_PARTY", "CHAT_MSG_PARTY_LEADER", "CHAT_MSG_RAID", "CHAT_MSG_RAID_LEADER",
    "CHAT_MSG_INSTANCE_CHAT", "CHAT_MSG_INSTANCE_CHAT_LEADER", "CHAT_MSG_CHANNEL",
    "CHAT_MSG_WHISPER", "CHAT_MSG_EMOTE", "CHAT_MSG_TEXT_EMOTE", "CHAT_MSG_SYSTEM",
    "CHAT_MSG_BATTLEGROUND", "CHAT_MSG_BATTLEGROUND_LEADER", "CHAT_MSG_RAID_WARNING"
}

local function BuildChannelPins()
    local pins = {}
    for _, reg in ipairs(addon.CHANNEL_REGISTRY) do
        if reg.isSystem or reg.isDynamic then
            pins[reg.key] = reg.defaultPinned or false
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
    for _, reg in ipairs(addon.CHANNEL_REGISTRY) do
        if not reg.isSystemMsg and not reg.isNotStorable then
            channels[reg.key] = reg.defaultSnapshotted or false
        end
    end
    return channels
end

local function BuildAutoJoinChannels()
    local channels = {}
    for _, reg in ipairs(addon.CHANNEL_REGISTRY) do
        if reg.isDynamic then
            channels[reg.key] = reg.defaultAutoJoin or false
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
                font = nil,
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
            welcomeGuild  = { enabled = false, sendMode = "channel", templates = {} },
            welcomeParty  = { enabled = false, sendMode = "channel", templates = {} },
            welcomeRaid   = { enabled = false, sendMode = "channel", templates = {} },
            autoJoinChannels = BuildAutoJoinChannels(),
        },
    },
    data = {
        chatSnapshot = {},
        chatSnapshotLineCount = 0,
        chatSnapshotMaxTotal = 5000,
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
