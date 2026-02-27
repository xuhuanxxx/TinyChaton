local addonName, addon = ...
local CVarAPI = _G["C_" .. "CVar"]
local L = addon.L

-- ============================================
-- SETTING_REGISTRY - Declarative Configuration
-- ============================================

addon.SETTING_REGISTRY = {
    -- --------------------------------------------
    -- 1. CHAT - FONT & VISUAL
    -- --------------------------------------------
    fontManaged = {
        category = "plugin",
        get = function() return addon.db.plugin.chat.font.managed end,
        set = function(v) addon.db.plugin.chat.font.managed = v end,
        default = false,
        ui = { type = "checkbox", label = "LABEL_FONT_MANAGED", tooltip = "LABEL_FONT_MANAGED_DESC", page = "chat", section = "SECTION_CHAT_FONT" },
    },
    fontSize = {
        category = "system",
        get = function() return addon.db.system and addon.db.system.fontSize end,
        set = function(v) if addon.db.system then addon.db.system.fontSize = v end end,
        getValue = function()
            local _, s = ChatFrame1:GetFont()
            return s or 14
        end,
        setValue = function(v) end, -- Managed by ApplyChatFontSettings
        default = function()
            local _, s = ChatFrame1:GetFont()
            return s or 14
        end,
        ui = { 
            type = "slider", label = "LABEL_FONT_SIZE", page = "chat", section = "SECTION_CHAT_FONT", min = 10, max = 24, step = 1,
            isEnabled = function() return addon:GetSettingValue("fontManaged") end,
        },
    },
    fontOutline = {
        category = "system",
        get = function() return addon.db.system and addon.db.system.fontOutline end,
        set = function(v) if addon.db.system then addon.db.system.fontOutline = v end end,
        getValue = function()
            local _, _, outline = ChatFrame1:GetFont()
            return (outline == "" or not outline) and "NONE" or outline
        end,
        setValue = function(v) end,
        default = function()
            local _, _, outline = ChatFrame1:GetFont()
            return (outline == "" or not outline) and "NONE" or outline
        end,
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
        category = "plugin",
        get = function() return addon.db.plugin.chat.visual.channelNameFormat end,
        set = function(v) addon.db.plugin.chat.visual.channelNameFormat = v end,
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
        category = "plugin",
        get = function() return addon.db.plugin.chat.content.emoteRender end,
        set = function(v) addon.db.plugin.chat.content.emoteRender = v end,
        default = true,
        ui = { type = "checkbox", label = "LABEL_EMOTE_RENDER", page = "chat", section = "SECTION_CHAT_CONTENT" },
    },
    snapshotEnabled = {
        category = "plugin",
        get = function() return addon.db.plugin.chat.content.snapshotEnabled end,
        set = function(v) addon.db.plugin.chat.content.snapshotEnabled = v end,
        default = true,
        ui = { type = "checkbox", label = "LABEL_SNAPSHOT_ENABLED", tooltip = "LABEL_SNAPSHOT_ENABLED_DESC", page = "chat", section = "SECTION_CHAT_CONTENT" },
    },

    -- --------------------------------------------
    -- 3. CHAT - INTERACTION ENHANCEMENT
    -- --------------------------------------------
    timestampEnabled = { -- SYSTEM CVAR MIRROR
        category = "system",
        get = function() return addon.db.system and addon.db.system.timestampEnabled end,
        set = function(v) if addon.db.system then addon.db.system.timestampEnabled = v end end,
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
        category = "system",
        get = function() return addon.db.system and addon.db.system.timestampFormat end,
        set = function(v) if addon.db.system then addon.db.system.timestampFormat = v end end,
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
        category = "plugin",
        get = function() return addon.db.plugin.chat.interaction.timestampColor end,
        set = function(v) addon.db.plugin.chat.interaction.timestampColor = v end,
        default = "FF888888",
        ui = { type = "color", label = "ACTION_COPY_TIMESTAMP_COLOR", page = "chat", section = "SECTION_CHAT_INTERACTION" },
    },
    clickToCopy = {
        category = "plugin",
        get = function() return addon.db.plugin.chat.interaction.clickToCopy end,
        set = function(v) addon.db.plugin.chat.interaction.clickToCopy = v end,
        default = true,
        ui = { type = "checkbox", label = "LABEL_COPY_CLICK_TO_COPY", tooltip = "LABEL_COPY_CLICK_TO_COPY_DESC", page = "chat", section = "SECTION_CHAT_INTERACTION" },
    },
    linkHover = {
        category = "plugin",
        get = function() return addon.db.plugin.chat.interaction.linkHover end,
        set = function(v) addon.db.plugin.chat.interaction.linkHover = v end,
        default = true,
        ui = { type = "checkbox", label = "LABEL_TWEAKS_LINK_HOVER", tooltip = "LABEL_TWEAKS_LINK_HOVER_DESC", page = "chat", section = "SECTION_CHAT_INTERACTION" },
    },
    sticky = {
        category = "plugin",
        get = function() return addon.db.plugin.chat.interaction.sticky end,
        set = function(v) addon.db.plugin.chat.interaction.sticky = v end,
        default = true,
        ui = { type = "checkbox", label = "LABEL_STREAM_STICKY_LABEL", tooltip = "LABEL_STREAM_STICKY_DESC_LABEL", page = "chat", section = "SECTION_CHAT_INTERACTION" },
    },
    tabCycle = {
        category = "plugin",
        get = function() return addon.db.plugin.chat.interaction.tabCycle end,
        set = function(v) addon.db.plugin.chat.interaction.tabCycle = v end,
        default = true,
        ui = { type = "checkbox", label = "LABEL_TWEAKS_TAB_CYCLE", tooltip = "LABEL_TWEAKS_TAB_CYCLE_DESC", page = "chat", section = "SECTION_CHAT_INTERACTION" },
    },

    -- --------------------------------------------
    -- 4. SHELF - APPEARANCE & BEHAVIOR
    -- --------------------------------------------
    shelfEnabled = {
        category = "plugin",
        get = function() return addon.db.plugin.shelf.enabled end,
        set = function(v) addon.db.plugin.shelf.enabled = v end,
        default = true,
    },
    shelfTheme = {
        category = "plugin",
        get = function() return addon.db.plugin.shelf.theme end,
        set = function(v) addon.db.plugin.shelf.theme = v end,
        default = function() return addon.CONSTANTS and addon.CONSTANTS.SHELF_DEFAULT_THEME or "Modern" end,
    },
    shelfAnchor = {
        category = "plugin",
        get = function() return addon.db.plugin.shelf.anchor end,
        set = function(v) addon.db.plugin.shelf.anchor = v end,
        default = function() return addon.CONSTANTS and addon.CONSTANTS.SHELF_DEFAULT_ANCHOR or "chat_top" end,
    },
    shelfDirection = {
        category = "plugin",
        get = function() return addon.db.plugin.shelf.direction end,
        set = function(v) addon.db.plugin.shelf.direction = v end,
        default = "horizontal",
    },
    shelfDynamicMode = {
        category = "plugin",
        get = function() return addon.db.plugin.shelf.dynamicMode end,
        set = function(v) addon.db.plugin.shelf.dynamicMode = v end,
        default = "mark",
    },
    shelfColorSet = {
        category = "plugin",
        get = function() return addon.Shelf and addon.Shelf.GetThemeProperty and addon.Shelf:GetThemeProperty("colorSet") end,
        set = function(v) if addon.Shelf and addon.Shelf.SetThemeProperty then addon.Shelf:SetThemeProperty("colorSet", v) end end,
        default = function()
            local theme = addon.db and addon.db.plugin.shelf.theme or addon.CONSTANTS.SHELF_DEFAULT_THEME
            local preset = addon.ThemeRegistry and addon.ThemeRegistry:GetPreset(theme)
            return preset and preset.properties and preset.properties.colorSet or addon.CONSTANTS.SHELF_DEFAULT_COLORSET
        end,
    },
}
