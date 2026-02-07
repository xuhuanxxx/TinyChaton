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
    addon.AddAddOnCheckbox(cat, P .. "welcomeEnabled", autoPath, "autoWelcome", L["LABEL_ENABLED"], autoDef.autoWelcome, nil)
    addon.AddAddOnSlider(cat, P .. "welcomeCooldownMinutes", autoPath, "welcomeCooldownMinutes", L["LABEL_WELCOME_COOLDOWN"], autoDef.welcomeCooldownMinutes, 0, 60, 5, nil)

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
        local label = db.currentSocialTab == "guild" and L["LABEL_WELCOME_GUILD"] or 
                      db.currentSocialTab == "party" and L["LABEL_WELCOME_PARTY"] or L["LABEL_WELCOME_RAID"]
        addon.ShowEditor(label, cfg, "templates", L["LABEL_WELCOME_TEMPLATE_HINT"])
    end, nil)

    -- 2. Auto Join Channels
    addon.AddSectionHeader(cat, L["SECTION_AUTO_JOIN_CHANNELS"])
    
    addon.AddProxyMultiDropdown(cat, P .. "autoJoinChannels", 
        L["LABEL_AUTO_JOIN_CHANNELS"] or "自动加入",
        function() return addon:GetAutoJoinChannelsItems() end,
        function() return addon:GetAutoJoinChannelSelection() end,
        function(sel) addon:SetAutoJoinChannelSelection(sel) end,
        L["TOOLTIP_AUTO_JOIN_CHANNELS"] or "选择登录后自动加入的频道")


    local function ResetAutomationData()
        autoDB.autoJoinChannels = addon.Utils.DeepCopy(autoDef.autoJoinChannels)
        autoDB.welcomeGuild = addon.Utils.DeepCopy(autoDef.welcomeGuild)
        autoDB.welcomeParty = addon.Utils.DeepCopy(autoDef.welcomeParty)
        autoDB.welcomeRaid = addon.Utils.DeepCopy(autoDef.welcomeRaid)

        if addon.ApplyAllSettings then addon:ApplyAllSettings() end

        local setting = Settings.GetSetting(P .. "autoJoinChannels")
        if setting and setting.SetValue and setting.GetValue then
            setting:SetValue(setting:GetValue())
        end
    end
    
    addon.RegisterPageReset(cat, ResetAutomationData)

    return cat
end
