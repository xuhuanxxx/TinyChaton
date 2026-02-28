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

    addon.AddSectionHeader(cat, L["SECTION_GENERAL_APPEARANCE"] or "Appearance")

    local appearanceProxySettings = {}

    local function GetThemeVal(k)
        local db = GetShelfDB()
        if not db then return 0 end
        local t = db.theme or addon.CONSTANTS.SHELF_DEFAULT_THEME
        local themeTable = db.themes and db.themes[t]
        if themeTable and themeTable[k] ~= nil then return themeTable[k] end
        local preset = addon.ThemeRegistry and addon.ThemeRegistry:GetPreset(t)
        if preset and preset.properties and preset.properties[k] ~= nil then return preset.properties[k] end
        return 0
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

            for key, setting in pairs(appearanceProxySettings) do
                if setting and setting.SetValue then
                    setting:SetValue(GetThemeVal(key))
                end
            end
        end,
        nil)
    appearanceProxySettings["font"] = addon.AddRegistrySetting(cat, "themeFont")
    appearanceProxySettings["colorSet"] = addon.AddRegistrySetting(cat, "themeColorSet")
    appearanceProxySettings["fontSize"] = addon.AddRegistrySetting(cat, "themeFontSize")
    appearanceProxySettings["buttonSize"] = addon.AddRegistrySetting(cat, "themeButtonSize")
    appearanceProxySettings["spacing"] = addon.AddRegistrySetting(cat, "themeSpacing")
    appearanceProxySettings["scale"] = addon.AddRegistrySetting(cat, "themeScale")
    appearanceProxySettings["alpha"] = addon.AddRegistrySetting(cat, "themeAlpha")

    local function ResetAppearanceData()
        local db = GetShelfDB()
        if not db then return end

        db.theme = shelfDef.theme
        db.themes = addon.Utils.DeepCopy(shelfDef.themes)
        db.colorSet = shelfDef.colorSet
        db.anchor = shelfDef.anchor
        db.direction = shelfDef.direction
        db.savedPoint = shelfDef.savedPoint

        for key, setting in pairs(appearanceProxySettings) do
            if setting and setting.SetValue then
                setting:SetValue(GetThemeVal(key))
            end
        end

        if addon.ApplyAllSettings then addon:ApplyAllSettings() end
        if addon.RefreshShelfPreview then addon.RefreshShelfPreview() end
    end

    if not inline then
        addon.RegisterPageReset(cat, ResetAppearanceData)
    end

    return cat, ResetAppearanceData
end
