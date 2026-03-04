local addonName, addon = ...
local L = addon.L

-- Resolve channel display name using current display policy.
function addon:GetChannelLabel(item, channelNumber)
    if addon.ChannelIdentityResolver and addon.ChannelIdentityResolver.FormatDisplayText then
        return addon.ChannelIdentityResolver.FormatDisplayText(item, "channel", "chat", {
            streamMeta = { channelId = channelNumber },
        })
    end
    local label = (item and item.identity and item.identity.labelKey and L[item.identity.labelKey]) or item.key or "UNKNOWN"
    return tostring(label)
end

-- Apply filter settings and invalidate cache
function addon:ApplyFilterSettings()
    addon.FilterVersion = (addon.FilterVersion or 0) + 1

    if addon.Debug then
        addon:Debug(string.format("Filter cache invalidated (version: %d)", addon.FilterVersion))
    end
end

local function RequireAddonMethod(methodName)
    local fn = addon[methodName]
    if type(fn) ~= "function" then
        error(string.format("Required addon method missing: %s", tostring(methodName)))
    end
    return fn
end

function addon:ApplyAllSettings()
    local fireEvent = RequireAddonMethod("FireEvent")
    if not addon.db.enabled then
        if addon.Shelf and addon.Shelf.frame then addon.Shelf.frame:Hide() end
        addon:Shutdown()
        fireEvent(addon, "SETTINGS_APPLIED")
        return
    end

    RequireAddonMethod("ApplyChatFontSettings")(addon)
    RequireAddonMethod("ApplyStickyChannelSettings")(addon)
    RequireAddonMethod("ApplyFilterSettings")(addon)
    RequireAddonMethod("ApplyAutoJoinSettings")(addon)
    RequireAddonMethod("ApplyAutoWelcomeSettings")(addon)
    RequireAddonMethod("ApplyShelfSettings")(addon)
    RequireAddonMethod("RefreshShelf")(addon)
    fireEvent(addon, "SETTINGS_APPLIED")
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
        for k, _ in pairs(target) do
            if source[k] == nil and type(k) == "string" then
                target[k] = nil
            end
        end
    end
end

local currentProfileCache = nil
local VALID_CHAT_NAME_STYLES = { FULL = true, SHORT_ONE = true, SHORT_TWO = true }
local VALID_SHELF_NAME_STYLES = { SHORT_ONE = true, SHORT_TWO = true }

local function EnsureDisplayConfig(profile)
    if type(profile) ~= "table" then return end
    if type(profile.chat) ~= "table" then profile.chat = {} end
    if type(profile.chat.visual) ~= "table" then profile.chat.visual = {} end
    if type(profile.chat.visual.display) ~= "table" then profile.chat.visual.display = {} end
    if type(profile.chat.visual.display.channel) ~= "table" then profile.chat.visual.display.channel = {} end

    if type(profile.shelf) ~= "table" then profile.shelf = {} end
    if type(profile.shelf.visual) ~= "table" then profile.shelf.visual = {} end
    if type(profile.shelf.visual.display) ~= "table" then profile.shelf.visual.display = {} end

    local chatChannel = profile.chat.visual.display.channel
    local shelfDisplay = profile.shelf.visual.display

    -- Strict schema normalization:
    -- chat keeps FULL/SHORT_ONE/SHORT_TWO; shelf keeps SHORT_ONE/SHORT_TWO only.
    -- Drop obsolete display keys on every startup (idempotent cleanup).
    if type(chatChannel.showNumber) ~= "boolean" then
        chatChannel.showNumber = true
    end
    if not VALID_CHAT_NAME_STYLES[chatChannel.nameStyle] then
        chatChannel.nameStyle = "SHORT_ONE"
    end
    if not VALID_SHELF_NAME_STYLES[shelfDisplay.nameStyle] then
        shelfDisplay.nameStyle = "SHORT_ONE"
    end

    profile.chat.visual.display.kit = nil
    profile.shelf.visual.display.channel = nil
    profile.shelf.visual.display.kit = nil
    profile.chat.visual.channelNameFormat = nil
end

local function EnsureChannelCandidatesRegistry()
    addon.ChannelCandidatesValid = true
    addon.ChannelCandidatesErrors = nil

    local registry = addon.ChannelCandidatesRegistry
    if not registry or type(registry.Validate) ~= "function" then
        addon.ChannelCandidatesValid = false
        addon.ChannelCandidatesErrors = { "ChannelCandidatesRegistry missing or invalid" }
        return
    end

    local locale = (type(GetLocale) == "function" and GetLocale()) or "enUS"
    if type(registry.BuildCanonicalIndex) == "function" then
        registry:BuildCanonicalIndex(locale)
    end
    local ok, errs = registry:Validate(locale)
    if ok then
        return
    end

    addon.ChannelCandidatesValid = false
    addon.ChannelCandidatesErrors = errs
    local prefix = (L and L["LABEL_ADDON_NAME"]) or "TinyChaton"
    print("|cffff0000" .. prefix .. "|r: candidate registry validation failed.")
    if type(errs) == "table" then
        for _, err in ipairs(errs) do
            print("|cffff0000" .. prefix .. "|r: " .. tostring(err))
        end
    end
end

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
    if addon.StreamRuleEngine and addon.StreamRuleEngine.ClearAllCaches then
        addon.StreamRuleEngine:ClearAllCaches("profile_switch")
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
    if addon.StreamRuleEngine and addon.StreamRuleEngine.ClearAllCaches then
        addon.StreamRuleEngine:ClearAllCaches("profile_load")
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
    if type(addon.db.profile) ~= "table" then
        error("addon.db.profile not initialized")
    end
    if type(addon.db.account) ~= "table" then
        error("addon.db.account not initialized")
    end

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
    EnsureDisplayConfig(addon.db and addon.db.profile)
    EnsureChannelCandidatesRegistry()
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
    if addon.StreamEventDispatcher and addon.StreamEventDispatcher.UnregisterFilters then
        addon.StreamEventDispatcher:UnregisterFilters()
    end
    if addon.StopBubbleTicker then addon:StopBubbleTicker() end
    if addon.CancelPendingWelcomeTimers then addon:CancelPendingWelcomeTimers() end
    if addon.CancelTabCycleTimer then addon:CancelTabCycleTimer() end
end
