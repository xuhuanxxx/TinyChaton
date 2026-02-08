local addonName, addon = ...
local L = addon.L

local CategoryBuilders = addon.CategoryBuilders or {}
addon.CategoryBuilders = CategoryBuilders

CategoryBuilders.profile = function(rootCat)
    local cat, _ = Settings.RegisterVerticalLayoutSubcategory(rootCat, L["PAGE_PROFILE"])
    Settings.RegisterAddOnCategory(cat)
    
    addon.AddText(cat, L["LABEL_PROFILE_DESC"])
    
    -- Chat History Management
    addon.AddSectionHeader(cat, L["SECTION_HISTORY"])
    
    local P = "TinyChaton_Profile_"
    local C = addon.CONSTANTS
    addon.AddProxySlider(cat, P .. "snapshotMaxTotal",
        L["LABEL_SNAPSHOT_MAX_TOTAL"],
        C.SNAPSHOT_MAX_TOTAL_DEFAULT,
        C.SNAPSHOT_MAX_TOTAL_MIN,
        C.SNAPSHOT_MAX_TOTAL_MAX,
        C.SNAPSHOT_MAX_TOTAL_STEP,
        function() return addon.db.global.chatSnapshotMaxTotal or C.SNAPSHOT_MAX_TOTAL_DEFAULT end,
        function(v) 
            addon.db.global.chatSnapshotMaxTotal = v
        end,
        L["TOOLTIP_SNAPSHOT_MAX_TOTAL"])

    addon.AddNativeButton(cat, L["LABEL_HISTORY_CLEAR"], L["ACTION_CLEAR_HISTORY"], function()
        StaticPopupDialogs["TINYCHATON_CLEAR_HISTORY"] = {
            text = L["ACTION_HISTORY_CLEAR_CONFIRM"],
            button1 = YES,
            button2 = NO,
            OnAccept = function() addon:ClearHistory() end,
            hideOnEscape = true,
        }
        StaticPopup_Show("TINYCHATON_CLEAR_HISTORY")
    end, L["TOOLTIP_HISTORY_CLEAR"])
    

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
