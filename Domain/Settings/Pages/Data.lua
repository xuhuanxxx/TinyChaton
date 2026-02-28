local addonName, addon = ...
local L = addon.L

local CategoryBuilders = addon.CategoryBuilders or {}
addon.CategoryBuilders = CategoryBuilders

CategoryBuilders.data = function(rootCat)
    local cat, _ = Settings.RegisterVerticalLayoutSubcategory(rootCat, L["PAGE_DATA"])
    Settings.RegisterAddOnCategory(cat)

    addon.AddSectionHeader(cat, L["SECTION_HISTORY_STORAGE"])
    addon.AddRegistrySetting(cat, "dataSnapshotStorageDefaultMax")
    addon.AddRegistrySetting(cat, "dataSnapshotStorageOverrideEnabled")
    addon.AddRegistrySetting(cat, "dataSnapshotStorageOverrideValue")

    addon.AddSectionHeader(cat, L["SECTION_HISTORY_REPLAY"])
    addon.AddRegistrySetting(cat, "dataSnapshotReplayDefaultMax")
    addon.AddRegistrySetting(cat, "dataSnapshotReplayOverrideEnabled")
    addon.AddRegistrySetting(cat, "dataSnapshotReplayOverrideValue")

    addon.AddSectionHeader(cat, L["SECTION_HISTORY_ACTIONS"])
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

    return cat
end
