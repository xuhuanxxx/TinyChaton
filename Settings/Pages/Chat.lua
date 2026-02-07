local addonName, addon = ...
local L = addon.L
local def = addon.DEFAULTS and addon.DEFAULTS.plugin or {}

local CategoryBuilders = addon.CategoryBuilders or {}
addon.CategoryBuilders = CategoryBuilders

-- Helper: Create setting UI from registry
local function CreateSettingFromRegistry(subCat, key)
    local reg = addon.SETTING_REGISTRY[key]
    if not reg or not reg.ui then return end
    
    local P = "TinyChaton_"
    local variable = P .. key
    
    -- Unified accessors for Proxy settings
    local getter = function()
        if reg.getValue then 
            local val = reg.getValue()
            if val ~= nil then return val end
        end
        return reg.get()
    end
    
    local setter = function(v)
        if reg.setValue then reg.setValue(v) end
        if reg.set then reg.set(v) end
        if addon.ApplyAllSettings then addon:ApplyAllSettings() end
    end
    
    local defVal = (type(reg.default) == "function") and reg.default() or reg.default

    if reg.ui.type == "checkbox" then
        return addon.AddProxyCheckbox(subCat, variable, L[reg.ui.label], defVal, getter, setter, reg.ui.tooltip and L[reg.ui.tooltip] or nil)
    elseif reg.ui.type == "dropdown" then
        return addon.AddProxyDropdown(subCat, variable, L[reg.ui.label], defVal, reg.ui.options, getter, setter, reg.ui.tooltip and L[reg.ui.tooltip] or nil)
    elseif reg.ui.type == "slider" then
        return addon.AddProxySlider(subCat, variable, L[reg.ui.label], defVal, reg.ui.min, reg.ui.max, reg.ui.step, getter, setter, reg.ui.tooltip and L[reg.ui.tooltip] or nil)
    elseif reg.ui.type == "color" then
        return addon.AddNativeButton(subCat, L[reg.ui.label], L[reg.ui.label], function()
            local r,g,b,a = addon.Utils.ParseColorHex(getter())
            ColorPickerFrame:SetupColorPickerAndShow({ r=r, g=g, b=b, opacity=a, hasOpacity=true,
                swatchFunc = function() 
                    local cr,cg,cb,ca = ColorPickerFrame:GetColorRGB(), ColorPickerFrame:GetColorAlpha()
                    setter(addon.Utils.FormatColorHex(cr,cg,cb,ca))
                end
            })
        end)
    end
end

CategoryBuilders.chat = function(rootCat)
    local subCat, _ = Settings.RegisterVerticalLayoutSubcategory(rootCat, L["PAGE_CHAT"])
    Settings.RegisterAddOnCategory(subCat)
    local P = "TinyChaton_Chat_"

    addon.AddSectionHeader(subCat, L["SECTION_CHAT_FONT"])
    CreateSettingFromRegistry(subCat, "fontManaged")
    
    addon.AddNativeDropdown(subCat, P .. "font", L["LABEL_FONT"], "",
        function() local c = Settings.CreateControlTextContainer(); c:Add("", L["LABEL_DEFAULT"]); return c:GetData() end,
        function() return addon.db.plugin.chat.font.font or "" end,
        function(v) addon.db.plugin.chat.font.font = (v ~= "") and v or nil; if addon.ApplyChatFontSettings then addon:ApplyChatFontSettings() end end, nil)
    
    CreateSettingFromRegistry(subCat, "fontSize")
    CreateSettingFromRegistry(subCat, "fontOutline")

    addon.AddSectionHeader(subCat, L["SECTION_CHAT_CHANNEL"])
    CreateSettingFromRegistry(subCat, "channelNameFormat")

    addon.AddSectionHeader(subCat, L["SECTION_CHAT_CONTENT"])
    CreateSettingFromRegistry(subCat, "emoteRender")
    CreateSettingFromRegistry(subCat, "snapshotEnabled")

    addon.AddProxyMultiDropdown(subCat, P .. "snapshotPersonal",
        L["LABEL_SNAPSHOT_PERSONAL"] or "Personal",
        function() return addon:GetSnapshotChannelsItems("private") end,
        function() return addon:GetSnapshotChannelSelection("private") end,
        function(sel) addon:SetSnapshotChannelSelection("private", sel) end,
        L["TOOLTIP_SNAPSHOT_PERSONAL"] or "Select personal channels to snapshot")

    addon.AddProxyMultiDropdown(subCat, P .. "snapshotSystem",
        L["LABEL_SNAPSHOT_SYSTEM"] or "System",
        function() return addon:GetSnapshotChannelsItems("system") end,
        function() return addon:GetSnapshotChannelSelection("system") end,
        function(sel) addon:SetSnapshotChannelSelection("system", sel) end,
        L["TOOLTIP_SNAPSHOT_SYSTEM"] or "Select system channels to snapshot")

    addon.AddProxyMultiDropdown(subCat, P .. "snapshotDynamic",
        L["LABEL_SNAPSHOT_DYNAMIC"] or "Dynamic",
        function() return addon:GetSnapshotChannelsItems("dynamic") end,
        function() return addon:GetSnapshotChannelSelection("dynamic") end,
        function(sel) addon:SetSnapshotChannelSelection("dynamic", sel) end,
        L["TOOLTIP_SNAPSHOT_DYNAMIC"] or "Select dynamic channels to snapshot")

    addon.AddSectionHeader(subCat, L["SECTION_CHAT_INTERACTION"])
    CreateSettingFromRegistry(subCat, "timestampEnabled")
    CreateSettingFromRegistry(subCat, "timestampFormat")
    CreateSettingFromRegistry(subCat, "timestampColor")
    CreateSettingFromRegistry(subCat, "clickToCopy")
    CreateSettingFromRegistry(subCat, "linkHover")
    CreateSettingFromRegistry(subCat, "sticky")
    CreateSettingFromRegistry(subCat, "tabCycle")

    local function ResetChatData()
        addon.db.plugin.chat.content.snapshotChannels = addon.Utils.DeepCopy(def.chat.content.snapshotChannels)
        if addon.ApplyAllSettings then addon:ApplyAllSettings() end

        local settings = {
            Settings.GetSetting(P .. "snapshotPersonal"),
            Settings.GetSetting(P .. "snapshotSystem"),
            Settings.GetSetting(P .. "snapshotDynamic"),
        }
        for _, setting in ipairs(settings) do
            if setting and setting.SetValue and setting.GetValue then
                setting:SetValue(setting:GetValue())
            end
        end
    end
    
    addon.RegisterPageReset(subCat, ResetChatData)

    return subCat
end
