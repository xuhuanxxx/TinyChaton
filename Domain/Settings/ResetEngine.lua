local addonName, addon = ...

addon.SettingsIntentRegistry = addon.SettingsIntentRegistry or {}
local Registry = addon.SettingsIntentRegistry

Registry.pageSpecs = Registry.pageSpecs or {}
Registry.pageKeyByCategoryId = Registry.pageKeyByCategoryId or {}
Registry.pageKeyByVariable = Registry.pageKeyByVariable or {}

local function DeepCopy(value)
    if addon.Utils and addon.Utils.DeepCopy then
        return addon.Utils.DeepCopy(value)
    end
    return value
end

local function GetPath(root, path)
    if type(path) ~= "string" or path == "" then
        return nil
    end
    if addon.Utils and addon.Utils.GetByPath then
        return addon.Utils.GetByPath(root, path)
    end
    return nil
end

local function SetPath(root, path, value)
    if type(path) ~= "string" or path == "" then
        return
    end
    if addon.Utils and addon.Utils.SetByPath then
        addon.Utils.SetByPath(root, path, value)
    end
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

local function ValidateSpec(pageKey, spec)
    if type(pageKey) ~= "string" or pageKey == "" then
        error("Settings page spec key must be a non-empty string")
    end
    if type(spec) ~= "table" then
        error(string.format("Settings page spec '%s' must be a table", tostring(pageKey)))
    end
    for _, field in ipairs({ "preReset", "postRefresh", "skipApply" }) do
        if spec[field] ~= nil then
            error(string.format("Settings page spec '%s' uses removed field '%s'", tostring(pageKey), field))
        end
    end
end

function Registry.SerializeSelection(selection)
    return SerializeSelection(selection)
end

function Registry:RegisterPageSpec(pageKey, spec)
    ValidateSpec(pageKey, spec)

    local normalized = {
        pageKey = pageKey,
        category = spec.category,
        scope = spec.scope or "all",
        writeDefaults = spec.writeDefaults or {},
        writeRootDefaults = spec.writeRootDefaults or {},
        refreshControls = spec.refreshControls or {},
        clearRuleCaches = spec.clearRuleCaches == true,
        refreshShelf = spec.refreshShelf == true,
        refreshShelfList = spec.refreshShelfList == true,
        refreshShelfPreview = spec.refreshShelfPreview == true,
        refreshSettingsPanel = spec.refreshSettingsPanel ~= false,
    }

    self.pageSpecs[pageKey] = normalized

    if normalized.category and normalized.category.GetID then
        self.pageKeyByCategoryId[normalized.category:GetID()] = pageKey
    end

    for _, control in ipairs(normalized.refreshControls) do
        if type(control) == "table" and type(control.variable) == "string" and control.variable ~= "" then
            self.pageKeyByVariable[control.variable] = pageKey
        end
    end

    return normalized
end

function Registry:GetPageSpec(pageKey)
    return self.pageSpecs[pageKey]
end

function Registry:GetPageKeyForCategory(category)
    if not category or not category.GetID then
        return nil
    end
    return self.pageKeyByCategoryId[category:GetID()]
end

function Registry:GetPageKeyForSetting(setting)
    local variable = TryGetSettingVariable(setting)
    if not variable then
        return nil
    end
    return self.pageKeyByVariable[variable]
end

function Registry:GetOrderedPageSpecs()
    local out = {}
    for key, spec in pairs(self.pageSpecs) do
        out[#out + 1] = spec
    end
    table.sort(out, function(a, b)
        return tostring(a.pageKey) < tostring(b.pageKey)
    end)
    return out
end

function Registry:WriteDefault(path, rootScope)
    local sourceRoot = rootScope and addon.DEFAULTS or (addon.DEFAULTS and addon.DEFAULTS.profile)
    local targetRoot = rootScope and addon.db or (addon.db and addon.db.profile)
    if not sourceRoot or not targetRoot then
        return
    end
    SetPath(targetRoot, path, DeepCopy(GetPath(sourceRoot, path)))
end

function Registry:RefreshControl(controlSpec)
    if type(controlSpec) ~= "table" then return end
    local variable = controlSpec.variable
    if type(variable) ~= "string" or variable == "" then return end

    if controlSpec.type == "multidropdown" then
        local selection = controlSpec.selection
        if selection == nil and type(controlSpec.selectionFromPath) == "string" then
            selection = GetPath(addon.db and addon.db.profile, controlSpec.selectionFromPath)
        end
        if selection == nil and type(controlSpec.selectionGetter) == "function" then
            local ok, value = pcall(controlSpec.selectionGetter)
            if ok then
                selection = value
            end
        end
        addon.RefreshMultiDropdownSelection(variable, selection, {
            silent = true,
            serialized = SerializeSelection(selection),
        })
        return
    end

    local setting = Settings.GetSetting(variable)
    if not setting then return end

    local value = controlSpec.value
    if value == nil and type(controlSpec.valueFromPath) == "string" then
        value = GetPath(addon.db and addon.db.profile, controlSpec.valueFromPath)
    end
    if value == nil and type(controlSpec.valueFromRootPath) == "string" then
        value = GetPath(addon.db, controlSpec.valueFromRootPath)
    end
    if value == nil and controlSpec.valueFromSetting ~= false and setting.GetValue then
        value = setting:GetValue()
    end

    addon.RefreshSettingValue(variable, value, { silent = true })
end
