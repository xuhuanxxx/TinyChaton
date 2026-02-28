local addonName, addon = ...
local L = addon.L
local def = addon.DEFAULTS and addon.DEFAULTS.profile or {}

local CategoryBuilders = addon.CategoryBuilders or {}
addon.CategoryBuilders = CategoryBuilders

CategoryBuilders.general = function(rootCat)
    local cat, _ = Settings.RegisterVerticalLayoutSubcategory(rootCat, L["PAGE_GENERAL"])
    Settings.RegisterAddOnCategory(cat)
    local P = "TinyChaton_General_"

    addon.AddSectionHeader(cat, L["SECTION_GENERAL_GLOBAL"] or "Global")

    local globalDef = addon.DEFAULTS and addon.DEFAULTS.enabled
    local globalEnabledSetting = addon.AddProxyCheckbox(cat, P .. "enabled", L["LABEL_ENABLED"], globalDef,
        function() return addon.db and addon.db.enabled end,
        function(v)
            if addon.db then addon.db.enabled = v end
            if addon.ApplyAllSettings then addon:ApplyAllSettings() end
        end,
        L["LABEL_MASTER_SWITCH_DESC"])

    addon.AddSectionHeader(cat, L["SECTION_GENERAL_TOOLBAR"] or "Toolbar")

    local function GetButtonsDB()
        return addon.db and addon.db.profile and addon.db.profile.buttons
    end
    local buttonsDef = def.buttons or { enabled = true }

    local buttonsEnabledSetting = addon.AddProxyCheckbox(cat, P .. "buttonsEnabled", L["LABEL_ENABLED"], buttonsDef.enabled,
        function()
            local db = GetButtonsDB()
            return db and db.enabled
        end,
        function(v)
            local db = GetButtonsDB()
            if db then db.enabled = v end
            if addon.ApplyShelfSettings then addon:ApplyShelfSettings() end
        end,
        nil)

    local resetAppearanceData = nil
    if addon.CategoryBuilders and addon.CategoryBuilders.appearance then
        _, resetAppearanceData = addon.CategoryBuilders.appearance(cat, { inline = true, inGeneral = true })
    end

    local function ResetGeneralData()
        if addon.db then
            addon.db.enabled = addon.DEFAULTS.enabled
        end

        local db = GetButtonsDB()
        if db and buttonsDef then
            db.enabled = buttonsDef.enabled
        end

        if resetAppearanceData then
            resetAppearanceData()
        end

        if globalEnabledSetting and globalEnabledSetting.SetValue then
            globalEnabledSetting:SetValue(addon.db and addon.db.enabled)
        end
        if buttonsEnabledSetting and buttonsEnabledSetting.SetValue then
            local bdb = GetButtonsDB()
            buttonsEnabledSetting:SetValue(bdb and bdb.enabled)
        end

        if addon.ApplyAllSettings then addon:ApplyAllSettings() end
    end

    addon.RegisterPageReset(cat, ResetGeneralData)

    return cat
end
