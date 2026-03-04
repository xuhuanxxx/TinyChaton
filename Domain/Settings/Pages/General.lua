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
    addon.AddProxyCheckbox(cat, P .. "enabled", L["LABEL_ENABLED"], globalDef,
        function() return addon.db and addon.db.enabled end,
        function(v)
            if addon.db then addon.db.enabled = v end
            addon:CommitSettings("settings_ui_change", "all")
        end,
        L["LABEL_MASTER_SWITCH_DESC"])

    addon.AddSectionHeader(cat, L["SECTION_GENERAL_TOOLBAR"] or "Toolbar")

    local function GetButtonsDB()
        return addon.db and addon.db.profile and addon.db.profile.buttons
    end
    local buttonsDef = def.buttons or { enabled = true }

    addon.AddProxyCheckbox(cat, P .. "buttonsEnabled", L["LABEL_ENABLED"], buttonsDef.enabled,
        function()
            local db = GetButtonsDB()
            return db and db.enabled
        end,
        function(v)
            local db = GetButtonsDB()
            if db then db.enabled = v end
            addon:CommitSettings("shelf_settings_change", "shelf")
        end,
        nil)
    addon.AddRegistrySetting(cat, "shelfDisplayNameStyle")

    local resetAppearanceSpec = nil
    if addon.CategoryBuilders and addon.CategoryBuilders.appearance then
        _, resetAppearanceSpec = addon.CategoryBuilders.appearance(cat, { inline = true, inGeneral = true })
    end

    local writeDefaults = {
        "buttons.enabled",
        "buttons.dynamicMode",
        "shelf.visual.display.nameStyle",
    }
    local refreshControls = {
        { type = "setting", variable = P .. "enabled" },
        { type = "setting", variable = P .. "buttonsEnabled", valueFromPath = "buttons.enabled" },
        { type = "setting", variable = "TinyChaton_shelfDisplayNameStyle", valueFromPath = "shelf.visual.display.nameStyle" },
    }
    if type(resetAppearanceSpec) == "table" then
        for _, path in ipairs(resetAppearanceSpec.writeDefaults or {}) do
            writeDefaults[#writeDefaults + 1] = path
        end
        for _, control in ipairs(resetAppearanceSpec.refreshControls or {}) do
            refreshControls[#refreshControls + 1] = control
        end
    end

    addon.SettingsReset:RegisterPageSpec("general", {
        category = cat,
        preReset = function()
            if addon.db then
                addon.db.enabled = addon.DEFAULTS and addon.DEFAULTS.enabled
            end
        end,
        writeDefaults = writeDefaults,
        refreshControls = refreshControls,
        postRefresh = function()
            if addon.RefreshShelfPreview then addon.RefreshShelfPreview() end
        end,
    })
    addon.RegisterPageReset(cat, "general")

    return cat
end
