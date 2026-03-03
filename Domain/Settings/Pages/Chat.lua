local addonName, addon = ...
local L = addon.L
local def = addon.DEFAULTS and addon.DEFAULTS.profile or {}

local CategoryBuilders = addon.CategoryBuilders or {}
addon.CategoryBuilders = CategoryBuilders

-- Helper: Create setting UI from registry
local function CreateSettingFromRegistry(subCat, key)
    local reg = addon.SETTING_REGISTRY[key]
    if not reg or not reg.ui then return end

    if reg.ui.type ~= "color" then
        return addon.AddRegistrySetting(subCat, key)
    end

    local getter = reg.getValue or reg.get
    local setter = reg.setValue or reg.set
    return addon.AddNativeButton(subCat, L[reg.ui.label], L[reg.ui.label], function()
        local r,g,b,a = addon.Utils.ParseColorHex(getter())
        ColorPickerFrame:SetupColorPickerAndShow({ r=r, g=g, b=b, opacity=a, hasOpacity=true,
            swatchFunc = function()
                local cr, cg, cb = ColorPickerFrame:GetColorRGB()
                local ca = ColorPickerFrame:GetColorAlpha()
                setter(addon.Utils.FormatColorHex(cr,cg,cb,ca))
                if addon.ApplyAllSettings then addon:ApplyAllSettings() end
            end
        })
    end)
end

CategoryBuilders.chat = function(rootCat)
    local subCat, _ = Settings.RegisterVerticalLayoutSubcategory(rootCat, L["PAGE_CHAT"])
    Settings.RegisterAddOnCategory(subCat)
    local P = "TinyChaton_Chat_"
    local function GetChatFontDB()
        local profile = addon.db and addon.db.profile
        return profile and profile.chat and profile.chat.font
    end

    local function GetChatContentDB()
        local profile = addon.db and addon.db.profile
        return profile and profile.chat and profile.chat.content
    end

    addon.AddSectionHeader(subCat, L["SECTION_CHAT_FONT"])
    CreateSettingFromRegistry(subCat, "fontManaged")

    addon.AddProxyDropdown(subCat, P .. "font", L["LABEL_FONT"], addon.CONSTANTS.CHAT_DEFAULT_FONT,
        function()
            local c = Settings.CreateControlTextContainer()
            c:Add("STANDARD", L["FONT_STANDARD"])
            c:Add("CHAT", L["FONT_CHAT"])
            c:Add("DAMAGE", L["FONT_DAMAGE"])

            local db = GetChatFontDB()
            local val = db and db.font
            if val and val ~= "STANDARD" and val ~= "CHAT" and val ~= "DAMAGE" and val ~= "" then
                 local name = L["LABEL_CUSTOM"] .. " (" .. (val:match("([^\\]+)$") or val) .. ")"
                 c:Add(val, name)
            end
            return c:GetData()
        end,
        function()
            local db = GetChatFontDB()
            local val = db and db.font
            if val == "CHAT" or val == "DAMAGE" then return val end
            if val and val ~= "" and val ~= "STANDARD" then return val end
            return "STANDARD"
        end,
        function(v)
            local db = GetChatFontDB()
            if db then db.font = (v ~= "STANDARD") and v or nil end
            if addon.ApplyChatFontSettings then addon:ApplyChatFontSettings() end
        end, nil)

    CreateSettingFromRegistry(subCat, "fontSize")
    CreateSettingFromRegistry(subCat, "fontOutline")

    addon.AddSectionHeader(subCat, L["SECTION_DISPLAY_CHAT_CHANNEL"])
    CreateSettingFromRegistry(subCat, "chatDisplayChannelShowNumber")
    CreateSettingFromRegistry(subCat, "chatDisplayChannelNameStyle")

    addon.AddSectionHeader(subCat, L["SECTION_CHAT_CONTENT"])
    CreateSettingFromRegistry(subCat, "emoteRender")
    addon.AddProxyCheckbox(subCat, P .. "repeatFilter", L["LABEL_REPEAT_FILTER"], false,
        function()
            local db = GetChatContentDB()
            return db and db.repeatFilter
        end,
        function(v)
            local db = GetChatContentDB()
            if db then db.repeatFilter = v end
            if addon.ApplyAllSettings then addon:ApplyAllSettings() end
        end,
        L["LABEL_REPEAT_FILTER_DESC"])
    CreateSettingFromRegistry(subCat, "snapshotEnabled")

    addon.AddProxyMultiDropdown(subCat, P .. "snapshotPersonal",
        L["LABEL_SNAPSHOT_PERSONAL"],
        function() return addon:GetSnapshotChannelsItems("private") end,
        function() return addon:GetSnapshotChannelSelection("private") end,
        function(sel) addon:SetSnapshotChannelSelection("private", sel) end,
        L["TOOLTIP_SNAPSHOT_PERSONAL"])

    addon.AddProxyMultiDropdown(subCat, P .. "snapshotSystem",
        L["LABEL_SNAPSHOT_SYSTEM"],
        function() return addon:GetSnapshotChannelsItems("system") end,
        function() return addon:GetSnapshotChannelSelection("system") end,
        function(sel) addon:SetSnapshotChannelSelection("system", sel) end,
        L["TOOLTIP_SNAPSHOT_SYSTEM"])

    addon.AddProxyMultiDropdown(subCat, P .. "snapshotDynamic",
        L["LABEL_SNAPSHOT_DYNAMIC"],
        function() return addon:GetSnapshotChannelsItems("dynamic") end,
        function() return addon:GetSnapshotChannelSelection("dynamic") end,
        function(sel) addon:SetSnapshotChannelSelection("dynamic", sel) end,
        L["TOOLTIP_SNAPSHOT_DYNAMIC"])
    addon.AddProxyMultiDropdown(subCat, P .. "snapshotNotice",
        L["LABEL_SNAPSHOT_NOTICE"],
        function() return addon:GetSnapshotChannelsItems("notice") end,
        function() return addon:GetSnapshotChannelSelection("notice") end,
        function(sel) addon:SetSnapshotChannelSelection("notice", sel) end,
        L["TOOLTIP_SNAPSHOT_NOTICE"])


    addon.AddSectionHeader(subCat, L["SECTION_CHAT_INTERACTION"])

    CreateSettingFromRegistry(subCat, "timestampEnabled")
    CreateSettingFromRegistry(subCat, "timestampFormat")
    CreateSettingFromRegistry(subCat, "timestampColor")
    CreateSettingFromRegistry(subCat, "clickToCopy")
    addon.AddProxyMultiDropdown(subCat, P .. "copyPersonal",
        L["LABEL_COPY_PERSONAL"],
        function() return addon:GetCopyChannelsItems("private") end,
        function() return addon:GetCopyChannelSelection("private") end,
        function(sel) addon:SetCopyChannelSelection("private", sel) end,
        L["TOOLTIP_COPY_PERSONAL"])
    addon.AddProxyMultiDropdown(subCat, P .. "copySystem",
        L["LABEL_COPY_SYSTEM"],
        function() return addon:GetCopyChannelsItems("system") end,
        function() return addon:GetCopyChannelSelection("system") end,
        function(sel) addon:SetCopyChannelSelection("system", sel) end,
        L["TOOLTIP_COPY_SYSTEM"])
    addon.AddProxyMultiDropdown(subCat, P .. "copyDynamic",
        L["LABEL_COPY_DYNAMIC"],
        function() return addon:GetCopyChannelsItems("dynamic") end,
        function() return addon:GetCopyChannelSelection("dynamic") end,
        function(sel) addon:SetCopyChannelSelection("dynamic", sel) end,
        L["TOOLTIP_COPY_DYNAMIC"])
    addon.AddProxyMultiDropdown(subCat, P .. "copyNotice",
        L["LABEL_COPY_NOTICE"],
        function() return addon:GetCopyChannelsItems("notice") end,
        function() return addon:GetCopyChannelSelection("notice") end,
        function(sel) addon:SetCopyChannelSelection("notice", sel) end,
        L["TOOLTIP_COPY_NOTICE"])
    CreateSettingFromRegistry(subCat, "linkHover")
    CreateSettingFromRegistry(subCat, "sticky")
    CreateSettingFromRegistry(subCat, "tabCycle")

    addon.SettingsReset:RegisterPageSpec("chat", {
        category = subCat,
        writeDefaults = {
            "chat.content.snapshotChannels",
            "chat.interaction.copyChannels",
        },
        refreshControls = {
            { type = "multidropdown", variable = P .. "snapshotPersonal", selectionFromPath = "chat.content.snapshotChannels" },
            { type = "multidropdown", variable = P .. "snapshotSystem", selectionFromPath = "chat.content.snapshotChannels" },
            { type = "multidropdown", variable = P .. "snapshotDynamic", selectionFromPath = "chat.content.snapshotChannels" },
            { type = "multidropdown", variable = P .. "snapshotNotice", selectionFromPath = "chat.content.snapshotChannels" },
            { type = "multidropdown", variable = P .. "copyPersonal", selectionFromPath = "chat.interaction.copyChannels" },
            { type = "multidropdown", variable = P .. "copySystem", selectionFromPath = "chat.interaction.copyChannels" },
            { type = "multidropdown", variable = P .. "copyDynamic", selectionFromPath = "chat.interaction.copyChannels" },
            { type = "multidropdown", variable = P .. "copyNotice", selectionFromPath = "chat.interaction.copyChannels" },
        },
    })

    addon.RegisterPageReset(subCat, "chat")

    return subCat
end
