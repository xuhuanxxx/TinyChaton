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

local function EnsureSchemaCore()
    if not addon.TinyCoreSettingsSchemaRegistry or type(addon.TinyCoreSettingsSchemaRegistry.New) ~= "function" then
        error("TinyCore SettingsSchemaRegistry is not initialized")
    end
    if not addon.TinyCoreSettingsSchemaValidator or type(addon.TinyCoreSettingsSchemaValidator.ValidateByType) ~= "function" then
        error("TinyCore SettingsSchemaValidator is not initialized")
    end

    addon._tinyCoreSettingsSchemaRegistry = addon._tinyCoreSettingsSchemaRegistry
        or addon.TinyCoreSettingsSchemaRegistry:New({
            getStaticRegistry = function()
                return addon.SETTING_REGISTRY
            end,
            getRuntimeRegistry = function()
                return addon.RUNTIME_SETTING_REGISTRY
            end,
        })

    return addon._tinyCoreSettingsSchemaRegistry, addon.TinyCoreSettingsSchemaValidator
end

local function GetRegistryByKey(key)
    local schemaRegistry = EnsureSchemaCore()
    return schemaRegistry:GetByKey(key)
end

local function ResolveDefault(reg)
    local _, validator = EnsureSchemaCore()
    return validator.ResolveDefault(reg)
end

local function ValidateByType(reg, value)
    local _, validator = EnsureSchemaCore()
    return validator.ValidateByType(reg, value)
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
    local schemaRegistry = EnsureSchemaCore()
    return schemaRegistry:GetAll()
end

function addon:GetSetting(key)
    local reg = GetRegistryByKey(key)
    if not reg then return nil end
    local _, validator = EnsureSchemaCore()
    local accessor = validator.ResolveAccessor(reg)
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

    local _, validator = EnsureSchemaCore()
    local accessor = validator.ResolveAccessor(reg)
    if not accessor or not accessor.set then
        return false, "setting is read-only"
    end

    local oldValue = addon:GetSetting(key)
    accessor.set(value)

    if reg.apply then
        reg.apply(value, oldValue)
    elseif not (opts and opts.skipApply) and addon.CommitSettings then
        addon:CommitSettings()
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
            local _, validator = EnsureSchemaCore()
            local accessor = validator.ResolveAccessor(reg)
            if accessor and accessor.set then
                accessor.set(def)
            end
        end
    end
    if addon.CommitSettings then
        addon:CommitSettings()
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
