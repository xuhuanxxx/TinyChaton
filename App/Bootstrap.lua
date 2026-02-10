local addonName, addon = ...
local L = addon.L

_G.TinyChaton = addon

addon.chatFrameTransformers = addon.chatFrameTransformers or {}

addon.callbacks = {}

function addon:RegisterCallback(event, func, owner)
    if not event or not func then return end
    if not self.callbacks[event] then self.callbacks[event] = {} end
    table.insert(self.callbacks[event], { func = func, owner = owner })
end

function addon:UnregisterCallback(event, owner)
    if not self.callbacks[event] or owner == nil then return end
    for i = #self.callbacks[event], 1, -1 do
        if self.callbacks[event][i].owner == owner then
            table.remove(self.callbacks[event], i)
        end
    end
end

function addon:FireEvent(event, ...)
    if self.callbacks[event] then
        for _, handler in ipairs(self.callbacks[event]) do
            if handler.func then
                -- Use pcall to prevent one error from breaking all listeners
                local ok, err = pcall(handler.func, ...)
                if not ok then
                    addon:Error("Error in event %s: %s", event, tostring(err))
                end
            end
        end
    end
end

function addon:RegisterChatFrameTransformer(name, fn)
    if not name or not fn then return end
    self.chatFrameTransformers[name] = fn
end

addon.TRANSFORMER_ORDER = {
    "display_strip_prefix",
    "display_highlight",
    "clean_message",
    "channel_formatter",
    "interaction_timestamp",
    "visual_emotes"
}

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

addon.moduleRegistry = {}

--- Register a module for initialization
--- @param name string
--- @param initFn function
function addon:RegisterModule(name, initFn)
    if not name or not initFn then
        addon:Error("Attempted to register invalid module: %s", tostring(name))
        return
    end
    table.insert(self.moduleRegistry, { name = name, init = initFn })
end

function addon:OnInitialize()
    if addon.InitServiceContainer then addon:InitServiceContainer() end
    if addon.InitConfig then addon:InitConfig() end

    if not addon.db then
        print("|cFFFF0000TinyChaton:|r Failed to initialize database")
        return
    end

    if addon.InitPolicyEngine then addon:InitPolicyEngine() end
    if addon.InitEnvironmentService then addon:InitEnvironmentService() end
    if addon.InitFeatureRegistry then addon:InitFeatureRegistry() end

    if addon.InitEvents then addon:InitEvents() end

    if addon.RegisterSettings then
        local ok, err = pcall(addon.RegisterSettings, addon)
        if not ok then
            addon:Error("Settings registration failed: %s", tostring(err))
        end
    end

    local L = addon.L
    if not addon.db.enabled then
        print("|cFF00FF00" .. L["LABEL_ADDON_NAME"] .. "|r" .. L["MSG_DISABLED"])
    else
        print("|cFF00FF00" .. L["LABEL_ADDON_NAME"] .. "|r" .. L["MSG_LOADED"])
    end

    addon:SetupChatFrameHooks()

    if addon.InitializeEventDispatcher then
        addon:InitializeEventDispatcher()
    end

    -- Modules are registered when their files are loaded (TOC order determines registry order)
    for _, mod in ipairs(self.moduleRegistry) do
        local ok, err = pcall(mod.init, addon)
        if not ok then
            addon:Error("Failed to init module %s: %s", mod.name, tostring(err))
        end
    end

    if addon.ReconcileFeatures then
        addon:ReconcileFeatures()
    end

    addon:ApplyAllSettings()
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

-- Apply filter settings and invalidate cache
function addon:ApplyFilterSettings()
    -- Increment FilterVersion to invalidate middleware caches
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
    if addon.ApplyAutomationSettings then addon:ApplyAutomationSettings() end
    if addon.ApplyShelfSettings then addon:ApplyShelfSettings() end
    if addon.RefreshShelf then addon:RefreshShelf() end
    if addon.FireEvent then addon:FireEvent("SETTINGS_APPLIED") end
end

-- Profile Management & Data Proxy

-- Recursive synchronization with dynamic default support
local function RecursiveSync(target, source, isReset, path)
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
                RecursiveSync(target[k], realValue, isReset, (path or "") .. "." .. tostring(k))
            else
                target[k] = realValue
            end
        elseif type(v) == "table" and type(target[k]) == "table" then
             -- Recurse even if target exists, to sync nested fields
             RecursiveSync(target[k], v, isReset, (path or "") .. "." .. tostring(k))
        end
    end

    -- Pruning: Remove keys in target that are not in source
    -- CRITICAL CHANGE: Only prune if isReset is TRUE (and source is not empty)
    -- This protects user data from being deleted during normal loading
    if isReset then
        local sourceIsEmpty = (next(source) == nil)
        if sourceIsEmpty then
            return
        end
        for k, v in pairs(target) do
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
        __index = function(t, k)
            if k == "global" then
                return TinyChatonDB.global
            end
            -- Use Cached Profile for performance
            if currentProfileCache then
                return currentProfileCache[k]
            end
            -- Fallback (should rarely happen if cache is maintained)
            local profileName = addon:GetCurrentProfile()
            local profile = TinyChatonDB.profiles[profileName]
            return profile and profile[k] or nil
        end,
        __newindex = function(t, k, v)
            if k == "global" then
                TinyChatonDB.global = v
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
    addon:FireEvent("PROFILE_CHANGED", profileName)
    self:ApplyAllSettings()
    self:RefreshAllSettings()

    return true
end

function addon:LoadProfile(profileName)
    local profile = TinyChatonDB.profiles[profileName]
    if not profile then return end

    currentProfileCache = profile
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
        plugin = addon.Utils.DeepCopy(sourceProfile.plugin) or {},
        system = addon.Utils.DeepCopy(sourceProfile.system) or {}
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

    local charKey = self:GetCharacterKey()
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

    currentProfile.plugin = addon.Utils.DeepCopy(sourceProfile.plugin)
    currentProfile.system = addon.Utils.DeepCopy(sourceProfile.system)

    self:LoadProfile(currentProfileName)
    self:ApplyAllSettings()
    addon:FireEvent("PROFILE_UPDATED", currentProfileName)

    return true
end


function addon:SynchronizeConfig(isReset)
    if not addon.db.plugin then addon.db.plugin = {} end
    if not addon.db.system then addon.db.system = {} end
    if not addon.db.global then addon.db.global = {} end

    if isReset or addon.db.enabled == nil then
        addon.db.enabled = (addon.DEFAULTS.enabled ~= nil) and addon.DEFAULTS.enabled or true
    end

    RecursiveSync(addon.db.plugin, addon.DEFAULTS.plugin, isReset)
    RecursiveSync(addon.db.global, addon.DEFAULTS.global, false)

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
    if not addon.DEFAULTS then
        print("|cFFFF0000TinyChaton Error:|r Config loaded but DEFAULTS is nil")
        TinyChatonDB = TinyChatonDB or { enabled = false }
        UpdateProfileCache()
        InitDBProxy() 
        return
    end

    TinyChatonDB = TinyChatonDB or {}
    if not TinyChatonDB.global then TinyChatonDB.global = {} end
    if not TinyChatonDB.profiles then TinyChatonDB.profiles = {} end
    if not TinyChatonDB.profileKeys then TinyChatonDB.profileKeys = {} end

    if not TinyChatonDB.profiles[addon.CONSTANTS.PROFILE_DEFAULT_NAME] then
        TinyChatonDB.profiles[addon.CONSTANTS.PROFILE_DEFAULT_NAME] = {
            enabled = true,
            plugin = {},
            system = {}
        }
    end

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
    if addon.StopBubbleTicker then addon:StopBubbleTicker() end
    if addon.CancelPendingWelcomeTimers then addon:CancelPendingWelcomeTimers() end
    if addon.CancelTabCycleTimer then addon:CancelTabCycleTimer() end
end
