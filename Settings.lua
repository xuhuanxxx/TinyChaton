local addonName, addon = ...
local L = addon.L

-- Initialize CategoryBuilders table that other modules will populate
addon.CategoryBuilders = addon.CategoryBuilders or {}

-------------------------------------------------------
-- Category Order Configuration
-------------------------------------------------------
local CATEGORY_ORDER = {
    "general",
    "shelf",
    "chat",
    "automation",
    "filters",
    "profile",
}

-------------------------------------------------------
-- Main Register
-------------------------------------------------------
-- Settings structure version (increment when changing settings structure)
local SETTINGS_VERSION = 1

function addon:RegisterSettings()
    -- Prevent duplicate registration (version-aware)
    if addon._settingsVersion and addon._settingsVersion >= SETTINGS_VERSION then
        return
    end
    addon._settingsVersion = SETTINGS_VERSION

    -- Use Standard Vertical Layout for Root Category
    local rootCat, layout = Settings.RegisterVerticalLayoutCategory(L["LABEL_ADDON_NAME"])

    -- Populate Root Page
    addon.AddText(rootCat, L["LABEL_ADDON_DESC"])
    addon.AddText(rootCat, L["LABEL_VERSION"] .. ": " .. (C_AddOns.GetAddOnMetadata(addonName, "Version") or "Dev"))
    addon.AddText(rootCat, L["LABEL_ADDON_SOURCE"])

    Settings.RegisterAddOnCategory(rootCat)
    addon.settingsCategory = rootCat

    -- Register categories in order
    for _, key in ipairs(CATEGORY_ORDER) do
        local builder = addon.CategoryBuilders[key]
        if builder then
            local ok, err = pcall(builder, rootCat)
            if not ok then
                print("|cFFFF0000" .. L["LABEL_ADDON_NAME"] .. " " .. L["MSG_CATEGORY_ERROR"] .. " (" .. key .. "):|r", err)
            end
        end
    end

    addon.OpenSettings = function() Settings.OpenToCategory(addon.settingsCategory:GetID()) end
end
