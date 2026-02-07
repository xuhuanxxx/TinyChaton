local addonName, addon = ...
local L = addon.L

local CategoryBuilders = addon.CategoryBuilders or {}
addon.CategoryBuilders = CategoryBuilders

CategoryBuilders.profile = function(rootCat)
    local cat, _ = Settings.RegisterVerticalLayoutSubcategory(rootCat, L["PAGE_PROFILE"])
    Settings.RegisterAddOnCategory(cat)
    
    addon.AddText(cat, L["LABEL_PROFILE_DESC"])
    
    addon.AddSectionHeader(cat, L["SECTION_RESET"])
    
    local function ResetAllSettings()
        -- 1. Force Synchronize Config (Revert db to defaults)
        addon:SynchronizeConfig(true)
        
        -- 2. Apply and Refresh All
        if addon.ApplyAllSettings then addon:ApplyAllSettings() end
        
        -- 3. Update Custom UI Elements
        if addon.RefreshShelfList then addon.RefreshShelfList() end
        if addon.RefreshShelfPreview then addon.RefreshShelfPreview() end
        
        print("|cFF00FF00" .. L["LABEL_ADDON_NAME"] .. "|r " .. L["MSG_RESET_COMPLETE"])
    end
    
    addon.AddNativeButton(cat, L["ACTION_RESET_ALL"], L["ACTION_RESET"], function()
        -- Show confirmation
        StaticPopupDialogs["TINYCHATON_RESET_ALL_CONFIRM"] = {
            text = L["MSG_RESET_ALL_CONFIRM"],
            button1 = YES,
            button2 = NO,
            OnAccept = ResetAllSettings,
            hideOnEscape = true,
        }
        StaticPopup_Show("TINYCHATON_RESET_ALL_CONFIRM")
    end, L["ACTION_RESET_ALL_DESC"])

    return cat
end
