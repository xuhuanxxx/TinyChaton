local addonName, addon = ...
local L = addon.L

-- Resolve channel display name based on format setting
function addon:GetChannelLabel(item, channelNumber, format)
    local fmt = format or (addon.db.profile and addon.db.profile.chat and addon.db.profile.chat.visual and addon.db.profile.chat.visual.channelNameFormat) or "SHORT"

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

-- Apply filter settings and invalidate cache
function addon:ApplyFilterSettings()
    addon.FilterVersion = (addon.FilterVersion or 0) + 1

    if addon.Debug then
        addon:Debug(string.format("Filter cache invalidated (version: %d)", addon.FilterVersion))
    end
end

function addon:ApplyAllSettings()
    if not addon.db.enabled then
        if addon.Shelf and addon.Shelf.frame then addon.Shelf.frame:Hide() end
        addon:Shutdown()
        if addon.FireEvent then addon:FireEvent("SETTINGS_APPLIED") end
        return
    end

    if addon.ApplyChatFontSettings then addon:ApplyChatFontSettings() end
    if addon.ApplyStickyChannelSettings then addon:ApplyStickyChannelSettings() end
    if addon.ApplyFilterSettings then addon:ApplyFilterSettings() end
    if addon.ApplyAutoJoinSettings then addon:ApplyAutoJoinSettings() end
    if addon.ApplyAutoWelcomeSettings then addon:ApplyAutoWelcomeSettings() end
    if addon.ApplyShelfSettings then addon:ApplyShelfSettings() end
    if addon.RefreshShelf then addon:RefreshShelf() end
    if addon.FireEvent then addon:FireEvent("SETTINGS_APPLIED") end
end

-- Profile Management & Data Proxy
local function RecursiveSync(target, source, isReset)
    if type(target) ~= "table" or type(source) ~= "table" then return end

    for k, v in pairs(source) do
        if isReset or target[k] == nil then
            local realValue = v
            if type(v) == "function" then
                realValue = v()
            end

            if type(realValue) == "table" then
                if type(target[k]) ~= "table" then
                    target[k] = {}
                end
                RecursiveSync(target[k], realValue, isReset)
            else
                target[k] = realValue
            end
        elseif type(v) == "table" and type(target[k]) == "table" then
            RecursiveSync(target[k], v, isReset)
        end
    end

    if isReset then
        local sourceIsEmpty = (next(source) == nil)
        if sourceIsEmpty then
            return
        end
        for k, _ in pairs(target) do
            if source[k] == nil and type(k) == "string" then
                target[k] = nil
            end
        end
    end
end

local currentProfileCache = nil

function addon:GetCurrentProfile()
    if not TinyChatonDB.profileKeys then return addon.CONSTANTS.PROFILE_DEFAULT_NAME end
    local charKey = self:GetCharacterKey()
    return TinyChatonDB.profileKeys[charKey] or addon.CONSTANTS.PROFILE_DEFAULT_NAME
end

local function UpdateProfileCache()
    local profileName = addon:GetCurrentProfile()
    currentProfileCache = TinyChatonDB.profiles[profileName]
end

local function InitDBProxy()
    addon.db = setmetatable({}, {
        __index = function(_, k)
            if k == "account" then
                return TinyChatonDB.account
            end
            if currentProfileCache then
                return currentProfileCache[k]
            end
            local profileName = addon:GetCurrentProfile()
            local profile = TinyChatonDB.profiles[profileName]
            return profile and profile[k] or nil
        end,
        __newindex = function(_, k, v)
            if k == "account" then
                TinyChatonDB.account = v
                return
            end
            if currentProfileCache then
                currentProfileCache[k] = v
            else
                local profileName = addon:GetCurrentProfile()
                local profile = TinyChatonDB.profiles[profileName]
                if profile then
                    profile[k] = v
                end
            end
        end,
        __metatable = false
    })
end

function addon:SetProfile(profileName)
    if not TinyChatonDB.profiles or not TinyChatonDB.profiles[profileName] then
        return false
    end

    local charKey = self:GetCharacterKey()
    TinyChatonDB.profileKeys[charKey] = profileName

    UpdateProfileCache()
    if addon.RuleMatcher and addon.RuleMatcher.ClearAllCaches then
        addon.RuleMatcher.ClearAllCaches("profile_switch")
    end
    addon:FireEvent("PROFILE_CHANGED", profileName)
    self:ApplyAllSettings()
    self:RefreshAllSettings()

    return true
end

function addon:LoadProfile(profileName)
    local profile = TinyChatonDB.profiles[profileName]
    if not profile then return end

    currentProfileCache = profile
    if addon.RuleMatcher and addon.RuleMatcher.ClearAllCaches then
        addon.RuleMatcher.ClearAllCaches("profile_load")
    end
    self:SynchronizeConfig(false)
    addon:FireEvent("PROFILE_LOADED", profileName)
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

    TinyChatonDB.profiles[profileName] = {
        enabled = sourceProfile.enabled,
        profile = addon.Utils.DeepCopy(sourceProfile.profile) or {}
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

    local isCurrentProfile = (self:GetCurrentProfile() == profileName)

    if isCurrentProfile then
        addon:FireEvent("PROFILE_DELETED", profileName)
        self:SetProfile(addon.CONSTANTS.PROFILE_DEFAULT_NAME)
    else
        addon:FireEvent("PROFILE_DELETED", profileName)
    end

    TinyChatonDB.profiles[profileName] = nil

    for key, prof in pairs(TinyChatonDB.profileKeys) do
        if prof == profileName then
            TinyChatonDB.profileKeys[key] = addon.CONSTANTS.PROFILE_DEFAULT_NAME
        end
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

    TinyChatonDB.profiles[newName] = TinyChatonDB.profiles[oldName]
    TinyChatonDB.profiles[oldName] = nil

    for key, prof in pairs(TinyChatonDB.profileKeys) do
        if prof == oldName then
            TinyChatonDB.profileKeys[key] = newName
        end
    end

    if self:GetCurrentProfile() == newName then
        UpdateProfileCache()
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

    currentProfile.profile = addon.Utils.DeepCopy(sourceProfile.profile)

    self:LoadProfile(currentProfileName)
    self:ApplyAllSettings()
    addon:FireEvent("PROFILE_UPDATED", currentProfileName)

    return true
end

function addon:SynchronizeConfig(isReset)
    if not addon.db.profile then addon.db.profile = {} end
    if not addon.db.account then addon.db.account = {} end

    if isReset or addon.db.enabled == nil then
        addon.db.enabled = (addon.DEFAULTS.enabled ~= nil) and addon.DEFAULTS.enabled or true
    end

    RecursiveSync(addon.db.profile, addon.DEFAULTS.profile, isReset)
    RecursiveSync(addon.db.account, addon.DEFAULTS.account, false)

    for key, reg in pairs(addon.SETTING_REGISTRY or {}) do
        local defVal = addon:GetSettingDefault(key)

        if reg.scope == "profile" then
            if reg.get and reg.set then
                if isReset or reg.get() == nil then
                    reg.set(defVal)
                end
            end
        elseif reg.scope == "account" then
            if reg.get and reg.set then
                if isReset or reg.get() == nil then
                    reg.set(defVal)
                end
            end
        end
    end
end

function addon:InitConfig()
    if not addon.DEFAULTS then
        print("|cFFFF0000TinyChaton Error:|r Config loaded but DEFAULTS is nil")
        TinyChatonDB = TinyChatonDB or { enabled = false }
        UpdateProfileCache()
        InitDBProxy()
        return
    end

    TinyChatonDB = TinyChatonDB or {}
    if not TinyChatonDB.account then TinyChatonDB.account = {} end
    if not TinyChatonDB.profiles then TinyChatonDB.profiles = {} end
    if not TinyChatonDB.profileKeys then TinyChatonDB.profileKeys = {} end

    if not TinyChatonDB.profiles[addon.CONSTANTS.PROFILE_DEFAULT_NAME] then
        TinyChatonDB.profiles[addon.CONSTANTS.PROFILE_DEFAULT_NAME] = {
            enabled = true,
            profile = {},
        }
    end

    addon.runtime = addon.runtime or {}
    InitDBProxy()
    UpdateProfileCache()
    self:SynchronizeConfig(false)
end

function addon:RefreshAllSettings()
    if SettingsPanel and SettingsPanel:IsShown() then
        local currentCategory = SettingsPanel:GetCurrentCategory()
        if currentCategory then
            SettingsPanel:SelectCategory(currentCategory)
        end
    end
end

function addon:Shutdown()
    if addon.EventDispatcher and addon.EventDispatcher.UnregisterFilters then
        addon.EventDispatcher:UnregisterFilters()
    end
    if addon.UnhookChatFrames then addon:UnhookChatFrames() end
    if addon.RestoreShortChannelGlobals then addon:RestoreShortChannelGlobals() end
    if addon.StopBubbleTicker then addon:StopBubbleTicker() end
    if addon.CancelPendingWelcomeTimers then addon:CancelPendingWelcomeTimers() end
    if addon.CancelTabCycleTimer then addon:CancelTabCycleTimer() end
end
