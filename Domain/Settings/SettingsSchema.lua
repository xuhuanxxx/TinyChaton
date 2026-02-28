local addonName, addon = ...
local CVarAPI = _G["C_" .. "CVar"]
local L = addon.L

local function ResolveShelfTheme()
    local db = addon.db and addon.db.profile and addon.db.profile.shelf
    local theme = db and db.theme
    if type(theme) ~= "string" or theme == "" then
        return addon.CONSTANTS and addon.CONSTANTS.SHELF_DEFAULT_THEME or "Modern"
    end
    return theme
end

local function GetThemePresetDefaults(theme)
    local defaultTheme = addon.CONSTANTS and addon.CONSTANTS.SHELF_DEFAULT_THEME or "Modern"
    local key = theme or defaultTheme
    local preset = addon.ThemeRegistry and addon.ThemeRegistry.GetPreset and addon.ThemeRegistry:GetPreset(key)
    local props = preset and preset.properties
    if type(props) == "table" then
        return props
    end
    return {}
end

local function GetThemeVal(prop)
    local theme = ResolveShelfTheme()
    local themeTable = addon.db and addon.db.profile and addon.db.profile.shelf and addon.db.profile.shelf.themes and addon.db.profile.shelf.themes[theme]
    if themeTable and themeTable[prop] ~= nil then
        return themeTable[prop]
    end
    local defaults = GetThemePresetDefaults(theme)
    return defaults[prop]
end

-- ============================================
-- SETTING_REGISTRY - Declarative Configuration
-- ============================================

addon.SETTING_REGISTRY = {
    -- --------------------------------------------
    -- 1. CHAT - FONT & VISUAL
    -- --------------------------------------------
    fontManaged = {
        scope = "profile",
        valueType = "boolean",
        get = function() return addon.db.profile.chat.font.managed end,
        set = function(v) addon.db.profile.chat.font.managed = v end,
        default = false,
        ui = { type = "checkbox", label = "LABEL_FONT_MANAGED", tooltip = "LABEL_FONT_MANAGED_DESC", page = "chat", section = "SECTION_CHAT_FONT" },
    },
    fontSize = {
        scope = "profile",
        valueType = "number",
        get = function() return addon.db.profile.chat.font.size end,
        set = function(v) addon.db.profile.chat.font.size = v end,
        getValue = function()
            return addon.db.profile.chat.font.size
        end,
        setValue = function(v) end, -- Managed by ApplyChatFontSettings
        default = 16,
        ui = { 
            type = "slider", label = "LABEL_FONT_SIZE", page = "chat", section = "SECTION_CHAT_FONT", min = 10, max = 24, step = 1,
            isEnabled = function() return addon:GetSettingValue("fontManaged") end,
        },
    },
    fontOutline = {
        scope = "profile",
        valueType = "string",
        get = function() return addon.db.profile.chat.font.outline end,
        set = function(v) addon.db.profile.chat.font.outline = v end,
        getValue = function()
            return addon.db.profile.chat.font.outline
        end,
        setValue = function(v) end,
        default = "NONE",
        ui = {
            type = "dropdown", label = "LABEL_FONT_OUTLINE", page = "chat", section = "SECTION_CHAT_FONT",
            isEnabled = function() return addon:GetSettingValue("fontManaged") end,
            options = function()
                local c = Settings.CreateControlTextContainer()
                c:Add("NONE", L["LABEL_OUTLINE_NONE"])
                c:Add("OUTLINE", L["LABEL_OUTLINE_NORMAL"])
                c:Add("THICKOUTLINE", L["LABEL_OUTLINE_THICK"])
                return c:GetData()
            end,
        },
    },
    channelNameFormat = {
        scope = "profile",
        valueType = "string",
        get = function() return addon.db.profile.chat.visual.channelNameFormat end,
        set = function(v) addon.db.profile.chat.visual.channelNameFormat = v end,
        default = "SHORT",
        ui = {
            type = "dropdown", label = "LABEL_STREAM_NAME_FORMAT_DESC_LABEL", page = "chat", section = "SECTION_CHAT_CHANNEL",
            options = function()
                local c = Settings.CreateControlTextContainer()
                c:Add("SHORT", L["LABEL_STREAM_FORMAT_SHORT"])
                c:Add("FULL", L["LABEL_STREAM_FORMAT_FULL_LABEL"])
                c:Add("NUMBER", L["LABEL_STREAM_FORMAT_NUMBER_LABEL"])
                c:Add("NUMBER_SHORT", L["LABEL_STREAM_FORMAT_NUMBER_SHORT"])
                return c:GetData()
            end,
        },
    },

    -- --------------------------------------------
    -- 2. CHAT - CONTENT (Emotes, Snapshots)
    -- --------------------------------------------
    emoteRender = {
        scope = "profile",
        valueType = "boolean",
        get = function() return addon.db.profile.chat.content.emoteRender end,
        set = function(v) addon.db.profile.chat.content.emoteRender = v end,
        default = true,
        ui = { type = "checkbox", label = "LABEL_EMOTE_RENDER", page = "chat", section = "SECTION_CHAT_CONTENT" },
    },
    snapshotEnabled = {
        scope = "profile",
        valueType = "boolean",
        get = function() return addon.db.profile.chat.content.snapshotEnabled end,
        set = function(v) addon.db.profile.chat.content.snapshotEnabled = v end,
        default = true,
        ui = { type = "checkbox", label = "LABEL_SNAPSHOT_ENABLED", tooltip = "LABEL_SNAPSHOT_ENABLED_DESC", page = "chat", section = "SECTION_CHAT_CONTENT" },
    },

    -- --------------------------------------------
    -- 3. CHAT - INTERACTION ENHANCEMENT
    -- --------------------------------------------
    timestampEnabled = { -- SYSTEM CVAR MIRROR
        scope = "system_cvar",
        valueType = "boolean",
        getValue = function() return CVarAPI.GetCVar("showTimestamps") ~= "none" end,
        setValue = function(value)
            if value then
                local fmt = addon:GetSettingValue("timestampFormat") or "%H:%M "
                CVarAPI.SetCVar("showTimestamps", fmt)
            else
                CVarAPI.SetCVar("showTimestamps", "none")
            end
        end,
        default = function() return CVarAPI.GetCVar("showTimestamps") ~= "none" end,
        ui = { type = "checkbox", label = "LABEL_TIMESTAMP_ENABLED", page = "chat", section = "SECTION_CHAT_INTERACTION" },
    },
    timestampFormat = { -- SYSTEM CVAR MIRROR
        scope = "system_cvar",
        valueType = "string",
        getValue = function()
            local cv = CVarAPI.GetCVar("showTimestamps")
            return cv ~= "none" and cv or "%H:%M "
        end,
        setValue = function(value)
            if CVarAPI.GetCVar("showTimestamps") ~= "none" then
                CVarAPI.SetCVar("showTimestamps", value)
            end
        end,
        default = function()
            local cv = CVarAPI.GetCVar("showTimestamps")
            return cv ~= "none" and cv or "%H:%M "
        end,
        ui = {
            type = "dropdown", label = "LABEL_FORMAT", page = "chat", section = "SECTION_CHAT_INTERACTION",
            isEnabled = function() return CVarAPI.GetCVar("showTimestamps") ~= "none" end,
            options = function()
                local c = Settings.CreateControlTextContainer()
                local formats = {
                    { fmt = "%I:%M ",       label = "03:27" },
                    { fmt = "%I:%M:%S ",    label = "03:27:32" },
                    { fmt = "%I:%M %p ",    label = "03:27 PM" },
                    { fmt = "%I:%M:%S %p ", label = "03:27:32 PM" },
                    { fmt = "%H:%M ",       label = "15:27" },
                    { fmt = "%H:%M:%S ",    label = "15:27:32" },
                }
                for _, info in ipairs(formats) do c:Add(info.fmt, info.label) end
                return c:GetData()
            end,
        },
    },
    timestampColor = {
        scope = "profile",
        valueType = "color",
        get = function() return addon.db.profile.chat.interaction.timestampColor end,
        set = function(v) addon.db.profile.chat.interaction.timestampColor = v end,
        default = "FF888888",
        ui = { type = "color", label = "ACTION_COPY_TIMESTAMP_COLOR", page = "chat", section = "SECTION_CHAT_INTERACTION" },
    },
    clickToCopy = {
        scope = "profile",
        valueType = "boolean",
        get = function() return addon.db.profile.chat.interaction.clickToCopy end,
        set = function(v) addon.db.profile.chat.interaction.clickToCopy = v end,
        default = true,
        ui = { type = "checkbox", label = "LABEL_COPY_CLICK_TO_COPY", tooltip = "LABEL_COPY_CLICK_TO_COPY_DESC", page = "chat", section = "SECTION_CHAT_INTERACTION" },
    },
    linkHover = {
        scope = "profile",
        valueType = "boolean",
        get = function() return addon.db.profile.chat.interaction.linkHover end,
        set = function(v) addon.db.profile.chat.interaction.linkHover = v end,
        default = true,
        ui = { type = "checkbox", label = "LABEL_TWEAKS_LINK_HOVER", tooltip = "LABEL_TWEAKS_LINK_HOVER_DESC", page = "chat", section = "SECTION_CHAT_INTERACTION" },
    },
    sticky = {
        scope = "profile",
        valueType = "boolean",
        get = function() return addon.db.profile.chat.interaction.sticky end,
        set = function(v) addon.db.profile.chat.interaction.sticky = v end,
        default = true,
        ui = { type = "checkbox", label = "LABEL_STREAM_STICKY_LABEL", tooltip = "LABEL_STREAM_STICKY_DESC_LABEL", page = "chat", section = "SECTION_CHAT_INTERACTION" },
    },
    tabCycle = {
        scope = "profile",
        valueType = "boolean",
        get = function() return addon.db.profile.chat.interaction.tabCycle end,
        set = function(v) addon.db.profile.chat.interaction.tabCycle = v end,
        default = true,
        ui = { type = "checkbox", label = "LABEL_TWEAKS_TAB_CYCLE", tooltip = "LABEL_TWEAKS_TAB_CYCLE_DESC", page = "chat", section = "SECTION_CHAT_INTERACTION" },
    },

    -- --------------------------------------------
    -- 4. SHELF - APPEARANCE & BEHAVIOR
    -- --------------------------------------------
    shelfEnabled = {
        scope = "profile",
        valueType = "boolean",
        get = function() return addon.db.profile.buttons.enabled end,
        set = function(v) addon.db.profile.buttons.enabled = v end,
        default = true,
    },
    shelfTheme = {
        scope = "profile",
        valueType = "string",
        get = function() return addon.db.profile.shelf.theme end,
        set = function(v) addon.db.profile.shelf.theme = v end,
        default = function() return addon.CONSTANTS and addon.CONSTANTS.SHELF_DEFAULT_THEME or "Modern" end,
    },
    shelfAnchor = {
        scope = "profile",
        valueType = "string",
        get = function() return addon.db.profile.shelf.anchor end,
        set = function(v) addon.db.profile.shelf.anchor = v end,
        default = function() return addon.CONSTANTS and addon.CONSTANTS.SHELF_DEFAULT_ANCHOR or "chat_top" end,
    },
    shelfDirection = {
        scope = "profile",
        valueType = "string",
        get = function() return addon.db.profile.shelf.direction end,
        set = function(v) addon.db.profile.shelf.direction = v end,
        default = "horizontal",
    },
    shelfDynamicMode = {
        scope = "profile",
        valueType = "string",
        get = function() return addon.db.profile.buttons.dynamicMode end,
        set = function(v) addon.db.profile.buttons.dynamicMode = v end,
        default = "mark",
    },
    shelfColorSet = {
        scope = "profile",
        valueType = "string",
        get = function() return addon.Shelf and addon.Shelf.GetThemeProperty and addon.Shelf:GetThemeProperty("colorSet") end,
        set = function(v) if addon.Shelf and addon.Shelf.SetThemeProperty then addon.Shelf:SetThemeProperty("colorSet", v) end end,
        default = function()
            local theme = addon.db and addon.db.profile.shelf.theme or addon.CONSTANTS.SHELF_DEFAULT_THEME
            local preset = addon.ThemeRegistry and addon.ThemeRegistry:GetPreset(theme)
            return preset and preset.properties and preset.properties.colorSet or addon.CONSTANTS.SHELF_DEFAULT_COLORSET
        end,
    },

    -- --------------------------------------------
    -- 5. THEME PAGE - APPEARANCE PROXY SETTINGS
    -- --------------------------------------------
    -- NOTE: theme* defaults are runtime-resolved from current selected theme.
    -- They must not be treated as static registration-time constants.
    themeFont = {
        scope = "profile",
        valueType = "string",
        path = "profile.shelf.themes.{theme}.font",
        pathContext = function()
            return { theme = ResolveShelfTheme() }
        end,
        default = function()
            return GetThemeVal("font") or addon.CONSTANTS.SHELF_DEFAULT_FONT
        end,
        normalizeGet = function(value)
            if value == "CHAT" or value == "DAMAGE" then
                return value
            end
            if value and value ~= "" and value ~= "STANDARD" then
                return value
            end
            return "STANDARD"
        end,
        normalizeSet = function(value)
            if value == "STANDARD" then
                return nil
            end
            return value
        end,
        onChange = function()
            if addon.ApplyShelfSettings then addon:ApplyShelfSettings() end
            if addon.RefreshShelfPreview then addon.RefreshShelfPreview() end
        end,
        applyAllSettings = false,
        ui = {
            type = "dropdown",
            page = "appearance",
            section = "SECTION_GENERAL_APPEARANCE",
            label = "LABEL_FONT",
            options = function()
                local c = Settings.CreateControlTextContainer()
                c:Add("STANDARD", L["FONT_STANDARD"])
                c:Add("CHAT", L["FONT_CHAT"])
                c:Add("DAMAGE", L["FONT_DAMAGE"])
                local current = GetThemeVal("font")
                if current and current ~= "" and current ~= "STANDARD" and current ~= "CHAT" and current ~= "DAMAGE" then
                    c:Add(current, L["LABEL_CUSTOM"] .. " (" .. (current:match("([^\\]+)$") or current) .. ")")
                end
                return c:GetData()
            end,
        },
    },
    themeColorSet = {
        scope = "profile",
        valueType = "string",
        path = "profile.shelf.themes.{theme}.colorSet",
        pathContext = function()
            return { theme = ResolveShelfTheme() }
        end,
        default = function()
            return GetThemeVal("colorSet") or addon.CONSTANTS.SHELF_DEFAULT_COLORSET
        end,
        onChange = function()
            if addon.ApplyShelfSettings then addon:ApplyShelfSettings() end
            if addon.RefreshShelfPreview then addon.RefreshShelfPreview() end
        end,
        applyAllSettings = false,
        ui = {
            type = "dropdown",
            page = "appearance",
            section = "SECTION_GENERAL_APPEARANCE",
            label = "LABEL_SHELF_COLORSET",
            options = function()
                return addon:GetColorSetOptions()
            end,
        },
    },
    themeFontSize = {
        scope = "profile",
        valueType = "number",
        path = "profile.shelf.themes.{theme}.fontSize",
        pathContext = function() return { theme = ResolveShelfTheme() } end,
        default = function()
            return GetThemeVal("fontSize") or addon.CONSTANTS.SHELF_DEFAULT_FONT_SIZE
        end,
        onChange = function()
            if addon.ApplyShelfSettings then addon:ApplyShelfSettings() end
            if addon.RefreshShelfPreview then addon.RefreshShelfPreview() end
        end,
        applyAllSettings = false,
        ui = { type = "slider", page = "appearance", section = "SECTION_GENERAL_APPEARANCE", label = "LABEL_FONT_SIZE", min = 8, max = 24, step = 1 },
    },
    themeButtonSize = {
        scope = "profile",
        valueType = "number",
        path = "profile.shelf.themes.{theme}.buttonSize",
        pathContext = function() return { theme = ResolveShelfTheme() } end,
        default = function()
            return GetThemeVal("buttonSize") or addon.CONSTANTS.SHELF_DEFAULT_BUTTON_SIZE
        end,
        onChange = function()
            if addon.ApplyShelfSettings then addon:ApplyShelfSettings() end
            if addon.RefreshShelfPreview then addon.RefreshShelfPreview() end
        end,
        applyAllSettings = false,
        ui = { type = "slider", page = "appearance", section = "SECTION_GENERAL_APPEARANCE", label = "LABEL_SHELF_BUTTON_SIZE", min = 16, max = 40, step = 1 },
    },
    themeSpacing = {
        scope = "profile",
        valueType = "number",
        path = "profile.shelf.themes.{theme}.spacing",
        pathContext = function() return { theme = ResolveShelfTheme() } end,
        default = function()
            return GetThemeVal("spacing") or addon.CONSTANTS.SHELF_DEFAULT_SPACING
        end,
        onChange = function()
            if addon.ApplyShelfSettings then addon:ApplyShelfSettings() end
            if addon.RefreshShelfPreview then addon.RefreshShelfPreview() end
        end,
        applyAllSettings = false,
        ui = { type = "slider", page = "appearance", section = "SECTION_GENERAL_APPEARANCE", label = "LABEL_SHELF_SPACING", min = 0, max = 10, step = 1 },
    },
    themeScale = {
        scope = "profile",
        valueType = "number",
        path = "profile.shelf.themes.{theme}.scale",
        pathContext = function() return { theme = ResolveShelfTheme() } end,
        default = function()
            return GetThemeVal("scale") or addon.CONSTANTS.SHELF_DEFAULT_SCALE
        end,
        onChange = function()
            if addon.ApplyShelfSettings then addon:ApplyShelfSettings() end
            if addon.RefreshShelfPreview then addon.RefreshShelfPreview() end
        end,
        applyAllSettings = false,
        ui = { type = "slider", page = "appearance", section = "SECTION_GENERAL_APPEARANCE", label = "LABEL_SHELF_SCALE", min = 0.5, max = 2.0, step = 0.1 },
    },
    themeAlpha = {
        scope = "profile",
        valueType = "number",
        path = "profile.shelf.themes.{theme}.alpha",
        pathContext = function() return { theme = ResolveShelfTheme() } end,
        default = function()
            return GetThemeVal("alpha") or addon.CONSTANTS.SHELF_DEFAULT_ALPHA
        end,
        onChange = function()
            if addon.ApplyShelfSettings then addon:ApplyShelfSettings() end
            if addon.RefreshShelfPreview then addon.RefreshShelfPreview() end
        end,
        applyAllSettings = false,
        ui = { type = "slider", page = "appearance", section = "SECTION_GENERAL_APPEARANCE", label = "LABEL_SHELF_ALPHA", min = 0.2, max = 1.0, step = 0.1 },
    },

    -- --------------------------------------------
    -- 6. DATA PAGE - HISTORY LIMITS
    -- --------------------------------------------
    dataSnapshotStorageDefaultMax = {
        scope = "account",
        valueType = "number",
        path = "account.chatSnapshotStorageDefaultMax",
        default = function() return addon.CONSTANTS.SNAPSHOT_STORAGE_MAX_DEFAULT end,
        onChange = function()
            if addon.NormalizeSnapshotLimits then addon:NormalizeSnapshotLimits() end
            if addon.SyncTrimSnapshotToLimit and addon.GetEffectiveSnapshotStorageLimit then
                addon:SyncTrimSnapshotToLimit(addon:GetEffectiveSnapshotStorageLimit())
            end
            if addon.TriggerEviction then addon:TriggerEviction() end
            if addon.RefreshAllSettings then addon:RefreshAllSettings() end
        end,
        applyAllSettings = false,
        ui = { type = "slider", page = "data", section = "SECTION_HISTORY_STORAGE", label = "LABEL_SNAPSHOT_STORAGE_DEFAULT_MAX", tooltip = "TOOLTIP_SNAPSHOT_STORAGE_DEFAULT_MAX", min = addon.CONSTANTS.SNAPSHOT_STORAGE_MAX_MIN, max = addon.CONSTANTS.SNAPSHOT_STORAGE_MAX_MAX, step = addon.CONSTANTS.SNAPSHOT_STORAGE_MAX_STEP },
    },
    dataSnapshotStorageOverrideEnabled = {
        scope = "profile",
        valueType = "boolean",
        get = function()
            local settings = addon.GetSnapshotLimitsSettings and addon:GetSnapshotLimitsSettings() or {}
            return settings.snapshotStorageOverrideEnabled == true
        end,
        set = function(v)
            if addon.SetSnapshotStorageOverrideEnabled then
                addon:SetSnapshotStorageOverrideEnabled(v)
            end
        end,
        default = false,
        onChange = function(value)
            if value and addon.GetSnapshotLimitsSettings and addon.GetEffectiveSnapshotStorageLimit and addon.SetSnapshotStorageOverrideValue then
                local settings = addon:GetSnapshotLimitsSettings()
                if settings.snapshotStorageOverrideValue == nil then
                    addon:SetSnapshotStorageOverrideValue(addon:GetEffectiveSnapshotStorageLimit())
                end
            end
            if addon.NormalizeSnapshotLimits then addon:NormalizeSnapshotLimits() end
            if addon.SyncTrimSnapshotToLimit and addon.GetEffectiveSnapshotStorageLimit then
                addon:SyncTrimSnapshotToLimit(addon:GetEffectiveSnapshotStorageLimit())
            end
            if addon.TriggerEviction then addon:TriggerEviction() end
            if addon.RefreshAllSettings then addon:RefreshAllSettings() end
        end,
        applyAllSettings = false,
        ui = { type = "checkbox", page = "data", section = "SECTION_HISTORY_STORAGE", label = "LABEL_SNAPSHOT_STORAGE_OVERRIDE_ENABLE", tooltip = "TOOLTIP_SNAPSHOT_STORAGE_OVERRIDE_ENABLE" },
    },
    dataSnapshotStorageOverrideValue = {
        scope = "profile",
        valueType = "number",
        get = function()
            local settings = addon.GetSnapshotLimitsSettings and addon:GetSnapshotLimitsSettings() or {}
            if settings.snapshotStorageOverrideValue ~= nil then
                return settings.snapshotStorageOverrideValue
            end
            return addon.GetEffectiveSnapshotStorageLimit and addon:GetEffectiveSnapshotStorageLimit() or addon.CONSTANTS.SNAPSHOT_STORAGE_MAX_DEFAULT
        end,
        set = function(v)
            if addon.SetSnapshotStorageOverrideValue then
                addon:SetSnapshotStorageOverrideValue(v)
            end
        end,
        default = function() return addon.CONSTANTS.SNAPSHOT_STORAGE_MAX_DEFAULT end,
        onChange = function()
            if addon.NormalizeSnapshotLimits then addon:NormalizeSnapshotLimits() end
            if addon.SyncTrimSnapshotToLimit and addon.GetEffectiveSnapshotStorageLimit then
                addon:SyncTrimSnapshotToLimit(addon:GetEffectiveSnapshotStorageLimit())
            end
            if addon.TriggerEviction then addon:TriggerEviction() end
            if addon.RefreshAllSettings then addon:RefreshAllSettings() end
        end,
        applyAllSettings = false,
        ui = { type = "slider", page = "data", section = "SECTION_HISTORY_STORAGE", label = "LABEL_SNAPSHOT_STORAGE_OVERRIDE_VALUE", tooltip = "TOOLTIP_SNAPSHOT_STORAGE_OVERRIDE_VALUE", min = addon.CONSTANTS.SNAPSHOT_STORAGE_MAX_MIN, max = addon.CONSTANTS.SNAPSHOT_STORAGE_MAX_MAX, step = addon.CONSTANTS.SNAPSHOT_STORAGE_MAX_STEP },
    },
    dataSnapshotReplayDefaultMax = {
        scope = "account",
        valueType = "number",
        path = "account.chatSnapshotReplayDefaultMax",
        default = function() return addon.CONSTANTS.SNAPSHOT_REPLAY_MAX_DEFAULT end,
        onChange = function()
            if addon.NormalizeSnapshotLimits then addon:NormalizeSnapshotLimits() end
            if addon.SyncTrimSnapshotToLimit and addon.GetEffectiveSnapshotStorageLimit then
                addon:SyncTrimSnapshotToLimit(addon:GetEffectiveSnapshotStorageLimit())
            end
            if addon.TriggerEviction then addon:TriggerEviction() end
            if addon.RefreshAllSettings then addon:RefreshAllSettings() end
        end,
        applyAllSettings = false,
        ui = { type = "slider", page = "data", section = "SECTION_HISTORY_REPLAY", label = "LABEL_SNAPSHOT_REPLAY_DEFAULT_MAX", tooltip = "TOOLTIP_SNAPSHOT_REPLAY_DEFAULT_MAX", min = addon.CONSTANTS.SNAPSHOT_REPLAY_MAX_MIN, max = addon.CONSTANTS.SNAPSHOT_REPLAY_MAX_MAX, step = addon.CONSTANTS.SNAPSHOT_REPLAY_MAX_STEP },
    },
    dataSnapshotReplayOverrideEnabled = {
        scope = "profile",
        valueType = "boolean",
        get = function()
            local settings = addon.GetSnapshotLimitsSettings and addon:GetSnapshotLimitsSettings() or {}
            return settings.snapshotReplayOverrideEnabled == true
        end,
        set = function(v)
            if addon.SetSnapshotReplayOverrideEnabled then
                addon:SetSnapshotReplayOverrideEnabled(v)
            end
        end,
        default = false,
        onChange = function(value)
            if value and addon.GetSnapshotLimitsSettings and addon.GetEffectiveSnapshotReplayLimit and addon.SetSnapshotReplayOverrideValue then
                local settings = addon:GetSnapshotLimitsSettings()
                if settings.snapshotReplayOverrideValue == nil then
                    addon:SetSnapshotReplayOverrideValue(addon:GetEffectiveSnapshotReplayLimit())
                end
            end
            if addon.NormalizeSnapshotLimits then addon:NormalizeSnapshotLimits() end
            if addon.SyncTrimSnapshotToLimit and addon.GetEffectiveSnapshotStorageLimit then
                addon:SyncTrimSnapshotToLimit(addon:GetEffectiveSnapshotStorageLimit())
            end
            if addon.TriggerEviction then addon:TriggerEviction() end
            if addon.RefreshAllSettings then addon:RefreshAllSettings() end
        end,
        applyAllSettings = false,
        ui = { type = "checkbox", page = "data", section = "SECTION_HISTORY_REPLAY", label = "LABEL_SNAPSHOT_REPLAY_OVERRIDE_ENABLE", tooltip = "TOOLTIP_SNAPSHOT_REPLAY_OVERRIDE_ENABLE" },
    },
    dataSnapshotReplayOverrideValue = {
        scope = "profile",
        valueType = "number",
        get = function()
            local settings = addon.GetSnapshotLimitsSettings and addon:GetSnapshotLimitsSettings() or {}
            if settings.snapshotReplayOverrideValue ~= nil then
                return settings.snapshotReplayOverrideValue
            end
            return addon.GetEffectiveSnapshotReplayLimit and addon:GetEffectiveSnapshotReplayLimit() or addon.CONSTANTS.SNAPSHOT_REPLAY_MAX_DEFAULT
        end,
        set = function(v)
            if addon.SetSnapshotReplayOverrideValue then
                addon:SetSnapshotReplayOverrideValue(v)
            end
        end,
        default = function() return addon.CONSTANTS.SNAPSHOT_REPLAY_MAX_DEFAULT end,
        onChange = function()
            if addon.NormalizeSnapshotLimits then addon:NormalizeSnapshotLimits() end
            if addon.SyncTrimSnapshotToLimit and addon.GetEffectiveSnapshotStorageLimit then
                addon:SyncTrimSnapshotToLimit(addon:GetEffectiveSnapshotStorageLimit())
            end
            if addon.TriggerEviction then addon:TriggerEviction() end
            if addon.RefreshAllSettings then addon:RefreshAllSettings() end
        end,
        applyAllSettings = false,
        ui = { type = "slider", page = "data", section = "SECTION_HISTORY_REPLAY", label = "LABEL_SNAPSHOT_REPLAY_OVERRIDE_VALUE", tooltip = "TOOLTIP_SNAPSHOT_REPLAY_OVERRIDE_VALUE", min = addon.CONSTANTS.SNAPSHOT_REPLAY_MAX_MIN, max = addon.CONSTANTS.SNAPSHOT_REPLAY_MAX_MAX, step = addon.CONSTANTS.SNAPSHOT_REPLAY_MAX_STEP },
    },

    -- --------------------------------------------
    -- 7. AUTOMATION PAGE - SIMPLE SETTINGS
    -- --------------------------------------------
    automationWelcomeEnabled = {
        scope = "profile",
        valueType = "boolean",
        path = "profile.automation.welcome.enabled",
        default = false,
        ensureTablePath = true,
        applyAllSettings = false,
        ui = { type = "checkbox", page = "automation", section = "LABEL_AUTO_WELCOME", label = "LABEL_ENABLED" },
    },
    automationWelcomeCooldownMinutes = {
        scope = "profile",
        valueType = "number",
        path = "profile.automation.welcome.cooldownMinutes",
        default = 5,
        ensureTablePath = true,
        applyAllSettings = false,
        ui = { type = "slider", page = "automation", section = "LABEL_AUTO_WELCOME", label = "LABEL_WELCOME_COOLDOWN", min = 0, max = 60, step = 5 },
    },
    automationCountdownPrimarySeconds = {
        scope = "profile",
        valueType = "number",
        path = "profile.automation.countdown.primarySeconds",
        default = 10,
        ensureTablePath = true,
        applyAllSettings = false,
        ui = { type = "slider", page = "automation", section = "SECTION_COUNTDOWN_TIMER", label = "ACTION_TIMER_PRIMARY", tooltip = "ACTION_TIMER_PRIMARY_DESC", min = 3, max = 60, step = 1 },
    },
    automationCountdownSecondarySeconds = {
        scope = "profile",
        valueType = "number",
        path = "profile.automation.countdown.secondarySeconds",
        default = 5,
        ensureTablePath = true,
        applyAllSettings = false,
        ui = { type = "slider", page = "automation", section = "SECTION_COUNTDOWN_TIMER", label = "ACTION_TIMER_SECONDARY", tooltip = "ACTION_TIMER_SECONDARY_DESC", min = 3, max = 60, step = 1 },
    },
}

for key, reg in pairs(addon.SETTING_REGISTRY) do
    reg.key = reg.key or key

    if not reg.scope and reg.category then
        reg.scope = (reg.category == "system") and "system_cvar" or "profile"
    end

    if not reg.valueType then
        local def = reg.default
        if type(def) == "function" then def = def() end
        local t = type(def)
        if t == "boolean" then
            reg.valueType = "boolean"
        elseif t == "number" then
            reg.valueType = "number"
        elseif t == "table" then
            reg.valueType = "table"
        else
            reg.valueType = "string"
        end
    end

    reg.accessor = reg.accessor or {}
    reg.accessor.get = reg.accessor.get or reg.get or reg.getValue
    reg.accessor.set = reg.accessor.set or reg.set or reg.setValue
end
