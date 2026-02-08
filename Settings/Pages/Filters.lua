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
    if not filterDB then addon.db.plugin.filter = { enabled = false, repeatFilter = true, block = { enabled = false, names = {}, keywords = {} }, highlight = { enabled = false, names = {}, keywords = {}, color = "FF00FF00" } } filterDB = addon.db.plugin.filter end
    if not filterDB.block then filterDB.block = { enabled = false, names = {}, keywords = {} } end
    if not filterDB.highlight then filterDB.highlight = { enabled = false, names = {}, keywords = {}, color = "FF00FF00" } end

    -- Blocklist Section
    addon.AddSectionHeader(cat, L["SECTION_BLOCKLIST"])
    addon.AddAddOnCheckbox(cat, P .. "block_enabled", "plugin.filter.block", "enabled", L["LABEL_ENABLED"], false, nil)
    addon.AddAddOnCheckbox(cat, P .. "block_inverse", "plugin.filter.block", "inverse", L["LABEL_BLOCK_INVERSE"], false, L["LABEL_BLOCK_INVERSE_DESC"])
    
    addon.AddNativeButton(cat, L["LABEL_BLOCK_NAMES"], L["ACTION_EDIT"], function()
        local db = addon.GetTableFromPath("plugin.filter.block")
        if db then addon.ShowEditor(L["LABEL_BLOCK_NAMES"], db, "names", L["LABEL_BLOCK_NAMES_HINT"]) end
    end, nil)
    
    addon.AddNativeButton(cat, L["LABEL_BLOCK_KEYWORDS"], L["ACTION_EDIT"], function()
        local db = addon.GetTableFromPath("plugin.filter.block")
        if db then addon.ShowEditor(L["LABEL_BLOCK_KEYWORDS"], db, "keywords", L["LABEL_BLOCK_KEYWORDS_HINT"]) end
    end, nil)

    addon.AddAddOnCheckbox(cat, P .. "repeatFilter", "plugin.filter", "repeatFilter", L["LABEL_REPEAT_FILTER"], true, L["LABEL_REPEAT_FILTER_DESC"])

    -- Highlight Section
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
