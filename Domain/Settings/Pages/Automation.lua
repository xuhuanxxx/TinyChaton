local addonName, addon = ...
local L = addon.L

local CategoryBuilders = addon.CategoryBuilders or {}
addon.CategoryBuilders = CategoryBuilders

local function GetAutomationDefaults()
    local profile = addon.DEFAULTS and addon.DEFAULTS.profile
    return (type(profile) == "table" and type(profile.automation) == "table") and profile.automation or {}
end

CategoryBuilders.automation = function(rootCat)
    local cat, _ = Settings.RegisterVerticalLayoutSubcategory(rootCat, L["PAGE_AUTOMATION"])
    Settings.RegisterAddOnCategory(cat)
    local P = "TinyChaton_Automation_"
    local autoDB = addon.db.profile.automation
    local autoDef = GetAutomationDefaults()
    local countdownDef = autoDef.countdown or { primarySeconds = 10, secondarySeconds = 5 }
    local function GetAutoDB()
        return addon.db and addon.db.profile and addon.db.profile.automation
    end

    -- 1. Auto Welcome
    addon.AddSectionHeader(cat, L["LABEL_AUTO_WELCOME"])

    local welcomeEnabledSetting = addon.AddRegistrySetting(cat, "automationWelcomeEnabled")
    local welcomeCooldownSetting = addon.AddRegistrySetting(cat, "automationWelcomeCooldownMinutes")

    local function GetTabConfig()
        local db = GetAutoDB()
        local fallback = GetAutomationDefaults().welcomeGuild or { enabled = false, sendMode = "channel" }
        if not db then return fallback end -- Fallback
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
        local db = GetAutoDB()
        if not db then return end
        local cfg = (db.currentSocialTab == "guild" and db.welcomeGuild) or
                    (db.currentSocialTab == "party" and db.welcomeParty) or db.welcomeRaid
        -- Initialize templates with defaults if empty/nil
        if cfg and type(cfg.templates) ~= "table" then
            local key = "welcome" .. (db.currentSocialTab:gsub("^%l", string.upper))
            local defaultTemplates = addon.DEFAULTS.profile.automation[key].templates
            cfg.templates = type(defaultTemplates) == "table" and addon.Utils.DeepCopy(defaultTemplates) or {}
        end
        local label = db.currentSocialTab == "guild" and L["LABEL_WELCOME_GUILD"] or
                      db.currentSocialTab == "party" and L["LABEL_WELCOME_PARTY"] or L["LABEL_WELCOME_RAID"]
        addon.UI.ShowEditor(label, cfg, "templates", L["LABEL_WELCOME_TEMPLATE_HINT"])
    end, nil)

    -- 2. Auto Join Channels
    addon.AddSectionHeader(cat, L["SECTION_AUTO_JOIN_CHANNELS"])

    addon.AddProxyMultiDropdown(cat, P .. "autoJoinDynamic",
        L["LABEL_AUTO_JOIN_PRESET_CHANNELS"] or L["LABEL_AUTO_JOIN_CHANNELS"],
        function() return addon:GetAutoJoinDynamicChannelsItems() end,
        function() return addon:GetAutoJoinDynamicChannelSelection() end,
        function(sel) addon:SetAutoJoinDynamicChannelSelection(sel) end,
        L["TOOLTIP_AUTO_JOIN_PRESET_CHANNELS"] or L["TOOLTIP_AUTO_JOIN_CHANNELS"])

    addon.AddNativeButton(cat, L["LABEL_AUTO_JOIN_CUSTOM_CHANNELS"] or L["LABEL_CUSTOM"], L["ACTION_EDIT"], function()
        local db = GetAutoDB()
        if not db then return end
        if type(db.customAutoJoinChannels) ~= "table" then
            db.customAutoJoinChannels = {}
        end

        local function SanitizeChannels(lines)
            local unique = {}
            local normalized = {}
            for _, raw in ipairs(lines) do
                if type(raw) == "string" then
                    local name = raw:match("^%s*(.-)%s*$")
                    if name and name ~= "" then
                        local key = string.lower(name)
                        if not unique[key] then
                            unique[key] = true
                            normalized[#normalized + 1] = name
                        end
                    end
                end
            end

            table.wipe(lines)
            for _, name in ipairs(normalized) do
                lines[#lines + 1] = name
            end
            return true
        end

        addon.UI.ShowEditor(
            L["LABEL_AUTO_JOIN_CUSTOM_CHANNELS"] or L["SECTION_AUTO_JOIN_CHANNELS"],
            db,
            "customAutoJoinChannels",
            L["TOOLTIP_AUTO_JOIN_CUSTOM_CHANNELS"] or L["TOOLTIP_AUTO_JOIN_CHANNELS"],
            SanitizeChannels
        )
    end, L["TOOLTIP_AUTO_JOIN_CUSTOM_CHANNELS"] or L["TOOLTIP_AUTO_JOIN_CHANNELS"])

    addon.AddSectionHeader(cat, L["SECTION_COUNTDOWN_TIMER"])

    local countdownPrimarySetting = addon.AddRegistrySetting(cat, "automationCountdownPrimarySeconds")
    local countdownSecondarySetting = addon.AddRegistrySetting(cat, "automationCountdownSecondarySeconds")


    addon.SettingsReset:RegisterPageSpec("automation", {
        category = cat,
        writeDefaults = {
            "automation",
        },
        refreshControls = {
            { type = "setting", variable = P .. "CurrentSocialTab", valueFromPath = "automation.currentSocialTab" },
            { type = "setting", variable = "TinyChaton_automationWelcomeEnabled" },
            { type = "setting", variable = "TinyChaton_automationWelcomeCooldownMinutes" },
            { type = "setting", variable = "TinyChaton_automationCountdownPrimarySeconds" },
            { type = "setting", variable = "TinyChaton_automationCountdownSecondarySeconds" },
            { type = "setting", variable = P .. "welcomeTab_enabled" },
            { type = "setting", variable = P .. "welcomeTab_sendMode" },
            { type = "multidropdown", variable = P .. "autoJoinDynamic", selectionFromPath = "automation.autoJoinDynamicChannels" },
        },
        postRefresh = function()
            autoDef = GetAutomationDefaults()
            countdownDef = autoDef.countdown or { primarySeconds = 10, secondarySeconds = 5 }
            RefreshTabSettings()
        end,
    })

    addon.RegisterPageReset(cat, "automation")

    return cat
end
