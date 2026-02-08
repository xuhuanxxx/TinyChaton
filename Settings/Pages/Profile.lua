local addonName, addon = ...
local L = addon.L

local CategoryBuilders = addon.CategoryBuilders or {}
addon.CategoryBuilders = CategoryBuilders

CategoryBuilders.profile = function(rootCat)
    local cat, _ = Settings.RegisterVerticalLayoutSubcategory(rootCat, L["PAGE_PROFILE"])
    Settings.RegisterAddOnCategory(cat)
    
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
    
    -- Profile Management
    addon.AddSectionHeader(cat, L["SECTION_PROFILE_MANAGEMENT"])
    
    -- Current Profile Dropdown
    addon.AddNativeDropdown(cat, P .. "currentProfile",
        L["LABEL_CURRENT_PROFILE"],
        addon.CONSTANTS.PROFILE_DEFAULT_NAME,
        function()
            local c = Settings.CreateControlTextContainer()
            local profiles = addon:GetProfileList()
            for _, name in ipairs(profiles) do
                c:Add(name, name)
            end
            return c:GetData()
        end,
        function() return addon:GetCurrentProfile() end,
        function(profileName)
            local success = addon:SetProfile(profileName)
            if success then
                print("|cFF00FF00" .. L["LABEL_ADDON_NAME"] .. "|r " .. string.format(L["MSG_PROFILE_SWITCHED"], profileName))
            end
        end,
        nil)
    
    -- New Profile Button
    addon.AddNativeButton(cat, L["ACTION_NEW_PROFILE"], L["ACTION_NEW_PROFILE"], function()
        StaticPopupDialogs["TINYCHATON_NEW_PROFILE"] = {
            text = L["PROMPT_PROFILE_NAME"],
            button1 = ACCEPT,
            button2 = CANCEL,
            hasEditBox = true,
            maxLetters = 32,
            OnShow = function(self)
                local defaultText = addon:GetCharacterKey()
                self.EditBox:SetText(defaultText)
                self.EditBox:HighlightText()
                
                -- Calculate adaptive width based on text length
                -- Use a temporary FontString to measure text width
                if not self.measureString then
                    self.measureString = self.EditBox:CreateFontString(nil, "OVERLAY")
                    self.measureString:SetFontObject(self.EditBox:GetFontObject())
                end
                self.measureString:SetText(defaultText)
                
                -- Add padding (20px on each side)
                local textWidth = self.measureString:GetStringWidth()
                local minWidth = 200  -- Minimum width
                local maxWidth = 400  -- Maximum width
                local padding = 40
                local calculatedWidth = math.min(math.max(textWidth + padding, minWidth), maxWidth)
                
                self.EditBox:SetWidth(calculatedWidth)
                
                -- Adjust dialog width to fit the edit box
                -- StaticPopup default width is 320, we may need to expand it
                if calculatedWidth > 280 then
                    self:SetWidth(calculatedWidth + 40)  -- Add margins
                end
            end,
            OnAccept = function(self)
                local name = self.EditBox:GetText()
                local currentProfile = addon:GetCurrentProfile()
                local success, err = addon:CreateProfile(name, currentProfile)
                if success then
                    addon:SetProfile(name)
                    print("|cFF00FF00" .. L["LABEL_ADDON_NAME"] .. "|r " .. string.format(L["MSG_PROFILE_CREATED"], name))
                else
                    print("|cFFFF0000" .. L["LABEL_ADDON_NAME"] .. "|r " .. (err or L["ERROR_PROFILE_INVALID_NAME"]))
                end
            end,
            EditBoxOnEscapePressed = function(self) self:GetParent():Hide() end,
            hideOnEscape = true,
            timeout = 0,
            exclusive = true,
        }
        StaticPopup_Show("TINYCHATON_NEW_PROFILE")
    end)
    
    -- Delete Profile Button
    addon.AddNativeButton(cat, L["ACTION_DELETE_PROFILE"], L["ACTION_DELETE_PROFILE"], function()
        local currentProfile = addon:GetCurrentProfile()
        if currentProfile == addon.CONSTANTS.PROFILE_DEFAULT_NAME then
            print("|cFFFF0000" .. L["LABEL_ADDON_NAME"] .. "|r " .. L["ERROR_CANNOT_DELETE_DEFAULT"])
            return
        end
        
        StaticPopupDialogs["TINYCHATON_DELETE_PROFILE"] = {
            text = string.format(L["CONFIRM_DELETE_PROFILE"], currentProfile),
            button1 = YES,
            button2 = NO,
            OnAccept = function()
                local success, err = addon:DeleteProfile(currentProfile)
                if success then
                    print("|cFF00FF00" .. L["LABEL_ADDON_NAME"] .. "|r " .. string.format(L["MSG_PROFILE_DELETED"], currentProfile))
                else
                    print("|cFFFF0000" .. L["LABEL_ADDON_NAME"] .. "|r " .. (err or "Error"))
                end
            end,
            hideOnEscape = true,
            timeout = 0,
        }
        StaticPopup_Show("TINYCHATON_DELETE_PROFILE")
    end)
    
    -- Rename Profile Button
    addon.AddNativeButton(cat, L["ACTION_RENAME_PROFILE"], L["ACTION_RENAME_PROFILE"], function()
        local currentProfile = addon:GetCurrentProfile()
        if currentProfile == addon.CONSTANTS.PROFILE_DEFAULT_NAME then
            print("|cFFFF0000" .. L["LABEL_ADDON_NAME"] .. "|r " .. L["ERROR_CANNOT_RENAME_DEFAULT"])
            return
        end
        
        StaticPopupDialogs["TINYCHATON_RENAME_PROFILE"] = {
            text = L["PROMPT_PROFILE_NAME"],
            button1 = ACCEPT,
            button2 = CANCEL,
            hasEditBox = true,
            maxLetters = 32,
            OnShow = function(self)
                self.EditBox:SetWidth(300)
            end,
            OnAccept = function(self)
                local newName = self.EditBox:GetText()
                local success, err = addon:RenameProfile(currentProfile, newName)
                if success then
                    print("|cFF00FF00" .. L["LABEL_ADDON_NAME"] .. "|r " .. string.format(L["MSG_PROFILE_RENAMED"], newName))
                else
                    print("|cFFFF0000" .. L["LABEL_ADDON_NAME"] .. "|r " .. (err or L["ERROR_PROFILE_INVALID_NAME"]))
                end
            end,
            EditBoxOnEscapePressed = function(self) self:GetParent():Hide() end,
            hideOnEscape = true,
            timeout = 0,
        }
        StaticPopup_Show("TINYCHATON_RENAME_PROFILE")
    end)
    
    -- Copy from Profile Dropdown
    addon.AddNativeDropdown(cat, P .. "copyFromProfile",
        L["LABEL_COPY_FROM_PROFILE"],
        "",
        function()
            local c = Settings.CreateControlTextContainer()
            c:Add("", L["LABEL_SELECT_PROFILE"] or "-- Select Profile --")
            local profiles = addon:GetProfileList()
            local currentProfile = addon:GetCurrentProfile()
            for _, name in ipairs(profiles) do
                if name ~= currentProfile then
                    c:Add(name, name)
                end
            end
            return c:GetData()
        end,
        function() return "" end,  -- Always show default "Select Profile"
        function(selectedProfile)
            if selectedProfile and selectedProfile ~= "" then
                local success, err = addon:CopyFromProfile(selectedProfile)
                if success then
                    print("|cFF00FF00" .. L["LABEL_ADDON_NAME"] .. "|r " .. string.format(L["MSG_PROFILE_COPIED"], selectedProfile))
                else
                    print("|cFFFF0000" .. L["LABEL_ADDON_NAME"] .. "|r " .. (err or "Error"))
                end
            end
        end,
        L["TOOLTIP_COPY_FROM_PROFILE"])

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
