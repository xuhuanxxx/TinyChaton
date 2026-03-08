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
    return templates
end



-- Storage mode switching removed - one database with profile/account domains
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
    SHELF_BUTTON_TEXT_HPAD = 8,
    SHELF_BUTTON_MAX_WIDTH_FACTOR = 1.9,

    -- Chat Defaults
    CHAT_DEFAULT_FONT = "STANDARD",
    CHAT_DEFAULT_SIZE = 16, -- Added from instruction

    -- Snapshot Defaults
    SNAPSHOT_STORAGE_MAX_DEFAULT = 5000,
    SNAPSHOT_STORAGE_MAX_MIN = 1000,
    SNAPSHOT_STORAGE_MAX_MAX = 20000,
    SNAPSHOT_STORAGE_MAX_STEP = 500,
    SNAPSHOT_REPLAY_MAX_DEFAULT = 200,
    SNAPSHOT_REPLAY_MAX_MIN = 10,
    SNAPSHOT_REPLAY_MAX_MAX = 200,
    SNAPSHOT_REPLAY_MAX_STEP = 10,

    -- Cache & Limits
    MESSAGE_CACHE_MAX_AGE = 600,   -- Domain/Chat/Render/Transformers/TimestampInteraction.lua
    MESSAGE_CACHE_LIMIT = 200,     -- Domain/Chat/Render/Transformers/TimestampInteraction.lua (soft limit)
    MESSAGE_CACHE_HARD_LIMIT = 500,-- Domain/Chat/Render/Transformers/TimestampInteraction.lua (hard limit)
    EMOTE_TICKER_INTERVAL = 0.5,   -- Domain/Chat/Render/Transformers/Emotes.lua

    -- Profile Defaults
    PROFILE_DEFAULT_NAME = "Default",
    PROFILE_NAME_MAX_LENGTH = 32,
}

-- Configuration Accessors

--- Get a configuration value by path safely
--- @param path string Dot-separated path (e.g., "profile.chat.content.snapshotEnabled")
--- @param default any Default value if nil
--- @return any The value or default
function addon:GetConfig(path, default)
    if not addon.db then return default end
    local val = addon.Utils.GetByPath(addon.db, path)
    if val == nil then return default end
    return val
end

--- Set a configuration value by path safely
--- @param path string Dot-separated path
--- @param value any Value to set
function addon:SetConfig(path, value)
    if not addon.db then return end
    addon.Utils.SetByPath(addon.db, path, value)
end

-- Stream Helper Functions

local STREAM_COMPILED = addon.StreamRegistryCompiler:Compile(addon.STREAM_REGISTRY)

local function GetCompiledRegistry()
    local compiled = STREAM_COMPILED
    if type(compiled) ~= "table" then
        error("STREAM_COMPILED is not initialized")
    end
    return compiled
end

function addon:GetStreamByKey(key)
    local compiled = GetCompiledRegistry()
    local byKey = compiled.byKey
    if type(byKey) ~= "table" then
        return nil
    end
    return byKey[key]
end

function addon:IsChannelStream(key)
    local kind = self:GetStreamKind(key)
    return kind == "channel"
end

function addon:IsNoticeStream(key)
    local kind = self:GetStreamKind(key)
    return kind == "notice"
end

function addon:GetStreamKind(key)
    local compiled = GetCompiledRegistry()
    local map = compiled.kindByKey
    if type(map) ~= "table" then
        return nil
    end
    return map[key]
end

function addon:GetStreamGroup(key)
    local compiled = GetCompiledRegistry()
    local map = compiled.groupByKey
    if type(map) ~= "table" then
        return nil
    end
    return map[key]
end

function addon:GetStreamCapabilities(key)
    local compiled = GetCompiledRegistry()
    local map = compiled.capabilitiesByKey
    if type(map) ~= "table" then
        return nil
    end
    return map[key]
end

function addon:GetStreamKeysByGroup(group)
    local compiled = GetCompiledRegistry()
    local byGroup = compiled.streamKeysByGroup
    if type(byGroup) ~= "table" then
        return {}
    end
    local key = type(group) == "string" and string.lower(group) or nil
    return byGroup[key] or {}
end

function addon:GetOutboundStreamKeys()
    local compiled = GetCompiledRegistry()
    return compiled.outboundStreamKeys or {}
end

function addon:GetDynamicStreamKeys()
    local compiled = GetCompiledRegistry()
    return compiled.dynamicStreamKeys or {}
end

function addon:IterateCompiledStreams()
    local compiled = GetCompiledRegistry()
    local orderedKeys = compiled.orderedStreamKeys or {}
    local byKey = compiled.byKey or {}
    local index = 0

    return function()
        index = index + 1
        local streamKey = orderedKeys[index]
        if not streamKey then
            return nil
        end
        return index, byKey[streamKey]
    end
end

function addon:GetStreamProperty(stream, propertyName, fallbackValue)
    if stream[propertyName] ~= nil then
        return stream[propertyName]
    end
    return fallbackValue
end

function addon:ResolveStreamToggle(streamKey, configMap, capabilityField, fallbackValue)
    if type(configMap) == "table" and configMap[streamKey] ~= nil then
        return configMap[streamKey] == true
    end
    local caps = self:GetStreamCapabilities(streamKey)
    if type(caps) == "table" and type(capabilityField) == "string" and caps[capabilityField] ~= nil then
        return caps[capabilityField] == true
    end
    return fallbackValue == true
end

function addon:GetWowChatTypeByEvent(eventName)
    if type(eventName) ~= "string" or eventName == "" then
        return nil
    end
    local compiled = GetCompiledRegistry()
    local map = compiled.eventToWowChatType
    return type(map) == "table" and map[eventName] or nil
end

function addon:GetChatEvents()
    local compiled = GetCompiledRegistry()
    return compiled.chatEvents or {}
end

function addon:GetStreamKeyByEvent(eventName)
    if type(eventName) ~= "string" or eventName == "" then
        return nil
    end
    local compiled = GetCompiledRegistry()
    local map = compiled.eventToStreamKey
    return type(map) == "table" and map[eventName] or nil
end

function addon:ValidateChatEventDerivation()
    local compiled = GetCompiledRegistry()
    local map = compiled.eventToWowChatType
    local streamMap = compiled.eventToStreamKey
    local chatEvents = compiled.chatEvents
    if type(map) ~= "table" then
        error("Compiled eventToWowChatType is not initialized")
    end
    if type(streamMap) ~= "table" then
        error("Compiled eventToStreamKey is not initialized")
    end
    if type(chatEvents) ~= "table" then
        error("Compiled chatEvents is not initialized")
    end

    for _, eventName in ipairs(chatEvents) do
        local wowChatType = map[eventName]
        if type(wowChatType) ~= "string" or wowChatType == "" then
            error("Missing wowChatType mapping for event: " .. tostring(eventName))
        end
        local streamKey = streamMap[eventName]
        if eventName ~= "CHAT_MSG_CHANNEL" and (type(streamKey) ~= "string" or streamKey == "") then
            error("Missing stream key mapping for non-channel event: " .. tostring(eventName))
        end
        if streamKey ~= nil and (type(streamKey) ~= "string" or streamKey == "") then
            error("Invalid stream key mapping for event: " .. tostring(eventName))
        end
    end
    if map["CHAT_MSG_CHANNEL"] ~= "CHANNEL" then
        error("CHAT_MSG_CHANNEL must map to CHANNEL")
    end

    return true
end
local function BuildChannelPins()
    local pins = {}
    for _, stream in addon:IterateCompiledStreams() do
        if stream.kind == "channel" then
            pins[stream.key] = addon:ResolveStreamToggle(stream.key, nil, "pinnable", false)
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

local function BuildSnapshotStreams()
    local channels = {}
    for _, stream in addon:IterateCompiledStreams() do
        channels[stream.key] = addon:ResolveStreamToggle(stream.key, nil, "snapshotDefault", false)
    end

    return channels
end

local function BuildCopyStreams()
    local channels = {}
    for _, stream in addon:IterateCompiledStreams() do
        channels[stream.key] = addon:ResolveStreamToggle(stream.key, nil, "copyDefault", false)
    end
    return channels
end

local function BuildAutoJoinDynamicChannels()
    local selections = {}
    for _, stream in addon:IterateCompiledStreams() do
        if stream.kind == "channel" and stream.group == "dynamic" then
            selections[stream.key] = addon:ResolveStreamToggle(stream.key, nil, "supportsAutoJoin", false)
        end
    end
    return selections
end

addon.DEFAULTS = {
    __version = 14,
    enabled = true,
    profile = {
        buttons = {
            enabled = true,
            dynamicMode = "mark",
            channelPins = BuildChannelPins(),
            kitPins = BuildKitPins(),
            buttonOrder = nil,
            bindings = {},
        },
        shelf = {
            theme = addon.CONSTANTS.SHELF_DEFAULT_THEME,
            themes = {},
            colorSet = addon.CONSTANTS.SHELF_DEFAULT_COLORSET,
            anchor = addon.CONSTANTS.SHELF_DEFAULT_ANCHOR,
            direction = "horizontal",
            savedPoint = false,
            visual = {
                display = {
                    nameStyle = "SHORT_ONE",
                },
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
                display = {
                    channel = {
                        showNumber = true,
                        nameStyle = "SHORT_ONE",
                    },
                },
            },
            content = {
                emoteRender = true,
                repeatFilter = false,
                snapshotEnabled = true,
                snapshotStreams = BuildSnapshotStreams(),
                maxPerStream = 500,
            },
            interaction = {
                clickToCopy = true,
                copyStreams = BuildCopyStreams(),
                linkHover = true,
                timestampColor = "FF888888",
                sticky = true,
                tabCycle = true,
            },
        },
        filter = {
            mode = "disabled", -- "blacklist", "whitelist", "disabled"
            streamBlocked = {},
            blacklist = {
                names = {},
                keywords = {},
            },
            whitelist = {
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
            welcome = {
                enabled = false,
                cooldownMinutes = 5,
            },
            currentSocialTab = "guild",
            welcomeGuild  = { enabled = false, sendMode = "channel", templates = GetDefaultWelcomeTemplates("guild") },
            welcomeParty  = { enabled = false, sendMode = "channel", templates = GetDefaultWelcomeTemplates("party") },
            welcomeRaid   = { enabled = false, sendMode = "channel", templates = GetDefaultWelcomeTemplates("raid") },
            autoJoinDelaySeconds = 3,
            autoJoinDynamicChannels = BuildAutoJoinDynamicChannels(),
            customAutoJoinChannels = {},
            countdown = { primarySeconds = 10, secondarySeconds = 5 },
        },
    },
    account = {
        chatSnapshotStorageDefaultMax = addon.CONSTANTS.SNAPSHOT_STORAGE_MAX_DEFAULT,
        chatSnapshotReplayDefaultMax = addon.CONSTANTS.SNAPSHOT_REPLAY_MAX_DEFAULT,
        policy = {
            mplusPostCompleteMode = "INSTANCE_RELAXED",
            raidOutOfCombatMode = "INSTANCE_RELAXED",
        },
    },
}

-- SETTING_REGISTRY moved to Domain/Settings/SettingsSchema.lua

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

    local getter = reg.accessor and reg.accessor.get
    if type(getter) == "function" then
        return getter()
    end

    if reg.scope == "system_cvar" then return addon:GetSettingDefault(key) end
    error(string.format("Setting '%s' missing getter accessor", tostring(key)))
end

function addon:SetSettingValue(key, value)
    local reg = addon:GetSettingInfo(key)
    if not reg then return end

    local setter = reg.accessor and reg.accessor.set
    if type(setter) ~= "function" then
        error(string.format("Setting '%s' missing setter accessor", tostring(key)))
    end
    setter(value)
end

function addon:IsSystemSetting(key)
    local reg = addon:GetSettingInfo(key)
    return reg and reg.scope == "system_cvar"
end
