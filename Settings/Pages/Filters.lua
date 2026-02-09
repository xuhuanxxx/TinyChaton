local addonName, addon = ...
local L = addon.L
local def = addon.DEFAULTS and addon.DEFAULTS.plugin or {}

local CategoryBuilders = addon.CategoryBuilders or {}
addon.CategoryBuilders = CategoryBuilders

CategoryBuilders.filters = function(rootCat)
    local cat, _ = Settings.RegisterVerticalLayoutSubcategory(rootCat, L["PAGE_FILTERS"])
    Settings.RegisterAddOnCategory(cat)
    local P = "TinyChaton_Filter_"
    local filterDB = addon.db.plugin.filter

    -- Ensure DB structure exists
    if not filterDB then
        addon.db.plugin.filter = {
            mode = "disabled",
            repeatFilter = true,
            blacklist = { names = {}, keywords = {} },
            whitelist = { names = {}, keywords = {} },
            highlight = { enabled = true, names = {}, keywords = {}, color = "FF00FF00" }
        }
        filterDB = addon.db.plugin.filter
    end
    if not filterDB.blacklist then filterDB.blacklist = { names = {}, keywords = {} } end
    if not filterDB.whitelist then filterDB.whitelist = { names = {}, keywords = {} } end
    if not filterDB.highlight then filterDB.highlight = { enabled = true, names = {}, keywords = {}, color = "FF00FF00" } end

    -- ========================================
    -- Section 1: Blacklist/Whitelist (Dynamic)
    -- ========================================
    addon.AddSectionHeader(cat, L["SECTION_BLOCKLIST"] .. " / " .. L["SECTION_WHITELIST"])

    -- Proxy Settings Storage
    local filterProxySettings = {}

    -- Current Filter Mode State (blacklist/whitelist)
    local currentMode = filterDB.mode == "whitelist" and "whitelist" or "blacklist"

    -- Getter/Setter for current mode's data
    local function GetModeVal(key)
        local db = addon.GetTableFromPath("plugin.filter")
        if not db then return nil end
        if key == "mode" then return db.mode end
        if key == "repeatFilter" then return db.repeatFilter end
        if not db[currentMode] then return {} end
        return db[currentMode][key] or {}
    end

    local function SetModeVal(key, value)
        local db = addon.GetTableFromPath("plugin.filter")
        if not db then return end
        if key == "mode" then
            db.mode = value
            -- Update currentMode when mode changes
            if value == "whitelist" or value == "blacklist" then
                currentMode = value
            end
        elseif key == "repeatFilter" then
            db.repeatFilter = value
        else
            if not db[currentMode] then db[currentMode] = {} end
            db[currentMode][key] = value
        end
        addon:ApplyAllSettings()
    end

    -- Filter Mode Dropdown (blacklist/whitelist/disabled)
    local function GetModeOptions()
        local container = Settings.CreateControlTextContainer()
        container:Add("disabled", L["LABEL_MODE_DISABLED"])
        container:Add("blacklist", L["LABEL_MODE_BLACKLIST"])
        container:Add("whitelist", L["LABEL_MODE_WHITELIST"])
        return container:GetData()
    end

    addon.AddNativeDropdown(cat, P .. "mode", L["LABEL_FILTER_MODE"], filterDB.mode or "disabled",
        GetModeOptions,
        function() return GetModeVal("mode") end,
        function(value)
            SetModeVal("mode", value)
            -- Refresh proxy settings when mode changes
            if SettingsPanel and SettingsPanel:IsShown() then
                for key, setting in pairs(filterProxySettings) do
                    if setting and setting.SetValue then
                        local correctVal = GetModeVal(key)
                        setting:SetValue(correctVal)
                    end
                end
            end
        end,
        nil)

    -- Repeat Filter Checkbox (Dynamic)
    filterProxySettings["repeatFilter"] = addon.AddNativeCheckbox(cat, P .. "repeatFilter",
        L["LABEL_REPEAT_FILTER"], true,
        function() return GetModeVal("repeatFilter") end,
        function(value) SetModeVal("repeatFilter", value) end,
        L["LABEL_REPEAT_FILTER_DESC"])

    -- Names Button (Dynamic)
    filterProxySettings["names"] = addon.AddNativeButton(cat, L["LABEL_BLOCK_NAMES"], L["ACTION_EDIT"], function()
        local db = addon.GetTableFromPath("plugin.filter")
        if not db or not db[currentMode] then return end
        addon.ShowEditor(L["LABEL_BLOCK_NAMES"], db[currentMode], "names", L["LABEL_BLOCK_NAMES_HINT"])
    end, nil)

    -- Keywords Button (Dynamic)
    filterProxySettings["keywords"] = addon.AddNativeButton(cat, L["LABEL_BLOCK_KEYWORDS"], L["ACTION_EDIT"], function()
        local db = addon.GetTableFromPath("plugin.filter")
        if not db or not db[currentMode] then return end
        addon.ShowEditor(L["LABEL_BLOCK_KEYWORDS"], db[currentMode], "keywords", L["LABEL_BLOCK_KEYWORDS_HINT"])
    end, nil)

    -- ========================================
    -- Section 2: Highlight (Static)
    -- ========================================
    addon.AddSectionHeader(cat, L["SECTION_HIGHLIGHTS"])

    addon.AddAddOnCheckbox(cat, P .. "highlight_enabled", "plugin.filter.highlight", "enabled", L["LABEL_ENABLED"], false, nil)

    addon.AddNativeButton(cat, L["LABEL_HIGHLIGHT_NAMES"], L["ACTION_EDIT"], function()
        local db = addon.GetTableFromPath("plugin.filter.highlight")
        if db then addon.ShowEditor(L["LABEL_HIGHLIGHT_NAMES"], db, "names", L["LABEL_HIGHLIGHT_NAMES_HINT"]) end
    end, nil)

    addon.AddNativeButton(cat, L["LABEL_HIGHLIGHT_KEYWORDS"], L["ACTION_EDIT"], function()
        local db = addon.GetTableFromPath("plugin.filter.highlight")
        if db then addon.ShowEditor(L["LABEL_HIGHLIGHT_KEYWORDS"], db, "keywords", L["LABEL_HIGHLIGHT_KEYWORDS_HINT"]) end
    end, nil)

    addon.AddNativeButton(cat, L["LABEL_HIGHLIGHT_COLOR"], L["ACTION_COLOR"], function()
        local db = addon.GetTableFromPath("plugin.filter.highlight")
        if not db then return end
        local r,g,b,a = addon.Utils.ParseColorHex(db.color or "FF00FF00")
        ColorPickerFrame:SetupColorPickerAndShow({ r=r, g=g, b=b, opacity=a, hasOpacity=true,
            swatchFunc = function()
                local cr,cg,cb,ca = ColorPickerFrame:GetColorRGB(), ColorPickerFrame:GetColorAlpha()
                db.color = addon.Utils.FormatColorHex(cr,cg,cb,ca)
                addon:ApplyAllSettings()
            end
        })
    end, nil)

    return cat
end
