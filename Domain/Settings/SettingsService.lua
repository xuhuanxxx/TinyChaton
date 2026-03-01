local addonName, addon = ...
local L = addon.L

addon.CategoryBuilders = addon.CategoryBuilders or {}

-- Category Order Configuration
local CATEGORY_ORDER = {
    "general",
    "buttons",
    "automation",
    "chat",
    "data",
    "filters",
    "profile",
}

-- Main Register
-- Settings structure version (increment when changing settings structure)
local SETTINGS_VERSION = 6

local function ResolveAccessor(reg)
    local accessor = reg and reg.accessor or nil
    if not accessor then
        accessor = {
            get = reg and (reg.get or reg.getValue) or nil,
            set = reg and (reg.set or reg.setValue) or nil,
        }
    end
    return accessor
end

local function GetRegistryByKey(key)
    local staticReg = addon.SETTING_REGISTRY and addon.SETTING_REGISTRY[key]
    if staticReg then
        return staticReg
    end
    return addon.RUNTIME_SETTING_REGISTRY and addon.RUNTIME_SETTING_REGISTRY[key] or nil
end

local function ResolveDefault(reg)
    if not reg then return nil end
    -- Default values are runtime-resolved. Do not cache function defaults
    -- across context changes (e.g. theme-dependent appearance settings).
    if type(reg.default) == "function" then
        return reg.default()
    end
    return reg.default
end

local function ValidateByType(reg, value)
    if not reg then
        return false, "unknown setting"
    end

    if reg.validate then
        return reg.validate(value)
    end

    local t = reg.valueType
    if t == "boolean" and type(value) ~= "boolean" then
        return false, "expected boolean"
    elseif t == "number" and type(value) ~= "number" then
        return false, "expected number"
    elseif (t == "string" or t == "color") and type(value) ~= "string" then
        return false, "expected string"
    elseif t == "table" and type(value) ~= "table" then
        return false, "expected table"
    end

    if reg.ui and reg.ui.type == "slider" and type(value) == "number" then
        if reg.ui.min and value < reg.ui.min then
            return false, "below min"
        end
        if reg.ui.max and value > reg.ui.max then
            return false, "above max"
        end
    end

    if reg.ui and reg.ui.options and type(value) == "string" then
        local options = reg.ui.options()
        if type(options) == "table" and #options > 0 then
            local found = false
            for _, opt in ipairs(options) do
                if opt.value == value then
                    found = true
                    break
                end
            end
            if not found then
                return false, "invalid option"
            end
        end
    end

    return true
end

function addon:RegisterSettings()
    -- Prevent duplicate registration (version-aware)
    if addon._settingsVersion and addon._settingsVersion >= SETTINGS_VERSION then
        return
    end

    -- Use Standard Vertical Layout for Root Category
    local rootCat, _ = Settings.RegisterVerticalLayoutCategory(L["LABEL_ADDON_NAME"])
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

    addon._settingsVersion = SETTINGS_VERSION
    addon._settingsLoaded = true -- Keep flag for diagnostics and compatibility.
    addon.OpenSettings = function()
        if addon.MemoryDiagnostics and addon.MemoryDiagnostics.MarkSettingsOpened then
            addon.MemoryDiagnostics:MarkSettingsOpened()
        end
        Settings.OpenToCategory(addon.settingsCategory:GetID())
    end
end

function addon:GetAllSettings()
    local merged = {}
    for k, reg in pairs(addon.SETTING_REGISTRY or {}) do
        merged[k] = reg
    end
    for k, reg in pairs(addon.RUNTIME_SETTING_REGISTRY or {}) do
        if not merged[k] then
            merged[k] = reg
        end
    end
    return merged
end

function addon:GetSetting(key)
    local reg = GetRegistryByKey(key)
    if not reg then return nil end
    local accessor = ResolveAccessor(reg)
    if accessor and accessor.get then
        return accessor.get()
    end
    return ResolveDefault(reg)
end

function addon:SetSetting(key, value, opts)
    local reg = GetRegistryByKey(key)
    if not reg then
        return false, "unknown setting"
    end

    local ok, err = ValidateByType(reg, value)
    if not ok then
        return false, err
    end

    local accessor = ResolveAccessor(reg)
    if not accessor or not accessor.set then
        return false, "setting is read-only"
    end

    local oldValue = addon:GetSetting(key)
    accessor.set(value)

    if reg.apply then
        reg.apply(value, oldValue)
    elseif not (opts and opts.skipApply) and addon.ApplyAllSettings then
        addon:ApplyAllSettings()
    end

    return true
end

function addon:ExportSettings(opts)
    local result = {}
    for key, reg in pairs(addon:GetAllSettings()) do
        if (not opts or not opts.scope or reg.scope == opts.scope)
            and (not opts or not opts.page or (reg.ui and reg.ui.page == opts.page)) then
            result[key] = addon:GetSetting(key)
        end
    end
    return result
end

function addon:ValidateAllSettings()
    local errors = {}
    for key, reg in pairs(addon:GetAllSettings()) do
        local value = addon:GetSetting(key)
        local ok, err = ValidateByType(reg, value)
        if not ok then
            table.insert(errors, {
                key = key,
                reason = err,
                value = value,
            })
        end
    end
    return {
        ok = #errors == 0,
        errors = errors,
    }
end

function addon:ResetSettings(scopeOrPage)
    for key, reg in pairs(addon:GetAllSettings()) do
        local isMatch = not scopeOrPage
            or reg.scope == scopeOrPage
            or (reg.ui and reg.ui.page == scopeOrPage)
        if isMatch then
            local def = ResolveDefault(reg)
            local accessor = ResolveAccessor(reg)
            if accessor and accessor.set then
                accessor.set(def)
            end
        end
    end
    if addon.ApplyAllSettings then
        addon:ApplyAllSettings()
    end
end

SLASH_TINYCHATON_OPTIONS1 = "/tinychat"
SLASH_TINYCHATON_OPTIONS2 = "/tinychaton"
SlashCmdList["TINYCHATON_OPTIONS"] = function()
    if addon.OpenSettings then
        addon.OpenSettings()
    else
        addon:RegisterSettings()
        if addon.settingsCategory then
            Settings.OpenToCategory(addon.settingsCategory:GetID())
        end
    end
end
