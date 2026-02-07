local addonName, addon = ...
local L = addon.L
local def = addon.DEFAULTS and addon.DEFAULTS.plugin or {}

local CategoryBuilders = addon.CategoryBuilders or {}
addon.CategoryBuilders = CategoryBuilders

CategoryBuilders.general = function(rootCat)
    local cat, _ = Settings.RegisterVerticalLayoutSubcategory(rootCat, L["PAGE_GENERAL"])
    Settings.RegisterAddOnCategory(cat)
    local P = "TinyChaton_General_"
    local S = "TinyChaton_Shelf_Appearance_"
    
    local globalDef = addon.DEFAULTS and addon.DEFAULTS.enabled
    addon.AddAddOnCheckbox(cat, P .. "enabled", addon.db, "enabled", L["LABEL_ENABLED"] .. L["LABEL_GLOBAL_SUFFIX"], globalDef, L["LABEL_MASTER_SWITCH_DESC"], function()
        if addon.ApplyAllSettings then addon:ApplyAllSettings() end
    end)
    
    addon.AddSectionHeader(cat, L["SECTION_SHELF_MAIN"])
    
    local shelfPath = "plugin.shelf"
    local shelfDef = def.shelf
    
    addon.AddAddOnCheckbox(cat, S .. "enabled", shelfPath, "enabled", L["LABEL_ENABLED"], shelfDef.enabled, nil, function() if addon.ApplyShelfSettings then addon:ApplyShelfSettings() end end)
    
    addon.AddAddOnDropdown(cat, S .. "anchor", shelfPath, "anchor", L["LABEL_SHELF_POSITION"],
        function() 
            local c = Settings.CreateControlTextContainer()
            
            -- Dynamic generation from registry
            local anchors = addon.AnchorRegistry and addon.AnchorRegistry:GetAnchors()
            if anchors then
                for _, anchor in ipairs(anchors) do
                    -- Skip internal fallback frames if not meant for user selection
                    if anchor.name ~= "fallback_frame" then
                        local labelKey = "LABEL_SHELF_POSITION_" .. string.upper(anchor.name)
                        c:Add(anchor.name, L[labelKey])
                    end
                end
            end
            
            -- Dynamic Custom Label
            local db = addon.GetTableFromPath("plugin.shelf")
            local customLabel = L["LABEL_SHELF_POSITION_CUSTOM_EMPTY"]
            if db and db.savedPoint then
                customLabel = L["LABEL_SHELF_POSITION_CUSTOM_SAVED"]
            end
            c:Add("custom", customLabel)
            
            return c:GetData() 
        end, shelfDef.anchor, nil, nil, function() if addon.ApplyShelfSettings then addon:ApplyShelfSettings() end end)
    
    addon.AddAddOnDropdown(cat, S .. "direction", shelfPath, "direction", L["LABEL_SHELF_DIRECTION"],
        function() 
            local c = Settings.CreateControlTextContainer()
            c:Add("horizontal", L["LABEL_SHELF_DIRECTION_HORIZONTAL"])
            c:Add("vertical", L["LABEL_SHELF_DIRECTION_VERTICAL"])
            return c:GetData() 
        end, shelfDef.direction, nil, nil, function() if addon.ApplyShelfSettings then addon:ApplyShelfSettings() end end)
    
    addon.AddAddOnDropdown(cat, S .. "dynamicMode", shelfPath, "dynamicMode", L["LABEL_SHELF_DYNAMIC_MODE"],
        function()
            local c = Settings.CreateControlTextContainer()
            c:Add("hide", L["LABEL_SHELF_DYNAMIC_HIDE"])
            c:Add("mark", L["LABEL_SHELF_DYNAMIC_MARK"])
            return c:GetData()
        end, shelfDef.dynamicMode, nil, nil, function() if addon.ApplyShelfSettings then addon:ApplyShelfSettings() end end)

    addon.AddSectionHeader(cat, L["SECTION_SHELF_BUTTON"])
    
    local shelfProxySettings = {}

    local function GetThemeVal(k)
        local db = addon.GetTableFromPath("plugin.shelf")
        if not db then return 0 end
        local t = db.theme or addon.CONSTANTS.SHELF_DEFAULT_THEME
        local themeTable = db.themes and db.themes[t]
        if themeTable and themeTable[k] ~= nil then return themeTable[k] end
        local preset = addon.ThemeRegistry and addon.ThemeRegistry:GetPreset(t)
        if preset and preset.properties and preset.properties[k] ~= nil then return preset.properties[k] end
        return 0
    end

    local function SetThemeVal(k, v)
        local db = addon.GetTableFromPath("plugin.shelf")
        if not db then return end
        local t = db.theme or addon.CONSTANTS.SHELF_DEFAULT_THEME
        if not db.themes then db.themes = {} end
        if not db.themes[t] then db.themes[t] = {} end
        db.themes[t][k] = v
        if addon.ApplyShelfSettings then addon:ApplyShelfSettings() end
        if addon.RefreshShelfPreview then addon.RefreshShelfPreview() end
    end
    
    addon.AddAddOnDropdown(cat, S .. "theme", shelfPath, "theme", L["LABEL_SHELF_THEME"],
        function() 
            local c = Settings.CreateControlTextContainer()
            local themes = addon.ThemeRegistry:GetComponentThemes("shelf")
            for _, themeKey in ipairs(themes) do
                local preset = addon.ThemeRegistry:GetPreset(themeKey)
                local labelKey = "LABEL_SHELF_THEME_" .. string.upper(themeKey)
                local label = L[labelKey]
                c:Add(themeKey, label)
            end
            return c:GetData() 
        end, shelfDef.theme, nil, 
        function()
            if SettingsPanel and SettingsPanel:IsShown() then
                if addon.ApplyShelfSettings then addon:ApplyShelfSettings() end
                for key, setting in pairs(shelfProxySettings) do
                    local correctVal = GetThemeVal(key)
                    if setting and setting.SetValue then setting:SetValue(correctVal) end
                end
            end
        end)
    
    shelfProxySettings["font"] = addon.AddNativeDropdown(cat, S .. "font", L["LABEL_FONT"], addon.CONSTANTS.SHELF_DEFAULT_FONT,
        function() 
            local c = Settings.CreateControlTextContainer()
            c:Add("STANDARD", L["FONT_STANDARD"])
            c:Add("CHAT", L["FONT_CHAT"])
            c:Add("DAMAGE", L["FONT_DAMAGE"])
            
            -- If current value is not one of the presets, show it as Custom
            local val = GetThemeVal("font")
            if val and val ~= "STANDARD" and val ~= "CHAT" and val ~= "DAMAGE" and val ~= "" then
                local name = L["LABEL_CUSTOM"] .. " (" .. (val:match("([^\\]+)$") or val) .. ")"
                c:Add(val, name) 
            end
            
            return c:GetData() 
        end,
        function() 
            -- Return the raw value so it matches the Custom option if applicable
            return GetThemeVal("font") 
        end,
        function(v) SetThemeVal("font", v) end,
        nil)

    shelfProxySettings["colorSet"] = addon.AddNativeDropdown(cat, S .. "colorSet", L["LABEL_SHELF_COLORSET"], addon.CONSTANTS.SHELF_DEFAULT_COLORSET,
        function() return addon:GetColorSetOptions() end,
        function() return GetThemeVal("colorSet") end, function(v) SetThemeVal("colorSet", v) end, nil)
    local modernPreset = addon.ThemeRegistry and addon.ThemeRegistry:GetPreset(addon.CONSTANTS.SHELF_DEFAULT_THEME)
    local modernDefaults = modernPreset and modernPreset.properties or {}
    
    shelfProxySettings["fontSize"] = addon.AddNativeSlider(cat, S .. "fontSize", L["LABEL_FONT_SIZE"], modernDefaults.fontSize or addon.CONSTANTS.SHELF_DEFAULT_FONT_SIZE, 8, 24, 1, 
        function() return GetThemeVal("fontSize") end, function(v) SetThemeVal("fontSize", v) end, nil)
    shelfProxySettings["buttonSize"] = addon.AddNativeSlider(cat, S .. "buttonSize", L["LABEL_SHELF_BUTTON_SIZE"], modernDefaults.buttonSize or addon.CONSTANTS.SHELF_DEFAULT_BUTTON_SIZE, 16, 40, 1, 
        function() return GetThemeVal("buttonSize") end, function(v) SetThemeVal("buttonSize", v) end, nil)
    shelfProxySettings["spacing"] = addon.AddNativeSlider(cat, S .. "spacing", L["LABEL_SHELF_SPACING"], modernDefaults.spacing or addon.CONSTANTS.SHELF_DEFAULT_SPACING, 0, 10, 1, 
        function() return GetThemeVal("spacing") end, function(v) SetThemeVal("spacing", v) end, nil)
    shelfProxySettings["scale"] = addon.AddNativeSlider(cat, S .. "scale", L["LABEL_SHELF_SCALE"], modernDefaults.scale or addon.CONSTANTS.SHELF_DEFAULT_SCALE, 0.5, 2.0, 0.1, 
        function() return GetThemeVal("scale") end, function(v) SetThemeVal("scale", v) end, nil)
    shelfProxySettings["alpha"] = addon.AddNativeSlider(cat, S .. "alpha", L["LABEL_SHELF_ALPHA"], modernDefaults.alpha or addon.CONSTANTS.SHELF_DEFAULT_ALPHA, 0.2, 1.0, 0.1, 
        function() return GetThemeVal("alpha") end, function(v) SetThemeVal("alpha", v) end, nil)

    return cat
end
