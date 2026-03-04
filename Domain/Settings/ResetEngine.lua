local addonName, addon = ...

addon.SettingsReset = addon.SettingsReset or {}
local SettingsReset = addon.SettingsReset

SettingsReset.pageSpecs = SettingsReset.pageSpecs or {}
SettingsReset.pageKeyByCategoryId = SettingsReset.pageKeyByCategoryId or {}
SettingsReset.pageKeyByVariable = SettingsReset.pageKeyByVariable or {}

local function DeepCopy(value)
    if addon.Utils and addon.Utils.DeepCopy then
        return addon.Utils.DeepCopy(value)
    end
    return value
end

local function GetProfilePath(path)
    if type(path) ~= "string" or path == "" then
        return nil
    end
    if addon.Utils and addon.Utils.GetByPath then
        return addon.Utils.GetByPath(addon.db and addon.db.profile, path)
    end
    return nil
end

local function SetProfilePath(path, value)
    if type(path) ~= "string" or path == "" then
        return
    end
    if addon.Utils and addon.Utils.SetByPath then
        addon.Utils.SetByPath(addon.db and addon.db.profile, path, value)
    end
end

local function GetDefaultPath(path)
    if type(path) ~= "string" or path == "" then
        return nil
    end
    if addon.Utils and addon.Utils.GetByPath then
        return addon.Utils.GetByPath(addon.DEFAULTS and addon.DEFAULTS.profile, path)
    end
    return nil
end

local function SerializeSelection(selection)
    if type(selection) ~= "table" then
        return ""
    end
    local keys = {}
    for key, enabled in pairs(selection) do
        if enabled == true then
            keys[#keys + 1] = tostring(key)
        end
    end
    table.sort(keys)
    return table.concat(keys, ",")
end

function SettingsReset.SerializeSelection(selection)
    return SerializeSelection(selection)
end

local function TryGetSettingVariable(setting)
    if not setting then return nil end
    if type(setting.GetVariable) == "function" then
        local ok, variable = pcall(setting.GetVariable, setting)
        if ok and type(variable) == "string" and variable ~= "" then
            return variable
        end
    end
    if type(setting.GetVariableName) == "function" then
        local ok, variable = pcall(setting.GetVariableName, setting)
        if ok and type(variable) == "string" and variable ~= "" then
            return variable
        end
    end
    if type(setting.variable) == "string" and setting.variable ~= "" then
        return setting.variable
    end
    return nil
end

function SettingsReset:DeepCopyDefault(path)
    return DeepCopy(GetDefaultPath(path))
end

function SettingsReset:WriteDefault(path)
    SetProfilePath(path, self:DeepCopyDefault(path))
end

function SettingsReset:RegisterPageSpec(pageKey, spec)
    if type(pageKey) ~= "string" or pageKey == "" or type(spec) ~= "table" then
        return
    end

    self.pageSpecs[pageKey] = spec

    if spec.category and spec.category.GetID then
        self.pageKeyByCategoryId[spec.category:GetID()] = pageKey
    end

    if type(spec.refreshControls) == "table" then
        for _, control in ipairs(spec.refreshControls) do
            if type(control) == "table" and type(control.variable) == "string" and control.variable ~= "" then
                self.pageKeyByVariable[control.variable] = pageKey
            end
        end
    end
end

function SettingsReset:RefreshControl(controlSpec)
    if type(controlSpec) ~= "table" then return end
    local variable = controlSpec.variable
    if type(variable) ~= "string" or variable == "" then return end

    if controlSpec.type == "multidropdown" then
        local selection = controlSpec.selection
        if selection == nil and type(controlSpec.selectionFromPath) == "string" then
            selection = GetProfilePath(controlSpec.selectionFromPath)
        end
        if selection == nil and type(controlSpec.selectionGetter) == "function" then
            local ok, value = pcall(controlSpec.selectionGetter)
            if ok then
                selection = value
            end
        end
        addon.RefreshMultiDropdownSelection(variable, selection, { silent = true, serialized = SerializeSelection(selection) })
        return
    end

    local setting = Settings.GetSetting(variable)
    if not setting then return end

    local value = controlSpec.value
    if value == nil and type(controlSpec.valueFromPath) == "string" then
        value = GetProfilePath(controlSpec.valueFromPath)
    end
    if value == nil and controlSpec.valueFromSetting ~= false and setting.GetValue then
        value = setting:GetValue()
    end

    addon.RefreshSettingValue(variable, value, { silent = true })
end

function SettingsReset:RunReset(spec, opts)
    if type(spec) ~= "table" then return end

    if type(spec.preReset) == "function" then
        spec.preReset(opts or {})
    end

    for _, path in ipairs(spec.writeDefaults or {}) do
        self:WriteDefault(path)
    end

    for _, control in ipairs(spec.refreshControls or {}) do
        self:RefreshControl(control)
    end

    if type(spec.postRefresh) == "function" then
        spec.postRefresh(opts or {})
    end

    if not spec.skipApply and addon.ApplyAllSettings then
        addon:ApplyAllSettings()
    end
end

function SettingsReset:ResetPage(pageKey, opts)
    local spec = self.pageSpecs[pageKey]
    if not spec then return false end
    self:RunReset(spec, opts)
    return true
end

function SettingsReset:ResetCategory(category, opts)
    if not category or not category.GetID then return false end
    local pageKey = self.pageKeyByCategoryId[category:GetID()]
    if not pageKey then return false end
    return self:ResetPage(pageKey, opts)
end

function SettingsReset:ResetBySetting(setting, opts)
    local variable = TryGetSettingVariable(setting)
    if not variable then return false end
    local pageKey = self.pageKeyByVariable[variable]
    if not pageKey then return false end
    return self:ResetPage(pageKey, opts)
end

function SettingsReset:ResetAllProfile()
    if not addon.db then
        return
    end
    addon.db.profile = DeepCopy(addon.DEFAULTS and addon.DEFAULTS.profile or {})
    addon.db.enabled = (addon.DEFAULTS and addon.DEFAULTS.enabled ~= nil) and addon.DEFAULTS.enabled or true

    local keys = {}
    for key in pairs(self.pageSpecs) do
        keys[#keys + 1] = key
    end
    table.sort(keys)
    for _, key in ipairs(keys) do
        local spec = self.pageSpecs[key]
        if type(spec.preReset) == "function" then
            spec.preReset({ isGlobal = true })
        end
        for _, control in ipairs(spec.refreshControls or {}) do
            self:RefreshControl(control)
        end
        if type(spec.postRefresh) == "function" then
            spec.postRefresh({ isGlobal = true })
        end
    end

    if addon.StreamRuleEngine and addon.StreamRuleEngine.ClearAllCaches then
        addon.StreamRuleEngine:ClearAllCaches("settings_reset_all")
    end

    if addon.ApplyAllSettings then
        addon:ApplyAllSettings()
    end
    if addon.RefreshAllSettings then
        addon:RefreshAllSettings()
    end
end
