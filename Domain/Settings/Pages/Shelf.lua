local addonName, addon = ...
local CF = _G["Create" .. "Frame"]
local L = addon.L
local def = addon.DEFAULTS and addon.DEFAULTS.plugin or {}

local CategoryBuilders = addon.CategoryBuilders or {}
addon.CategoryBuilders = CategoryBuilders

CategoryBuilders.shelf = function(rootCat)
    local cat, layout = Settings.RegisterVerticalLayoutSubcategory(rootCat, L["PAGE_SHELF"])
    Settings.RegisterAddOnCategory(cat)
    local P = "TinyChaton_Shelf_Content_"

    local shelfOrder = addon.Shelf:GetOrder()
    local shelfPath = "plugin.shelf"
    local function GetShelfDB() return addon.GetTableFromPath(shelfPath) end
    local shelfDef = def.shelf

    local function GetCP() local db = GetShelfDB(); return db and db.channelPins or {} end
    local function GetKP() local db = GetShelfDB(); return db and db.kitPins or {} end

    local registryMap = {}
    local kitRegistryMap = {}

    for _, stream, catKey, subKey in addon:IterateAllStreams() do
        registryMap[stream.key] = stream
    end
    for _, spec in ipairs(addon.KIT_REGISTRY or {}) do
        kitRegistryMap[spec.key] = spec
    end

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
            local db = GetShelfDB()
            if db then db.shelfOrder = addon.Utils.DeepCopy(shelfOrder) end
            addon:RefreshShelf()
        end
    end


    local previewInit = Settings.CreateElementInitializer("SettingsListElementTemplate", { name = "" })
    previewInit.GetExtent = function() return 80 end
    previewInit.InitFrame = function(self, frame)
        if not frame.cbrHandles then frame.cbrHandles = Settings.CreateCallbackHandleContainer() end
        addon.ClearSettingsListHighlight(frame)

        if not frame[addonName .. "_Shelf_Preview"] then
            frame[addonName .. "_Shelf_Preview"] = CF("Frame", addonName .. "_Shelf_PreviewContainer", frame)
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
        local db = GetShelfDB()
        local currentTheme = addon:GetShelfThemeProperties((db and db.theme) or "Modern")

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


    local bindingDialog = nil
    local function OpenBindingDialog(channelKey, buttonType)
        local db = GetShelfDB()
        if not db then return end
        local bindings = db.bindings
        if not bindings then db.bindings = {}; bindings = db.bindings end
        if not bindings[channelKey] then bindings[channelKey] = {} end

        local currentAction = bindings[channelKey][buttonType]

        -- Build items list for dialog
        local items = {}

        -- table.insert(items, { key = nil, label = L["LABEL_DEFAULT"] or "Default", category = "other" })
        -- table.insert(items, { key = false, label = L["LABEL_NONE"] or "None", category = "other" })

        local sortedActions = {}
        for key, action in pairs(addon.ACTION_REGISTRY or {}) do table.insert(sortedActions, action) end

        for _, action in ipairs(sortedActions) do
            table.insert(items, {
                key = action.key,
                label = action.label,
                tooltip = action.tooltip,
                category = action.category
            })
        end

        if not bindingDialog then
            bindingDialog = addon.CreateSelectionRibbon(addonName .. "BindingSelectionDialog", UIParent)
        end

        -- Resolve Title
        local item = registryMap[channelKey] or kitRegistryMap[channelKey]
        local title = item and (item.label or item.key) or channelKey
        if item and item.mappingKey and L[item.mappingKey] then
             title = L[item.mappingKey]
        end

        bindingDialog:Open(items, currentAction, title, function(selectedKey)
            bindings[channelKey][buttonType] = selectedKey

            addon:ApplyAllSettings()
            if addon.RefreshShelf then addon:RefreshShelf() end
            if addon.RefreshShelfPreview then addon.RefreshShelfPreview() end
            if addon.RefreshShelfList then addon.RefreshShelfList() end
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
            local container = CF("Frame", addonName .. "_Shelf_RibbonContainerFrame", frame)
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
                local row = CF("Frame", nil, parent)
                row:SetSize(520, 32)

                row.cb = CF("CheckButton", nil, row, "UICheckButtonTemplate")
                row.cb:SetSize(24, 24); row.cb:SetPoint("LEFT", 0, 0)

                local isEnabled = typeKey == "kit" and (GetKP()[item.key] ~= false) or (GetCP()[item.key] ~= false)
                row.cb:SetChecked(isEnabled)
                row.cb:SetScript("OnClick", function(self)
                    local db = GetShelfDB()
                    if not db then return end
                    if not db.kitPins then db.kitPins = {} end
                    if not db.channelPins then db.channelPins = {} end
                    local list = typeKey == "kit" and db.kitPins or db.channelPins
                    list[item.key] = self:GetChecked()
                    addon:ApplyAllSettings()
                    if addon.RefreshShelf then addon:RefreshShelf() end
                    if addon.RefreshShelfPreview then addon.RefreshShelfPreview() end
                end)

                row.label = row:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
                row.label:SetPoint("LEFT", row.cb, "RIGHT", 6, 0); row.label:SetText(item.label or item.key)

                -- Layout Constants
                local RIGHT_MARGIN = -5
                local BTN_SPACING = 4
                local MOVE_BTN_WIDTH = 24

                -- Move Buttons (Right Side)
                local downBtn = CF("Button", nil, row, "UIPanelButtonTemplate")
                downBtn:SetSize(MOVE_BTN_WIDTH, 22)
                downBtn:SetPoint("RIGHT", RIGHT_MARGIN, 0)
                downBtn:SetText("▼")
                downBtn:SetScript("OnClick", function() MoveInShelfOrder(item.key, 1); addon.RefreshShelfList() end)

                local upBtn = CF("Button", nil, row, "UIPanelButtonTemplate")
                upBtn:SetSize(MOVE_BTN_WIDTH, 22)
                upBtn:SetPoint("RIGHT", downBtn, "LEFT", -BTN_SPACING, 0)
                upBtn:SetText("▲")
                upBtn:SetScript("OnClick", function() MoveInShelfOrder(item.key, -1); addon.RefreshShelfList() end)

                -- Action Buttons & Labels
                -- Layout: [Left Btn]  [Right Btn] ... [Up] [Down]

                local ACTION_BTN_WIDTH = 150
                local BTN_GAP = 4

                -- Right Action
                local rightBtn = CF("Button", nil, row, "UIPanelButtonTemplate")
                rightBtn:SetSize(ACTION_BTN_WIDTH, 22)
                rightBtn:SetPoint("RIGHT", upBtn, "LEFT", -15, 0) -- Gap after move buttons
                rightBtn:SetScript("OnClick", function(self) OpenBindingDialog(item.key, "right") end)

                -- Left Action
                local leftBtn = CF("Button", nil, row, "UIPanelButtonTemplate")
                leftBtn:SetSize(ACTION_BTN_WIDTH, 22)
                leftBtn:SetPoint("RIGHT", rightBtn, "LEFT", -BTN_GAP, 0) -- Gap between Right Btn and Left Btn
                leftBtn:SetScript("OnClick", function(self) OpenBindingDialog(item.key, "left") end)

                -- Update Text Logic
                local function UpdateButtonText(btn, btnType)
                    -- Use Shelf:GetItemConfig to resolve the EFFECTIVE action (handling defaults)
                    local config = addon.Shelf:GetItemConfig(item.key)
                    local actionKey = config and ((btnType == "left" and config.leftClick) or (btnType == "right" and config.rightClick))

                    local text = L["LABEL_NONE"]

                    if actionKey then
                        if actionKey == false then
                            text = L["LABEL_NONE"]
                        else
                            local action = addon.ACTION_REGISTRY and addon.ACTION_REGISTRY[actionKey]
                            text = action and action.label or actionKey
                        end
                    end

                    -- Truncate removed to avoid UTF-8 issues.
                    -- if #text > 16 then text = string.sub(text, 1, 14) .. "..." end
                    btn:SetText(text)
                end

                row.Refresh = function()
                    local id = item.key
                    local isEnabled = typeKey == "kit" and (GetKP()[id] ~= false) or (GetCP()[id] ~= false)
                    row.cb:SetChecked(isEnabled)

                    local idx = GetKeyIndex(item.key)
                    upBtn:SetEnabled(idx > 1 and GetPrevEnabledIndex(idx) ~= nil)
                    downBtn:SetEnabled(idx > 0 and idx < #shelfOrder and GetNextEnabledIndex(idx) ~= nil)

                    UpdateButtonText(leftBtn, "left")
                    UpdateButtonText(rightBtn, "right")
                end

                return row
            end

            local function SetupPage(idx, filterFunc, typeKey)
                local page = ribbon:CreateContentPage(idx, container, { top = 60, bottom = 20, left = 0, right = 20 })
                page.items = {}

                if typeKey == "kit" then
                    for _, reg in ipairs(addon.KIT_REGISTRY or {}) do
                        if filterFunc(reg) then table.insert(page.items, reg) end
                    end
                else
                    for _, stream, catKey, subKey in addon:IterateAllStreams() do
                        if filterFunc(stream, catKey, subKey) then
                            table.insert(page.items, stream)
                        end
                    end
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

            local p1 = SetupPage(1, function(stream, catKey, subKey)
                return catKey == "CHANNEL" and subKey == "SYSTEM" and not stream.isSystemMsg and not stream.isNotStorable
            end, "channel")
            local p2 = SetupPage(2, function(stream, catKey, subKey)
                return catKey == "CHANNEL" and subKey == "DYNAMIC"
            end, "channel")
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
    local cdPath = "plugin.shelf.kitOptions.countdown"
    local cdDef = shelfDef.kitOptions.countdown

    local function GetCdVal(key)
        local db = addon.GetTableFromPath(cdPath)
        return db and db[key]
    end

    local function SetCdVal(key, value)
        local db = addon.GetTableFromPath(cdPath)
        if db then db[key] = value end
    end

    addon.AddProxySlider(cat, P_CD .. "Primary", L["ACTION_TIMER_PRIMARY"], cdDef.primary, 3, 60, 1,
        function() return GetCdVal("primary") end,
        function(v) SetCdVal("primary", v) end,
        L["ACTION_TIMER_PRIMARY_DESC"])

    addon.AddProxySlider(cat, P_CD .. "Secondary", L["ACTION_TIMER_SECONDARY"], cdDef.secondary, 3, 60, 1,
        function() return GetCdVal("secondary") end,
        function(v) SetCdVal("secondary", v) end,
        L["ACTION_TIMER_SECONDARY_DESC"])


    local function ResetShelfData()
        local db = GetShelfDB()
        if not db then return end
        db.channelPins = addon.Utils.DeepCopy(def.shelf.channelPins)
        db.kitPins = addon.Utils.DeepCopy(def.shelf.kitPins)
        db.shelfOrder = nil
        db.bindings = {}
        db.kitOptions = addon.Utils.DeepCopy(def.shelf.kitOptions)

        addon:ApplyAllSettings()
        addon:RefreshShelf()

        if addon.RefreshShelfList then addon.RefreshShelfList() end
    end

    addon.RegisterPageReset(cat, ResetShelfData)

    return cat
end
