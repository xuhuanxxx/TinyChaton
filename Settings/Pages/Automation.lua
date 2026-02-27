local addonName, addon = ...
local L = addon.L
local def = addon.DEFAULTS and addon.DEFAULTS.plugin or {}

local CategoryBuilders = addon.CategoryBuilders or {}
addon.CategoryBuilders = CategoryBuilders

CategoryBuilders.automation = function(rootCat)
    local cat, _ = Settings.RegisterVerticalLayoutSubcategory(rootCat, L["PAGE_AUTOMATION"])
    Settings.RegisterAddOnCategory(cat)
    local P = "TinyChaton_Automation_"
    local autoDB = addon.db.plugin.automation
    local autoDef = def.automation

    -- 1. Auto Welcome
    addon.AddSectionHeader(cat, L["LABEL_AUTO_WELCOME"])
    local autoPath = "plugin.automation"

    -- Proxy getter/setter for automation settings
    local function GetAutoVal(key)
        local db = addon.GetTableFromPath(autoPath)
        return db and db[key]
    end

    local function SetAutoVal(key, value)
        local db = addon.GetTableFromPath(autoPath)
        if db then db[key] = value end
    end

    addon.AddProxyCheckbox(cat, P .. "welcomeEnabled", L["LABEL_ENABLED"], autoDef.autoWelcome,
        function() return GetAutoVal("autoWelcome") end,
        function(v) SetAutoVal("autoWelcome", v) end,
        nil)

    addon.AddProxySlider(cat, P .. "welcomeCooldownMinutes", L["LABEL_WELCOME_COOLDOWN"], autoDef.welcomeCooldownMinutes, 0, 60, 5,
        function() return GetAutoVal("welcomeCooldownMinutes") end,
        function(v) SetAutoVal("welcomeCooldownMinutes", v) end,
        nil)

    local function GetTabConfig()
        local db = addon.GetTableFromPath("plugin.automation")
        if not db then return autoDef.welcomeGuild end -- Fallback
        local tab = db.currentSocialTab or "guild"
        if tab == "guild" then return db.welcomeGuild
        elseif tab == "party" then return db.welcomeParty
        else return db.welcomeRaid end
    end

    local tabSettings = {}
    local function RefreshTabSettings()
        local cfg = GetTabConfig()
        if tabSettings.enabled and tabSettings.enabled.SetValue then tabSettings.enabled:SetValue(cfg.enabled) end
        if tabSettings.sendMode and tabSettings.sendMode.SetValue then tabSettings.sendMode:SetValue(cfg.sendMode or "channel") end
    end

    local tabSetting = Settings.RegisterAddOnSetting(cat, P .. "CurrentSocialTab", "currentSocialTab", autoDB, Settings.VarType.String, L["LABEL_SELECT_SOCIAL_TAB"], "guild")
    if tabSetting and tabSetting.SetValueChangedCallback then
        tabSetting:SetValueChangedCallback(function() RefreshTabSettings(); addon:ApplyAllSettings() end)
    end
    Settings.CreateDropdown(cat, tabSetting, function()
        local c = Settings.CreateControlTextContainer()
        c:Add("guild", L["LABEL_WELCOME_GUILD"]); c:Add("party", L["LABEL_WELCOME_PARTY"]); c:Add("raid", L["LABEL_WELCOME_RAID"])
        return c:GetData()
    end, nil)

    tabSettings.enabled = Settings.RegisterProxySetting(cat, P .. "welcomeTab_enabled", Settings.VarType.Boolean, L["LABEL_ENABLED"], false,
        function() return GetTabConfig().enabled end, function(v) GetTabConfig().enabled = v end)
    Settings.CreateCheckbox(cat, tabSettings.enabled)

    tabSettings.sendMode = Settings.RegisterProxySetting(cat, P .. "welcomeTab_sendMode", Settings.VarType.String, L["LABEL_WELCOME_SEND_MODE"], "channel",
        function() return GetTabConfig().sendMode or "channel" end, function(v) GetTabConfig().sendMode = v end)
    Settings.CreateDropdown(cat, tabSettings.sendMode, function()
        local c = Settings.CreateControlTextContainer(); c:Add("channel", L["LABEL_WELCOME_CHANNEL"]); c:Add("whisper", L["LABEL_WELCOME_WHISPER"])
        return c:GetData()
    end, nil)

    addon.AddNativeButton(cat, L["LABEL_WELCOME_TEMPLATES"], L["ACTION_EDIT"], function()
        local db = addon.GetTableFromPath("plugin.automation")
        if not db then return end
        local cfg = (db.currentSocialTab == "guild" and db.welcomeGuild) or
                    (db.currentSocialTab == "party" and db.welcomeParty) or db.welcomeRaid
        -- Initialize templates with defaults if empty/nil
        if cfg then
            local templates = cfg.templates
            if type(templates) == "function" then
                cfg.templates = templates()
            elseif type(templates) ~= "table" or #templates == 0 then
                -- Get defaults from DEFAULTS
                local defaultTemplates = addon.DEFAULTS.plugin.automation["welcome" .. (db.currentSocialTab:gsub("^%l", string.upper))].templates
                if type(defaultTemplates) == "function" then
                    cfg.templates = defaultTemplates()
                end
            end
        end
        local label = db.currentSocialTab == "guild" and L["LABEL_WELCOME_GUILD"] or
                      db.currentSocialTab == "party" and L["LABEL_WELCOME_PARTY"] or L["LABEL_WELCOME_RAID"]
        addon.UI.ShowEditor(label, cfg, "templates", L["LABEL_WELCOME_TEMPLATE_HINT"])
    end, nil)

    -- 2. Auto Join Channels
    addon.AddSectionHeader(cat, L["SECTION_AUTO_JOIN_CHANNELS"])

    addon.AddNativeButton(cat, L["LABEL_AUTO_JOIN_CUSTOM_PLACEHOLDER"], L["ACTION_EDIT"], function()
        local prefix = (L and L["LABEL_ADDON_NAME"]) or "TinyChaton"
        local msg = (L and L["MSG_AUTO_JOIN_CUSTOM_PLACEHOLDER"]) or "Custom auto-join channel editor is not available yet."
        print("|cff00ff00" .. prefix .. "|r: " .. msg)
    end, L["TOOLTIP_AUTO_JOIN_CUSTOM_PLACEHOLDER"])


    local function ResetAutomationData()
        autoDB.customAutoJoinChannels = addon.Utils.DeepCopy(autoDef.customAutoJoinChannels)
        autoDB.welcomeGuild = addon.Utils.DeepCopy(autoDef.welcomeGuild)
        autoDB.welcomeParty = addon.Utils.DeepCopy(autoDef.welcomeParty)
        autoDB.welcomeRaid = addon.Utils.DeepCopy(autoDef.welcomeRaid)

        if addon.ApplyAllSettings then addon:ApplyAllSettings() end
    end

    addon.RegisterPageReset(cat, ResetAutomationData)

    return cat
end
