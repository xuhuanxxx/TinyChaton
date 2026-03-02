local addonName, addon = ...
local L = addon.L
local def = addon.DEFAULTS and addon.DEFAULTS.profile or {}

local CategoryBuilders = addon.CategoryBuilders or {}
addon.CategoryBuilders = CategoryBuilders

CategoryBuilders.appearance = function(rootCat, opts)
    opts = opts or {}
    local inline = opts.inline == true
    local inGeneral = opts.inGeneral == true

    local cat = rootCat
    if not inline then
        cat, _ = Settings.RegisterVerticalLayoutSubcategory(rootCat, L["PAGE_APPEARANCE"])
        Settings.RegisterAddOnCategory(cat)
    end

    local P = inline and "TinyChaton_General_Appearance_" or "TinyChaton_Appearance_"

    if not inGeneral then
        addon.AddSectionHeader(cat, L["SECTION_GENERAL_TOOLBAR"] or "Toolbar")
    end

    local function GetShelfDB()
        return addon.db and addon.db.profile and addon.db.profile.shelf
    end
    local shelfDef = def.shelf or {
        theme = addon.CONSTANTS.SHELF_DEFAULT_THEME,
        themes = {},
        colorSet = addon.CONSTANTS.SHELF_DEFAULT_COLORSET,
        anchor = addon.CONSTANTS.SHELF_DEFAULT_ANCHOR,
        direction = "horizontal",
        savedPoint = false,
    }

    addon.AddProxyDropdown(cat, P .. "anchor", L["LABEL_SHELF_POSITION"], shelfDef.anchor,
        function()
            local c = Settings.CreateControlTextContainer()

            local anchors = addon.AnchorRegistry and addon.AnchorRegistry:GetAnchors()
            if anchors then
                for _, anchor in ipairs(anchors) do
                    if anchor.name ~= "fallback_frame" then
                        local labelKey = "LABEL_SHELF_POSITION_" .. string.upper(anchor.name)
                        c:Add(anchor.name, L[labelKey])
                    end
                end
            end

            local db = GetShelfDB()
            local customLabel = L["LABEL_SHELF_POSITION_CUSTOM_EMPTY"]
            if db and db.savedPoint then
                customLabel = L["LABEL_SHELF_POSITION_CUSTOM_SAVED"]
            end
            c:Add("custom", customLabel)

            return c:GetData()
        end,
        function()
            local db = GetShelfDB()
            return db and db.anchor or shelfDef.anchor
        end,
        function(v)
            local db = GetShelfDB()
            if db then db.anchor = v end
            if addon.ApplyShelfSettings then addon:ApplyShelfSettings() end
        end,
        nil)

    addon.AddProxyDropdown(cat, P .. "direction", L["LABEL_SHELF_DIRECTION"], shelfDef.direction,
        function()
            local c = Settings.CreateControlTextContainer()
            c:Add("horizontal", L["LABEL_SHELF_DIRECTION_HORIZONTAL"])
            c:Add("vertical", L["LABEL_SHELF_DIRECTION_VERTICAL"])
            return c:GetData()
        end,
        function()
            local db = GetShelfDB()
            return db and db.direction or shelfDef.direction
        end,
        function(v)
            local db = GetShelfDB()
            if db then db.direction = v end
            if addon.ApplyShelfSettings then addon:ApplyShelfSettings() end
        end,
        nil)
    if inGeneral then
        addon.AddRegistrySetting(cat, "toolbarDynamicMode")
    end

    addon.AddSectionHeader(cat, L["SECTION_GENERAL_APPEARANCE"] or "Appearance")

    local appearanceThemeVariables = {
        "TinyChaton_themeFont",
        "TinyChaton_themeColorSet",
        "TinyChaton_themeFontSize",
        "TinyChaton_themeButtonSize",
        "TinyChaton_themeSpacing",
        "TinyChaton_themeScale",
        "TinyChaton_themeAlpha",
    }
    local function RefreshThemeSettingsUi()
        for _, variable in ipairs(appearanceThemeVariables) do
            local setting = Settings.GetSetting(variable)
            if setting and setting.GetValue then
                addon.RefreshSettingValue(variable, setting:GetValue(), { silent = true })
            end
        end
    end
    addon.AddProxyDropdown(cat, P .. "theme", L["LABEL_SHELF_THEME"], shelfDef.theme,
        function()
            local c = Settings.CreateControlTextContainer()
            local themes = addon.ThemeRegistry:GetComponentThemes("shelf")
            for _, themeKey in ipairs(themes) do
                local labelKey = "LABEL_SHELF_THEME_" .. string.upper(themeKey)
                c:Add(themeKey, L[labelKey])
            end
            return c:GetData()
        end,
        function()
            local db = GetShelfDB()
            return db and db.theme or shelfDef.theme
        end,
        function(v)
            local db = GetShelfDB()
            if db then db.theme = v end
            if addon.ApplyShelfSettings then addon:ApplyShelfSettings() end
            RefreshThemeSettingsUi()
        end,
        nil)
    addon.AddRegistrySetting(cat, "themeFont")
    addon.AddRegistrySetting(cat, "themeColorSet")
    addon.AddRegistrySetting(cat, "themeFontSize")
    addon.AddRegistrySetting(cat, "themeButtonSize")
    addon.AddRegistrySetting(cat, "themeSpacing")
    addon.AddRegistrySetting(cat, "themeScale")
    addon.AddRegistrySetting(cat, "themeAlpha")

    local resetSpec = {
        writeDefaults = {
            "shelf.theme",
            "shelf.themes",
            "shelf.colorSet",
            "shelf.anchor",
            "shelf.direction",
            "shelf.savedPoint",
        },
        refreshControls = {
            { type = "setting", variable = P .. "anchor", valueFromPath = "shelf.anchor" },
            { type = "setting", variable = P .. "direction", valueFromPath = "shelf.direction" },
            { type = "setting", variable = P .. "theme", valueFromPath = "shelf.theme" },
            { type = "setting", variable = "TinyChaton_themeFont" },
            { type = "setting", variable = "TinyChaton_themeColorSet" },
            { type = "setting", variable = "TinyChaton_themeFontSize" },
            { type = "setting", variable = "TinyChaton_themeButtonSize" },
            { type = "setting", variable = "TinyChaton_themeSpacing" },
            { type = "setting", variable = "TinyChaton_themeScale" },
            { type = "setting", variable = "TinyChaton_themeAlpha" },
        },
        postRefresh = function()
            RefreshThemeSettingsUi()
            if addon.RefreshShelfPreview then addon.RefreshShelfPreview() end
        end,
    }
    if inGeneral then
        resetSpec.writeDefaults[#resetSpec.writeDefaults + 1] = "buttons.dynamicMode"
        resetSpec.refreshControls[#resetSpec.refreshControls + 1] = { type = "setting", variable = "TinyChaton_toolbarDynamicMode", valueFromPath = "buttons.dynamicMode" }
    end

    if not inline then
        addon.SettingsReset:RegisterPageSpec("appearance", {
            category = cat,
            writeDefaults = resetSpec.writeDefaults,
            refreshControls = resetSpec.refreshControls,
            postRefresh = resetSpec.postRefresh,
        })
        addon.RegisterPageReset(cat, "appearance")
    end

    return cat, resetSpec
end
