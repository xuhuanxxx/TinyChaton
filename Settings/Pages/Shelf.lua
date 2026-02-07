local addonName, addon = ...
local L = addon.L
local def = addon.DEFAULTS and addon.DEFAULTS.plugin or {}

local CategoryBuilders = addon.CategoryBuilders or {}
addon.CategoryBuilders = CategoryBuilders

CategoryBuilders.shelf = function(rootCat)
    -- This page is now the "Content Management" page, formerly Modules.lua
    local cat, layout = Settings.RegisterVerticalLayoutSubcategory(rootCat, L["PAGE_SHELF"])
    Settings.RegisterAddOnCategory(cat)
    local P = "TinyChaton_Shelf_Content_"
    
    local shelfOrder = addon.Shelf:GetOrder()
    local shelfDB = addon.db.plugin.shelf
    local shelfDef = def.shelf
    
    local function GetCP() return shelfDB.channelPins or {} end
    local function GetKP() return shelfDB.kitPins or {} end

    local registryMap = {}
    for _, item in ipairs(addon.CHANNEL_REGISTRY) do registryMap[item.key] = item end

    local kitRegistryMap = {}
    for _, spec in ipairs(addon.KIT_REGISTRY) do kitRegistryMap[spec.key] = spec end

    local function IsKeyEnabled(key)
        local item = registryMap[key]
        if item then return GetCP()[key] ~= false end
        local kp = GetKP()
        local dbValue = kp[key]
        if dbValue ~= nil then return dbValue == true end
        local defValue = shelfDef and shelfDef.kitPins and shelfDef.kitPins[key]
        return defValue == true
    end

    local function GetKeyIndex(key)
        for i, k in ipairs(shelfOrder) do
            if k == key then return i end
        end
        return 0
    end

    local function GetPrevEnabledIndex(idx)
        for i = idx - 1, 1, -1 do
            if IsKeyEnabled(shelfOrder[i]) then return i end
        end
        return nil
    end

    local function GetNextEnabledIndex(idx)
        for i = idx + 1, #shelfOrder do
            if IsKeyEnabled(shelfOrder[i]) then return i end
        end
        return nil
    end

    local function MoveInShelfOrder(key, delta)
        local idx = GetKeyIndex(key)
        if idx == 0 then return end

        local targetIdx = (delta < 0) and GetPrevEnabledIndex(idx) or GetNextEnabledIndex(idx)
        if targetIdx then
            shelfOrder[idx], shelfOrder[targetIdx] = shelfOrder[targetIdx], shelfOrder[idx]
            shelfDB.shelfOrder = addon.Utils.DeepCopy(shelfOrder)
            addon:RefreshShelf()
        end
    end


    local previewInit = Settings.CreateElementInitializer("SettingsListElementTemplate", { name = "" })
    previewInit.GetExtent = function() return 80 end
    previewInit.InitFrame = function(self, frame)
        if not frame.cbrHandles then frame.cbrHandles = Settings.CreateCallbackHandleContainer() end
        addon.ClearSettingsListHighlight(frame)

        if not frame[addonName .. "_Shelf_Preview"] then
            frame[addonName .. "_Shelf_Preview"] = CreateFrame("Frame", addonName .. "_Shelf_PreviewContainer", frame)
            frame[addonName .. "_Shelf_Preview"]:SetPoint("CENTER")
            frame[addonName .. "_Shelf_Preview"]:SetSize(500, 60)

            frame:HookScript("OnHide", function()
                if frame[addonName .. "_Shelf_Preview"] then frame[addonName .. "_Shelf_Preview"]:Hide() end
            end)
        end
        addon.shelfPreviewContainer = frame[addonName .. "_Shelf_Preview"]
        addon.shelfPreviewContainer:Show()
        if addon.RefreshShelfPreview then addon.RefreshShelfPreview() end
    end
    Settings.RegisterInitializer(cat, previewInit)

    addon.RefreshShelfPreview = function()
        local container = addon.shelfPreviewContainer
        if not container or not container:IsVisible() then return end
        
        local TR = _G.TinyReactor
        if not TR or not TR.Reconciler then return end
        
        local visibleItems = addon.Shelf and addon.Shelf:GetVisibleItems() or {}
        local currentTheme = addon:GetShelfThemeProperties(shelfDB.theme or "Modern")
        
        local previewButtonSize = 30
        local previewSpacing = 2
        
        local elements = {}
        local totalWidth = (#visibleItems * previewButtonSize) + ((#visibleItems - 1) * previewSpacing)
        local startX = (container:GetWidth() - totalWidth) / 2
        
        for i, info in ipairs(visibleItems) do
            table.insert(elements, addon.ShelfButton:Create({
                key = info.key, text = info.text, item = info.item, size = previewButtonSize, theme = currentTheme,
                point = {"LEFT", container, "LEFT", startX + (i-1)*(previewButtonSize+previewSpacing), 0},
            }))
        end
        TR.Reconciler:Render(container, elements)
    end


    local function OpenBindingMenu(owner, channelKey, buttonType)
        local bindings = shelfDB.bindings
        if not bindings[channelKey] then bindings[channelKey] = {} end
        
        local function SetBinding(actionKey)
            bindings[channelKey][buttonType] = actionKey
            if not bindings[channelKey].left and not bindings[channelKey].right then bindings[channelKey] = nil end
            addon:ApplyAllSettings()
            if addon.RefreshShelf then addon:RefreshShelf() end
            if addon.RefreshShelfPreview then addon.RefreshShelfPreview() end
        end
        
        MenuUtil.CreateContextMenu(owner, function(owner, rootDescription)
            rootDescription:CreateTitle(buttonType == "left" and L["LABEL_BINDING_LEFT"] or L["LABEL_BINDING_RIGHT"])
            rootDescription:CreateButton(L["LABEL_DEFAULT"], function() SetBinding(nil) end)
            rootDescription:CreateButton(L["LABEL_NONE"], function() SetBinding(false) end)
            rootDescription:CreateDivider()

            local sortedActions = {}
            for key, action in pairs(addon.ACTION_REGISTRY or {}) do table.insert(sortedActions, action) end
            table.sort(sortedActions, function(a, b) return (a.label or "") < (b.label or "") end)
            
            for _, action in ipairs(sortedActions) do
                local function IsSelected() return bindings[channelKey] and bindings[channelKey][buttonType] == action.key end
                rootDescription:CreateRadio(action.label or action.key, IsSelected, function() SetBinding(action.key) end)
            end
        end)
    end


    if not addon.shelfTabState then addon.shelfTabState = { activeTab = 1 } end

    local ribbonInit = Settings.CreateElementInitializer("SettingsListElementTemplate", { name = "" })
    ribbonInit.GetExtent = function() return 420 end
    ribbonInit.InitFrame = function(self, frame)
        if not frame.cbrHandles then frame.cbrHandles = Settings.CreateCallbackHandleContainer() end
        frame:SetSize(580, 420)
        addon.ClearSettingsListHighlight(frame)

        if not frame[addonName .. "_Shelf_RibbonContainer"] then
            local container = CreateFrame("Frame", addonName .. "_Shelf_RibbonContainerFrame", frame)
            container:SetAllPoints()
            frame[addonName .. "_Shelf_RibbonContainer"] = container

            local ribbonTabs = {
                { label = L["LABEL_MODULES_TAB_SYSTEM"], key = "system" },
                { label = L["LABEL_MODULES_TAB_DYNAMIC"], key = "dynamic" },
                { label = L["LABEL_MODULES_TAB_KITS"], key = "kit" },
            }

            local ribbon = addon.CreateRibbon(container, ribbonTabs, {
                tabWidth = 110, tabHeight = 28, tabSpacing = 12, startX = 0, startY = -10,
                onTabChanged = function(index) addon.shelfTabState.activeTab = index end
            })
            container.ribbon = ribbon

            local function CreateRow(parent, i, item, typeKey)
                local row = CreateFrame("Frame", nil, parent)
                row:SetSize(520, 32)
                
                row.cb = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate")
                row.cb:SetSize(24, 24); row.cb:SetPoint("LEFT", 0, 0)
                
                local isEnabled = typeKey == "kit" and (GetKP()[item.key] ~= false) or (GetCP()[item.key] ~= false)
                row.cb:SetChecked(isEnabled)
                row.cb:SetScript("OnClick", function(self)
                    local list = typeKey == "kit" and shelfDB.kitPins or shelfDB.channelPins
                    list[item.key] = self:GetChecked()
                    addon:ApplyAllSettings()
                    if addon.RefreshShelf then addon:RefreshShelf() end
                    if addon.RefreshShelfPreview then addon.RefreshShelfPreview() end
                end)

                row.label = row:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
                row.label:SetPoint("LEFT", row.cb, "RIGHT", 6, 0); row.label:SetText(item.label or item.key)

                local function CreateBindBtn(text, pos, btnType)
                    local btn = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
                    btn:SetSize(40, 22); btn:SetPoint("RIGHT", row, "RIGHT", pos, 0); btn:SetText(text)
                    btn:SetScript("OnClick", function(self) OpenBindingMenu(self, item.key, btnType) end)
                    return btn
                end
                CreateBindBtn(L["LABEL_LEFT"], -120, "left")
                CreateBindBtn(L["LABEL_RIGHT"], -75, "right")

                local upBtn = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
                upBtn:SetSize(28, 22); upBtn:SetPoint("RIGHT", -40, 0); upBtn:SetText("▲")
                upBtn:SetScript("OnClick", function() MoveInShelfOrder(item.key, -1); addon.RefreshShelfList() end)
                
                local downBtn = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
                downBtn:SetSize(28, 22); downBtn:SetPoint("RIGHT", -6, 0); downBtn:SetText("▼")
                downBtn:SetScript("OnClick", function() MoveInShelfOrder(item.key, 1); addon.RefreshShelfList() end)

                row.Refresh = function()
                    local id = item.key
                    local isEnabled = typeKey == "kit" and (GetKP()[id] ~= false) or (GetCP()[id] ~= false)
                    row.cb:SetChecked(isEnabled)

                    local idx = GetKeyIndex(item.key)
                    upBtn:SetEnabled(idx > 1 and GetPrevEnabledIndex(idx) ~= nil)
                    downBtn:SetEnabled(idx > 0 and idx < #shelfOrder and GetNextEnabledIndex(idx) ~= nil)
                end
                return row
            end

            local function SetupPage(idx, filterFunc, typeKey)
                local page = ribbon:CreateContentPage(idx, container, { top = 60, bottom = 20, left = 0, right = 20 })
                page.items = {}
                for _, reg in ipairs(typeKey == "kit" and addon.KIT_REGISTRY or addon.CHANNEL_REGISTRY) do
                    if filterFunc(reg) then table.insert(page.items, reg) end
                end
                table.sort(page.items, function(a, b) return (a.order or 0) < (b.order or 0) end)
                
                page.rows = {}
                page.Refresh = function()
                    for i, item in ipairs(page.items) do
                        if not page.rows[i] then page.rows[i] = CreateRow(page, i, item, typeKey) end
                        page.rows[i]:SetPoint("TOPLEFT", 0, -(i-1)*32 - 10)
                        page.rows[i].Refresh()
                    end
                end
                return page
            end

            local p1 = SetupPage(1, function(r) return r.isSystem and not r.isSystemMsg and not r.isNotStorable end, "channel")
            local p2 = SetupPage(2, function(r) return r.isDynamic end, "channel")
            local p3 = SetupPage(3, function(r) return true end, "kit")

            addon.RefreshShelfList = function() 
                p1.Refresh(); p2.Refresh(); p3.Refresh() 
                if addon.RefreshShelfPreview then addon.RefreshShelfPreview() end
            end
            container.RestoreState = function() ribbon:SetActiveTab(addon.shelfTabState.activeTab or 1); addon.RefreshShelfList() end
            frame:HookScript("OnHide", function() container:Hide() end)
        end

        frame[addonName .. "_Shelf_RibbonContainer"]:Show()
        if frame[addonName .. "_Shelf_RibbonContainer"].RestoreState then frame[addonName .. "_Shelf_RibbonContainer"].RestoreState() end
    end
    Settings.RegisterInitializer(cat, ribbonInit)


    addon.AddSectionHeader(cat, L["KIT_COUNTDOWN"])
    local P_CD = "TinyChaton_Shelf_Countdown_"
    local cdDB = shelfDB.kitOptions.countdown
    local cdDef = shelfDef.kitOptions.countdown
    addon.AddAddOnSlider(cat, P_CD .. "Primary", cdDB, "primary", L["ACTION_TIMER_PRIMARY"], cdDef.primary, 3, 60, 1, L["ACTION_TIMER_PRIMARY_DESC"])
    addon.AddAddOnSlider(cat, P_CD .. "Secondary", cdDB, "secondary", L["ACTION_TIMER_SECONDARY"], cdDef.secondary, 3, 60, 1, L["ACTION_TIMER_SECONDARY_DESC"])


    local function ResetShelfData()
        shelfDB.channelPins = addon.Utils.DeepCopy(def.shelf.channelPins)
        shelfDB.kitPins = addon.Utils.DeepCopy(def.shelf.kitPins)
        shelfDB.shelfOrder = nil
        shelfDB.bindings = {}
        shelfDB.kitOptions = addon.Utils.DeepCopy(def.shelf.kitOptions)

        addon:ApplyAllSettings()
        addon:RefreshShelf()

        if addon.RefreshShelfList then addon.RefreshShelfList() end
    end
    
    addon.RegisterPageReset(cat, ResetShelfData)

    return cat
end
