local addonName, addon = ...
local L = addon.L

addon.chatFrameTransformers = addon.chatFrameTransformers or {}

function addon:RegisterChatFrameTransformer(name, fn)
    if not name or not fn then return end
    self.chatFrameTransformers[name] = fn
end

local TRANSFORMER_ORDER = { "copy", "visual" }

-- Track hooked frames for unhook support
local hookedFrames = {}

local function SetupChatFrameAddMessageHook(frame)
    if frame._TinyChatonAddMessageHooked then return end
    frame._TinyChatonAddMessageHooked = true
    local orig = frame.AddMessage
    -- Save original AddMessage for direct access (used by history restore)
    frame._TinyChatonOrigAddMessage = orig
    frame.AddMessage = function(self, msg, ...)
        for _, name in ipairs(TRANSFORMER_ORDER) do
            local fn = addon.chatFrameTransformers[name]
            if fn then
                local ok, result = pcall(fn, self, msg, ...)
                if ok and result ~= nil then msg = result end
            end
        end
        return orig(self, msg, ...)
    end
    table.insert(hookedFrames, frame)
end

-- Unhook all chat frames (restore original AddMessage)
function addon:UnhookChatFrames()
    for _, frame in ipairs(hookedFrames) do
        if frame._TinyChatonOrigAddMessage then
            frame.AddMessage = frame._TinyChatonOrigAddMessage
            frame._TinyChatonOrigAddMessage = nil
            frame._TinyChatonAddMessageHooked = nil
        end
    end
    hookedFrames = {}
end

function addon:SetupChatFrameHooks()
    for i = 1, NUM_CHAT_WINDOWS do
        local cf = _G["ChatFrame" .. i]
        if cf and cf.AddMessage then
            SetupChatFrameAddMessageHook(cf)
        end
    end
    if FCF_OpenTemporaryWindow then
        hooksecurefunc("FCF_OpenTemporaryWindow", function(chatFrame)
            if not chatFrame or chatFrame._TinyChatonAddMessageHooked then return end
            if chatFrame.AddMessage then
                SetupChatFrameAddMessageHook(chatFrame)
            else
                -- Fallback: Hook OnShow for late initialization
                chatFrame:HookScript("OnShow", function(self)
                    if not self._TinyChatonAddMessageHooked and self.AddMessage then
                        SetupChatFrameAddMessageHook(self)
                    end
                end)
            end
        end)
    end
end

local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        local loadedAddon = ...
        if loadedAddon == addonName then
            addon:OnInitialize()
            self:UnregisterEvent("ADDON_LOADED")
        end
    end
end)



function addon:OnInitialize()
    if addon.InitConfig then addon:InitConfig() end
    
    -- Check if InitConfig succeeded
    if not addon.db then
        print("|cFFFF0000TinyChaton:|r Failed to initialize database")
        return
    end
    
    if addon.InitEvents then addon:InitEvents() end
    
    if addon.RegisterSettings then 
        local ok, err = pcall(addon.RegisterSettings, addon)
        if not ok then
            print("|cFFFF0000" .. L["LABEL_ADDON_NAME"] .. " " .. L["MSG_SETTINGS_ERROR"] .. "|r", err)
        end
    end

    if not addon.db.enabled then
        print("|cFF00FF00" .. L["LABEL_ADDON_NAME"] .. "|r" .. L["MSG_DISABLED"])
        if addon.RegisterSettings then 
            pcall(addon.RegisterSettings, addon)
        end
        return
    end

    addon:SetupChatFrameHooks()
    
    -- Register modules in load order
    addon.MODULES = { "Filters", "Highlight", "Snapshot", "Copy", "Emotes", "Social", "Tweaks", "Shelf" }
    for _, module in ipairs(addon.MODULES) do
        local fn = addon["Init" .. module]
        if fn then
            local ok, err = pcall(fn, addon)
            if not ok then
                print("|cFFFF0000TinyChaton:|r Failed to init module " .. module .. ": " .. tostring(err))
            end
        end
    end

    addon:ApplyAllSettings()

    print("|cFF00FF00" .. L["LABEL_ADDON_NAME"] .. "|r" .. L["MSG_LOADED"])
end

-- Resolve channel display name based on format setting
function addon:GetChannelLabel(item, channelNumber, format)
    local fmt = format or (addon.db.plugin and addon.db.plugin.chat and addon.db.plugin.chat.visual and addon.db.plugin.chat.visual.channelNameFormat) or "SHORT"
    
    local id = channelNumber
    if not id and item.chatType == "CHANNEL" then
        if item.mappingKey then
            local name = L[item.mappingKey]
            if name then
                id = GetChannelName(name)
            end
        end
    end
    
    if fmt == "FULL" then 
        return item.label 
    end
    
    if fmt == "NUMBER" then 
        return tostring(id or item.label) 
    end

    local short = item.shortKey and L[item.shortKey]
    if not short or short == "" then
        short = "[" .. (item.key or "UNKNOWN") .. "]"
    end

    if fmt == "NUMBER_SHORT" and id then
        return id .. "." .. short
    end
    
    return short
end

function addon:ApplyAllSettings()
    if not addon.db.enabled then
        if addon.Shelf and addon.Shelf.frame then addon.Shelf.frame:Hide() end
        addon:Shutdown()
        return
    end

    if addon.ApplyChatFontSettings then addon:ApplyChatFontSettings() end
    if addon.ApplyChatVisualSettings then addon:ApplyChatVisualSettings() end
    if addon.ApplyFilterSettings then addon:ApplyFilterSettings() end
    if addon.ApplyAutomationSettings then addon:ApplyAutomationSettings() end
    if addon.ApplyShelfSettings then addon:ApplyShelfSettings() end
    if addon.RefreshShelf then addon:RefreshShelf() end
end

local function RecursiveSync(target, source, isReset, isPruning)
    if not target or not source then return end

    for k, v in pairs(source) do
        if type(v) == "table" then
            if type(target[k]) ~= "table" then
                target[k] = {}
            end
            RecursiveSync(target[k], v, isReset, isPruning)
        else
            if isReset or target[k] == nil then
                target[k] = v
            end
        end
    end

    if isPruning then
        for k, v in pairs(target) do
            if source[k] == nil then
                target[k] = nil
            end
        end
    end
end

-- ============================================
-- Profile Management
-- ============================================
function addon:GetCharacterKey()
    local name = UnitName("player")
    local realm = GetRealmName()
    return string.format("%s-%s", name, realm)
end

function addon:GetCurrentProfile()
    if not TinyChatonDB.profileKeys then return addon.CONSTANTS.PROFILE_DEFAULT_NAME end
    local charKey = self:GetCharacterKey()
    return TinyChatonDB.profileKeys[charKey] or addon.CONSTANTS.PROFILE_DEFAULT_NAME
end

function addon:SetProfile(profileName)
    if not TinyChatonDB.profiles or not TinyChatonDB.profiles[profileName] then 
        return false 
    end
    
    local charKey = self:GetCharacterKey()
    TinyChatonDB.profileKeys[charKey] = profileName
    
    -- Reload profile
    self:LoadProfile(profileName)
    self:ApplyAllSettings()
    
    return true
end

function addon:LoadProfile(profileName)
    local profile = TinyChatonDB.profiles[profileName]
    if not profile then return end
    
    -- Point addon.db to current profile
    addon.db.enabled = profile.enabled
    addon.db.plugin = profile.plugin
    addon.db.system = profile.system
    addon.db.global = TinyChatonDB.global
end

function addon:CreateProfile(profileName, copyFrom)
    if not profileName or profileName == "" then return false, "Invalid profile name" end
    if #profileName > addon.CONSTANTS.PROFILE_NAME_MAX_LENGTH then 
        return false, "Profile name too long" 
    end
    if TinyChatonDB.profiles[profileName] then 
        return false, "Profile already exists" 
    end
    
    local sourceProfile = copyFrom and TinyChatonDB.profiles[copyFrom] or TinyChatonDB.profiles[addon.CONSTANTS.PROFILE_DEFAULT_NAME]
    if not sourceProfile then 
        return false, "Source profile not found" 
    end
    
    -- Deep copy source profile
    TinyChatonDB.profiles[profileName] = {
        enabled = sourceProfile.enabled,
        plugin = addon.Utils.DeepCopy(sourceProfile.plugin),
        system = addon.Utils.DeepCopy(sourceProfile.system)
    }
    
    return true
end

function addon:DeleteProfile(profileName)
    if profileName == addon.CONSTANTS.PROFILE_DEFAULT_NAME then 
        return false, "Cannot delete default profile" 
    end
    if not TinyChatonDB.profiles[profileName] then 
        return false, "Profile not found" 
    end
    
    -- Check if any character is using this profile
    local charKey = self:GetCharacterKey()
    local isCurrentProfile = (self:GetCurrentProfile() == profileName)
    
    -- Delete profile
    TinyChatonDB.profiles[profileName] = nil
    
    -- Update profileKeys (switch affected characters to Default)
    for key, prof in pairs(TinyChatonDB.profileKeys) do
        if prof == profileName then
            TinyChatonDB.profileKeys[key] = addon.CONSTANTS.PROFILE_DEFAULT_NAME
        end
    end
    
    -- If current character was using this profile, reload Default
    if isCurrentProfile then
        self:LoadProfile(addon.CONSTANTS.PROFILE_DEFAULT_NAME)
        self:ApplyAllSettings()
    end
    
    return true
end

function addon:RenameProfile(oldName, newName)
    if oldName == addon.CONSTANTS.PROFILE_DEFAULT_NAME then 
        return false, "Cannot rename default profile" 
    end
    if not TinyChatonDB.profiles[oldName] then 
        return false, "Profile not found" 
    end
    if TinyChatonDB.profiles[newName] then 
        return false, "New name already exists" 
    end
    if not newName or newName == "" then 
        return false, "Invalid new name" 
    end
    if #newName > addon.CONSTANTS.PROFILE_NAME_MAX_LENGTH then 
        return false, "Profile name too long" 
    end
    
    -- Rename profile
    TinyChatonDB.profiles[newName] = TinyChatonDB.profiles[oldName]
    TinyChatonDB.profiles[oldName] = nil
    
    -- Update profileKeys
    for key, prof in pairs(TinyChatonDB.profileKeys) do
        if prof == oldName then
            TinyChatonDB.profileKeys[key] = newName
        end
    end
    
    return true
end

function addon:GetProfileList()
    local profiles = {}
    for name in pairs(TinyChatonDB.profiles or {}) do
        table.insert(profiles, name)
    end
    table.sort(profiles)
    return profiles
end

function addon:CopyFromProfile(sourceProfileName)
    local currentProfileName = self:GetCurrentProfile()
    
    if not TinyChatonDB.profiles[sourceProfileName] then 
        return false, "Source profile not found" 
    end
    if sourceProfileName == currentProfileName then
        return false, "Cannot copy from current profile"
    end
    
    local sourceProfile = TinyChatonDB.profiles[sourceProfileName]
    local currentProfile = TinyChatonDB.profiles[currentProfileName]
    
    -- Deep copy settings from source to current profile
    currentProfile.plugin = addon.Utils.DeepCopy(sourceProfile.plugin)
    currentProfile.system = addon.Utils.DeepCopy(sourceProfile.system)
    
    -- Reload current profile to apply changes
    self:LoadProfile(currentProfileName)
    self:ApplyAllSettings()
    
    return true
end


function addon:SynchronizeConfig(isReset)

    if not addon.db.plugin then addon.db.plugin = {} end
    if not addon.db.system then addon.db.system = {} end
    if not addon.db.global then addon.db.global = {} end

    if isReset or addon.db.enabled == nil then
        addon.db.enabled = (addon.DEFAULTS.enabled ~= nil) and addon.DEFAULTS.enabled or true
    end

    RecursiveSync(addon.db.plugin, addon.DEFAULTS.plugin, isReset, true)
    -- global data should never be reset, only initialized if missing
    RecursiveSync(addon.db.global, addon.DEFAULTS.global, false, false)

    for key, reg in pairs(addon.SETTING_REGISTRY or {}) do
        local defVal = addon:GetSettingDefault(key)

        if reg.category == "system" then
            if isReset or addon.db.system[key] == nil then
                local realVal = (reg.getValue and reg.getValue())
                addon.db.system[key] = (realVal ~= nil) and realVal or defVal
            end
        elseif reg.category == "plugin" then
            if reg.get and reg.set then
                if isReset or reg.get() == nil then
                    reg.set(defVal)
                end
            end
        end
    end
end

function addon:InitConfig()
    -- Ensure Config module is fully loaded
    if not addon.DEFAULTS then
        local configLoaded, configErr = pcall(function()
            dofile("Interface\\AddOns\\TinyChaton\\Config.lua")
        end)
        if not configLoaded then
            print("|cFFFF0000TinyChaton Error:|r Failed to load Config: " .. tostring(configErr))
            addon.db = TinyChatonDB or { enabled = false }
            return
        end
    end
    
    if not addon.DEFAULTS then
        print("|cFFFF0000TinyChaton Error:|r Config loaded but DEFAULTS is nil")
        addon.db = TinyChatonDB or { enabled = false }
        return
    end
    
    -- Initialize database structure
    TinyChatonDB = TinyChatonDB or {}
    
    -- Initialize global node
    if not TinyChatonDB.global then TinyChatonDB.global = {} end
    
    -- Initialize profiles structure
    if not TinyChatonDB.profiles then
        TinyChatonDB.profiles = {}
    end
    
    -- Initialize profileKeys
    if not TinyChatonDB.profileKeys then 
        TinyChatonDB.profileKeys = {} 
    end
    
    -- Ensure Default profile exists
    if not TinyChatonDB.profiles[addon.CONSTANTS.PROFILE_DEFAULT_NAME] then
        TinyChatonDB.profiles[addon.CONSTANTS.PROFILE_DEFAULT_NAME] = {
            enabled = true,
            plugin = {},
            system = {}
        }
    end
    
    -- Load current character's profile
    local currentProfile = self:GetCurrentProfile()
    local profile = TinyChatonDB.profiles[currentProfile]
    
    -- Setup addon.db (points to current profile + global)
    addon.db = {
        enabled = profile.enabled,
        plugin = profile.plugin,
        system = profile.system,
        global = TinyChatonDB.global
    }
    
    self:SynchronizeConfig(false)
end

function addon:Shutdown()
    if addon.StopBubbleTicker then addon:StopBubbleTicker() end
    if addon.CancelPendingWelcomeTimers then addon:CancelPendingWelcomeTimers() end
    if addon.CancelTweaksTimer then addon:CancelTweaksTimer() end
end
