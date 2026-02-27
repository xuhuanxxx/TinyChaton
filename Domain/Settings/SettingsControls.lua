local addonName, addon = ...
local L = addon.L

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
    return setting
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

-- Deprecated: Use addon.UI.ShowEditor instead
function addon.ShowEditor(title, dbTable, dbKey, hint, validateFunc)
    return addon.UI.ShowEditor(title, dbTable, dbKey, hint, validateFunc)
end

-- Deprecated: Use addon.UI.CanvasStyle
addon.CanvasStyle = addon.UI.CanvasStyle

-- Deprecated: Use addon.UI.CreateCanvas
function addon.CreateCanvasLayout(parentFrame, opts)
    return addon.UI.CreateCanvas(parentFrame, opts)
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
