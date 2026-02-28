local addonName, addon = ...
local L = addon.L

local function TrackRuntimeSetting(meta)
    if not meta or not meta.key then return end
    addon.RUNTIME_SETTING_REGISTRY = addon.RUNTIME_SETTING_REGISTRY or {}
    addon.RUNTIME_SETTING_REGISTRY[meta.key] = meta
end

function addon.ClearSettingsListHighlight(frame)
    if not frame then return end

    local function IsUserElement(f)
        if not f then return false end
        local name = f:GetName() or ""
        if name:find("^" .. addonName .. "_") then
            return true
        end
        return IsUserElement(f:GetParent())
    end

    local function ClearSettingsElement(f)
        if not f then return end
        if IsUserElement(f) then
            return
        end

        f:EnableMouse(false)
        f:SetScript("OnEnter", nil)
        f:SetScript("OnLeave", nil)

        local regions = {f:GetRegions()}
        for _, region in ipairs(regions) do
            if region:GetObjectType() == "Texture" then
                local name = region:GetName() or ""
                if name:find("Highlight") or name:find("Hover") or name:find("hover") then
                    region:SetAlpha(0)
                    region:Hide()
                end
            end
        end

        local children = {f:GetChildren()}
        for _, child in ipairs(children) do
            ClearSettingsElement(child)
        end
    end

    ClearSettingsElement(frame)
end

-- Static Popups

if not StaticPopupDialogs["TINYCHATON_HISTORY_CLEAR_CONFIRM"] then
    StaticPopupDialogs["TINYCHATON_HISTORY_CLEAR_CONFIRM"] = {
        text = L["ACTION_HISTORY_CLEAR_CONFIRM"],
        button1 = YES,
        button2 = NO,
        OnAccept = function()
            addon:ClearHistory()
        end,
        hideOnEscape = true,
    }
end

-- Dynamic Path Resolver
function addon.GetTableFromPath(path)
    if type(path) ~= "string" then return nil end

    local current = addon.db
    for part in string.gmatch(path, "([^%.]+)") do
        if current and type(current) == "table" then
            current = current[part]
        else
            return nil
        end
    end
    return current
end


function addon.EnsureTableFromPath(path)
    if type(path) ~= "string" then return nil end

    local current = addon.db
    for part in string.gmatch(path, "([^%.]+)") do
        if not current[part] then
            current[part] = {}
        end
        current = current[part]
        if type(current) ~= "table" then
            return nil  -- Path exists but is not a table
        end
    end
    return current
end

-- Standard Vertical Layout Helpers

function addon.AddText(cat, text)
    local init = Settings.CreateElementInitializer("SettingsListSectionHeaderTemplate", { name = text })
    Settings.RegisterInitializer(cat, init)
end

function addon.AddSectionHeader(cat, text)
    local init = Settings.CreateElementInitializer("SettingsListSectionHeaderTemplate", { name = text })
    Settings.RegisterInitializer(cat, init)
end

function addon.AddAddOnCheckbox(cat, variable, tbl, key, name, default, tooltip, applyFunc)
    if not tbl then return nil end

    local targetTbl = type(tbl) == "string" and addon.EnsureTableFromPath(tbl) or tbl
    if not targetTbl or type(targetTbl) ~= "table" then return nil end

    local setting = Settings.GetSetting(variable)
    if not setting then
        local defVal = default and Settings.Default.True or Settings.Default.False
        setting = Settings.RegisterAddOnSetting(cat, variable, key, targetTbl, Settings.VarType.Boolean, name, defVal)
    end

    if setting then
        if setting.SetValueChangedCallback then
            setting:SetValueChangedCallback(function()
                if applyFunc then applyFunc() else addon:ApplyAllSettings() end
            end)
        end
        Settings.CreateCheckbox(cat, setting, tooltip)
    end
    return setting
end

function addon.AddAddOnDropdown(cat, variable, tbl, key, name, optionsFunc, default, tooltip, valueChangedCallback, applyFunc)
    if not tbl then return nil end

    local targetTbl = type(tbl) == "string" and addon.EnsureTableFromPath(tbl) or tbl
    if not targetTbl or type(targetTbl) ~= "table" then return nil end

    local setting = Settings.GetSetting(variable)
    if not setting then
        local varType = type(default) == "number" and Settings.VarType.Number or Settings.VarType.String
        setting = Settings.RegisterAddOnSetting(cat, variable, key, targetTbl, varType, name, default)
    end

    if setting then
        if setting.SetValueChangedCallback then
            setting:SetValueChangedCallback(function(_, value)
                if not valueChangedCallback then
                    if applyFunc then applyFunc() else addon:ApplyAllSettings() end
                end
                if valueChangedCallback then valueChangedCallback(value) end
            end)
        end
        Settings.CreateDropdown(cat, setting, optionsFunc, tooltip)
    end
    return setting
end

function addon.AddAddOnSlider(cat, variable, tbl, key, name, default, minVal, maxVal, step, tooltip, applyFunc)
    if not tbl then return nil end

    local targetTbl = type(tbl) == "string" and addon.EnsureTableFromPath(tbl) or tbl
    if not targetTbl or type(targetTbl) ~= "table" then return nil end

    local setting = Settings.GetSetting(variable)
    if not setting then
        setting = Settings.RegisterAddOnSetting(cat, variable, key, targetTbl, Settings.VarType.Number, name, default)
    end

    if setting then
        if setting.SetValueChangedCallback then
            setting:SetValueChangedCallback(function()
                if applyFunc then applyFunc() else addon:ApplyAllSettings() end
            end)
        end
        local options = Settings.CreateSliderOptions(minVal, maxVal, step)
        options:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right, function(value)
            if step < 1 then
                return string.format("%.1f", value)
            else
                return string.format("%d", value)
            end
        end)

        local dynamicTooltip = function()
            local val = (tbl and tbl[key]) or default
            local valStr = (step < 1) and string.format("%.1f", val) or string.format("%d", val)
            if tooltip then
                return string.format("%s\n\n%s: %s", tooltip, L["LABEL_VALUE"], valStr)
            else
                return string.format("%s: %s", L["LABEL_VALUE"], valStr)
            end
        end

        Settings.CreateSlider(cat, setting, options, dynamicTooltip)
    end
end

function addon.AddNativeCheckbox(cat, variable, name, default, getter, setter, tooltip)
    local existingSetting = Settings.GetSetting(variable)
    if existingSetting then
        return existingSetting
    end

    local setting = Settings.RegisterProxySetting(cat, variable, Settings.VarType.Boolean, name, default, getter, setter)
    Settings.CreateCheckbox(cat, setting, tooltip)
    TrackRuntimeSetting({
        key = variable,
        scope = "profile",
        valueType = "boolean",
        default = default,
        accessor = { get = getter, set = setter },
    })

    return setting
end

function addon.AddNativeSlider(cat, variable, name, default, minVal, maxVal, step, getter, setter, tooltip)
    local existingSetting = Settings.GetSetting(variable)
    if existingSetting then
        return existingSetting
    end

    local setting = Settings.RegisterProxySetting(cat, variable, Settings.VarType.Number, name, default, getter, setter)
    local options = Settings.CreateSliderOptions(minVal, maxVal, step)
    options:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right, function(value)
        if step < 1 then
            return string.format("%.1f", value)
        else
            return string.format("%d", value)
        end
    end)

    local dynamicTooltip = function()
        local val = getter()
        local valStr = (step < 1) and string.format("%.1f", val) or string.format("%d", val)
        if tooltip then
            return string.format("%s\n\n%s: %s", tooltip, L["LABEL_VALUE"], valStr)
        else
            return string.format("%s: %s", L["LABEL_VALUE"], valStr)
        end
    end

    Settings.CreateSlider(cat, setting, options, dynamicTooltip)
    TrackRuntimeSetting({
        key = variable,
        scope = "profile",
        valueType = "number",
        default = default,
        ui = { type = "slider", min = minVal, max = maxVal, step = step },
        accessor = { get = getter, set = setter },
    })

    return setting
end

function addon.AddNativeDropdown(cat, variable, name, default, optionsFunc, getter, setter, tooltip)
    local varType = (type(default) == "number") and Settings.VarType.Number or Settings.VarType.String
    local setting = Settings.GetSetting(variable)
    if not setting then
        setting = Settings.RegisterProxySetting(cat, variable, varType, name, default, getter, setter)
    end
    if setting then
        Settings.CreateDropdown(cat, setting, optionsFunc, tooltip)
    end
    TrackRuntimeSetting({
        key = variable,
        scope = "profile",
        valueType = (type(default) == "number") and "number" or "string",
        default = default,
        ui = { type = "dropdown", options = optionsFunc },
        accessor = { get = getter, set = setter },
    })
    return setting
end

-- Proxy Registration Helpers

function addon.AddProxyCheckbox(cat, variable, name, default, getter, setter, tooltip)
    local setting = Settings.GetSetting(variable)
    if not setting then
        setting = Settings.RegisterProxySetting(cat, variable, Settings.VarType.Boolean, name, default, getter, setter)
    end
    if setting then
        Settings.CreateCheckbox(cat, setting, tooltip)
    end
    TrackRuntimeSetting({
        key = variable,
        scope = "profile",
        valueType = "boolean",
        default = default,
        accessor = { get = getter, set = setter },
    })
    return setting
end

function addon.AddProxySlider(cat, variable, name, default, minVal, maxVal, step, getter, setter, tooltip)
    local setting = Settings.GetSetting(variable)
    if not setting then
        setting = Settings.RegisterProxySetting(cat, variable, Settings.VarType.Number, name, default, getter, setter)
    end
    if setting then
        local options = Settings.CreateSliderOptions(minVal, maxVal, step)
        options:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right, function(value)
            return (step < 1) and string.format("%.1f", value) or string.format("%d", value)
        end)
        Settings.CreateSlider(cat, setting, options, function()
            local val = getter()
            local valStr = (step < 1) and string.format("%.1f", val) or string.format("%d", val)
            return tooltip and (tooltip .. "\n\n" .. L["LABEL_VALUE"] .. ": " .. valStr) or (L["LABEL_VALUE"] .. ": " .. valStr)
        end)
    end
    TrackRuntimeSetting({
        key = variable,
        scope = "profile",
        valueType = "number",
        default = default,
        ui = { type = "slider", min = minVal, max = maxVal, step = step },
        accessor = { get = getter, set = setter },
    })
    return setting
end

function addon.AddProxyDropdown(cat, variable, name, default, optionsFunc, getter, setter, tooltip)
    local varType = (type(default) == "number") and Settings.VarType.Number or Settings.VarType.String
    local setting = Settings.GetSetting(variable)
    if not setting then
        setting = Settings.RegisterProxySetting(cat, variable, varType, name, default, getter, setter)
    end
    if setting then
        Settings.CreateDropdown(cat, setting, optionsFunc, tooltip)
    end
    TrackRuntimeSetting({
        key = variable,
        scope = "profile",
        valueType = (type(default) == "number") and "number" or "string",
        default = default,
        ui = { type = "dropdown", options = optionsFunc },
        accessor = { get = getter, set = setter },
    })
    return setting
end

local function ResolvePathContext(reg)
    if not reg or type(reg.pathContext) ~= "function" then
        return {}
    end
    local ok, ctx = pcall(reg.pathContext)
    if ok and type(ctx) == "table" then
        return ctx
    end
    return {}
end

local function ResolvePath(path, ctx)
    if not addon.Utils or type(addon.Utils.ResolveTemplatePath) ~= "function" then
        return path
    end
    local resolved = addon.Utils.ResolveTemplatePath(path, ctx)
    if type(addon.Utils.ValidatePath) == "function" then
        local ok = addon.Utils.ValidatePath(resolved)
        if not ok then
            return nil
        end
    end
    return resolved
end

local function BuildPathAccessor(reg)
    local function getter()
        local ctx = ResolvePathContext(reg)
        local path = ResolvePath(reg.path, ctx)
        if not path then
            return nil
        end
        return addon.Utils.GetByPath(addon.db, path)
    end

    local function setter(value)
        local ctx = ResolvePathContext(reg)
        local path = ResolvePath(reg.path, ctx)
        if not path then
            return
        end
        local ensureTablePath = reg.ensureTablePath
        if ensureTablePath == nil then
            ensureTablePath = true
        end

        if ensureTablePath then
            addon.Utils.SetByPath(addon.db, path, value)
            return
        end

        local parts = {}
        for part in path:gmatch("[^%.]+") do
            parts[#parts + 1] = part
        end
        if #parts == 0 then
            return
        end
        local parentPath = table.concat(parts, ".", 1, #parts - 1)
        local parent = (#parts == 1) and addon.db or addon.Utils.GetByPath(addon.db, parentPath)
        if type(parent) == "table" then
            parent[parts[#parts]] = value
        end
    end

    return {
        get = getter,
        set = setter,
    }
end

local function BuildRegistrySetter(reg, rawSetter)
    return function(v)
        local ctx = ResolvePathContext(reg)
        local value = v

        if reg and type(reg.normalizeSet) == "function" then
            local ok, normalized = pcall(reg.normalizeSet, value, ctx)
            if ok then
                value = normalized
            end
        end

        if rawSetter then
            rawSetter(value)
        end

        if reg and type(reg.onChange) == "function" then
            pcall(reg.onChange, value, ctx)
        end

        if (not reg) or reg.applyAllSettings ~= false then
            if addon.ApplyAllSettings then
                addon:ApplyAllSettings()
            end
        end
    end
end

local function ResolveRegistryDefault(reg, fallback)
    if reg and type(reg.default) == "function" then
        local ok, value = pcall(reg.default)
        if ok then
            return value
        end
    elseif reg and reg.default ~= nil then
        return reg.default
    end
    return fallback
end

local function ResolveRegistryValue(reg, rawGetter, ctx, fallbackDefault)
    local value = rawGetter and rawGetter() or nil
    if reg and type(reg.normalizeGet) == "function" then
        local ok, normalized = pcall(reg.normalizeGet, value, ctx)
        if ok then
            return normalized
        end
    end
    if value == nil then
        return ResolveRegistryDefault(reg, fallbackDefault)
    end
    return value
end

addon.SettingsRegistryInternals = addon.SettingsRegistryInternals or {}
addon.SettingsRegistryInternals.ResolvePathContext = ResolvePathContext
addon.SettingsRegistryInternals.ResolvePath = ResolvePath
addon.SettingsRegistryInternals.BuildPathAccessor = BuildPathAccessor
addon.SettingsRegistryInternals.BuildRegistrySetter = BuildRegistrySetter
addon.SettingsRegistryInternals.ResolveRegistryDefault = ResolveRegistryDefault
addon.SettingsRegistryInternals.ResolveRegistryValue = ResolveRegistryValue

function addon.AddRegistrySetting(cat, key)
    local reg = addon.SETTING_REGISTRY and addon.SETTING_REGISTRY[key]
    if not reg or not reg.ui then return nil end

    local variable = "TinyChaton_" .. key
    local defVal = (type(reg.default) == "function") and reg.default() or reg.default
    local accessor = reg.accessor or {}
    local getter = accessor.get or reg.getValue or reg.get
    local rawSetter = accessor.set or reg.setValue or reg.set

    if (not getter or not rawSetter) and type(reg.path) == "string" then
        local pathAccessor = BuildPathAccessor(reg)
        getter = getter or pathAccessor.get
        rawSetter = rawSetter or pathAccessor.set
    end

    if getter then
        local rawGetter = getter
        getter = function()
            local ctx = ResolvePathContext(reg)
            return ResolveRegistryValue(reg, rawGetter, ctx, defVal)
        end
    end
    if not getter then
        getter = function()
            return ResolveRegistryDefault(reg, defVal)
        end
    end

    rawSetter = rawSetter or function() end
    local setter = BuildRegistrySetter(reg, rawSetter)
    local label = reg.ui.label and L[reg.ui.label] or key
    local tooltip = reg.ui.tooltip and L[reg.ui.tooltip] or nil

    if reg.ui.type == "checkbox" then
        return addon.AddProxyCheckbox(cat, variable, label, defVal, getter, setter, tooltip)
    elseif reg.ui.type == "dropdown" then
        return addon.AddProxyDropdown(cat, variable, label, defVal, reg.ui.options, getter, setter, tooltip)
    elseif reg.ui.type == "slider" then
        return addon.AddProxySlider(cat, variable, label, defVal, reg.ui.min, reg.ui.max, reg.ui.step, getter, setter, tooltip)
    end

    return nil
end

-- MultiDropdown Helper

function addon.AddProxyMultiDropdown(cat, variable, name, optionfunc, getter, setter, tooltip, summaryFunc)
    local setting = Settings.GetSetting(variable)
    if not setting then
        local function serializeGetter()
            local sel = getter()
            if type(sel) ~= "table" then return "" end
            local keys = {}
            for k, v in pairs(sel) do
                if v then table.insert(keys, k) end
            end
            table.sort(keys)
            return table.concat(keys, ",")
        end

        local function deserializeSetter(value)
            local selection = {}
            if type(value) == "string" and value ~= "" then
                for key in value:gmatch("([^,]+)") do
                    selection[key] = true
                end
            end
            if setter then
                setter(selection)
            end
        end

        setting = Settings.RegisterProxySetting(cat, variable, Settings.VarType.String, name, "", serializeGetter, deserializeSetter)
    end

    local data = {
        name = name,
        var = variable,
        optionfunc = optionfunc,
        getSelection = getter,
        setSelection = setter,
        tooltip = tooltip,
        summaryFunc = summaryFunc,
        hideSummary = true,
        setting = setting,
        GetSetting = function() return setting end,
    }

    local init = Settings.CreateElementInitializer("TinyChaton_MultiDropdownTemplate", data)

    init.GetName = function() return name end
    init.GetTooltip = function() return tooltip end
    init.GetSetting = function() return setting end
    init.GetData = function() return data end

    Settings.RegisterInitializer(cat, init)
    TrackRuntimeSetting({
        key = variable,
        scope = "profile",
        valueType = "table",
        default = "",
        accessor = { get = getter, set = setter },
        ui = { type = "multi_dropdown" },
    })

    return setting
end

function addon.AddNativeButton(cat, label, buttonText, onClick, tooltip, visibilityPredicate)
    if CreateSettingsButtonInitializer then
        local btn = CreateSettingsButtonInitializer(label, buttonText, onClick, tooltip, false)
        if visibilityPredicate then
            btn:AddVisibilityPredicate(visibilityPredicate)
        end
        SettingsPanel:GetLayout(cat):AddInitializer(btn)
        return btn
    end
end

-- Page Reset Registration Helper
function addon.RegisterPageReset(category, callback)
    if not category or not callback then return end

    local variable = "TinyChaton_ResetTrigger_" .. category:GetID()

    local setting = Settings.GetSetting(variable)
    if not setting then
        setting = Settings.RegisterProxySetting(category, variable, Settings.VarType.Number,
            "Reset Trigger", 0,
            function() return 1 end,
            function(v)
                if v == 0 then
                    callback()
                end
            end
        )
    end
end
