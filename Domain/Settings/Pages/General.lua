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
    local shelfNameStyleSetting = addon.AddRegistrySetting(cat, "shelfDisplayNameStyle")

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
            db.dynamicMode = buttonsDef.dynamicMode or "mark"
        end

        local shelfDB = addon.db and addon.db.profile and addon.db.profile.shelf
        if shelfDB and shelfDB.visual and shelfDB.visual.display then
            shelfDB.visual.display.nameStyle = (def.shelf and def.shelf.visual and def.shelf.visual.display and def.shelf.visual.display.nameStyle) or "SHORT_ONE"
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
        if shelfNameStyleSetting and shelfNameStyleSetting.SetValue then
            local sdb = addon.db and addon.db.profile and addon.db.profile.shelf
            local style = sdb and sdb.visual and sdb.visual.display and sdb.visual.display.nameStyle
            shelfNameStyleSetting:SetValue(style)
        end

        if addon.ApplyAllSettings then addon:ApplyAllSettings() end
    end

    addon.RegisterPageReset(cat, ResetGeneralData)

    return cat
end
