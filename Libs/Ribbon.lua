local addonName, addon = ...

local function Clamp(v, lo, hi)
    if v < lo then return lo end
    if v > hi then return hi end
    return v
end

local function ApplyTabStyle(tab)
    if tab.disabled then
        tab.Left:Show()
        tab.Middle:Show()
        tab.Right:Show()
        tab.LeftActive:Hide()
        tab.MiddleActive:Hide()
        tab.RightActive:Hide()
        tab:Disable()
        tab:SetDisabledFontObject(GameFontDisableSmall)
        tab.Text:ClearAllPoints()
        tab.Text:SetPoint("LEFT", tab, "LEFT", 14, tab.deselectedTextY or -3)
        tab.Text:SetPoint("RIGHT", tab, "RIGHT", -12, tab.deselectedTextY or -3)
        return
    end

    if tab.selected then
        tab.Left:Hide()
        tab.Middle:Hide()
        tab.Right:Hide()
        tab.LeftActive:Show()
        tab.MiddleActive:Show()
        tab.RightActive:Show()
        tab:Disable()
        tab:SetDisabledFontObject(GameFontHighlightSmall)
        tab.Text:ClearAllPoints()
        tab.Text:SetPoint("LEFT", tab, "LEFT", 14, tab.selectedTextY or -3)
        tab.Text:SetPoint("RIGHT", tab, "RIGHT", -12, tab.selectedTextY or -3)
        return
    end

    tab.Left:Show()
    tab.Middle:Show()
    tab.Right:Show()
    tab.LeftActive:Hide()
    tab.MiddleActive:Hide()
    tab.RightActive:Hide()
    tab:Enable()
    tab.Text:ClearAllPoints()
    tab.Text:SetPoint("LEFT", tab, "LEFT", 14, tab.deselectedTextY or -3)
    tab.Text:SetPoint("RIGHT", tab, "RIGHT", -12, tab.deselectedTextY or -3)
end

local function SetTabWidth(tab, width)
    local middleWidth = width - 40
    if middleWidth < 1 then middleWidth = 1 end

    tab.Middle:SetWidth(middleWidth)
    tab.MiddleActive:SetWidth(middleWidth)

    tab:SetWidth(middleWidth + 40)

    if tab.HighlightTexture then
        tab.HighlightTexture:SetWidth(tab:GetWidth())
    end
end

local function CreateTabButton(container, tabConfig, layout)
    local tab = CreateFrame("Button", nil, container)
    tab:SetHeight(layout.height)

    tab.id = tabConfig.id
    tab.config = tabConfig
    tab.label = tabConfig.label or tostring(tabConfig.id or "")
    tab.disabled = tabConfig.disabled == true
    tab.selected = false
    tab.deselectedTextY = -3
    local activeHeightBoost = layout.activeTabHeightBoost or 3
    local activeTextLiftRatio = layout.activeTextLiftRatio or 0.4
    local activeTextLiftPx = math.max(1, math.floor((activeHeightBoost * activeTextLiftRatio) + 0.5))
    tab.selectedTextY = tab.deselectedTextY + activeTextLiftPx

    tab.Left = tab:CreateTexture(nil, "BORDER")
    tab.Left:SetTexture("Interface\\OptionsFrame\\UI-OptionsFrame-InActiveTab")
    tab.Left:SetWidth(20)
    tab.Left:SetPoint("TOPLEFT", tab, "TOPLEFT", 0, 0)
    tab.Left:SetPoint("BOTTOMLEFT", tab, "BOTTOMLEFT", 0, 0)
    tab.Left:SetTexCoord(0, 0.15625, 0, 1)

    tab.Middle = tab:CreateTexture(nil, "BORDER")
    tab.Middle:SetTexture("Interface\\OptionsFrame\\UI-OptionsFrame-InActiveTab")
    tab.Middle:SetPoint("TOPLEFT", tab.Left, "TOPRIGHT")
    tab.Middle:SetPoint("BOTTOMLEFT", tab.Left, "BOTTOMRIGHT")
    tab.Middle:SetTexCoord(0.15625, 0.84375, 0, 1)

    tab.Right = tab:CreateTexture(nil, "BORDER")
    tab.Right:SetTexture("Interface\\OptionsFrame\\UI-OptionsFrame-InActiveTab")
    tab.Right:SetWidth(20)
    tab.Right:SetPoint("TOPLEFT", tab.Middle, "TOPRIGHT")
    tab.Right:SetPoint("BOTTOMLEFT", tab.Middle, "BOTTOMRIGHT")
    tab.Right:SetTexCoord(0.84375, 1, 0, 1)

    tab.LeftActive = tab:CreateTexture(nil, "BORDER")
    tab.LeftActive:SetTexture("Interface\\OptionsFrame\\UI-OptionsFrame-ActiveTab")
    tab.LeftActive:SetWidth(20)
    tab.LeftActive:SetPoint("TOPLEFT", tab, "TOPLEFT", 0, 0)
    tab.LeftActive:SetPoint("BOTTOMLEFT", tab, "BOTTOMLEFT", 0, 0)
    tab.LeftActive:SetTexCoord(0, 0.15625, 0, 1)
    tab.LeftActive:Hide()

    tab.MiddleActive = tab:CreateTexture(nil, "BORDER")
    tab.MiddleActive:SetTexture("Interface\\OptionsFrame\\UI-OptionsFrame-ActiveTab")
    tab.MiddleActive:SetPoint("TOPLEFT", tab.LeftActive, "TOPRIGHT")
    tab.MiddleActive:SetPoint("BOTTOMLEFT", tab.LeftActive, "BOTTOMRIGHT")
    tab.MiddleActive:SetTexCoord(0.15625, 0.84375, 0, 1)
    tab.MiddleActive:Hide()

    tab.RightActive = tab:CreateTexture(nil, "BORDER")
    tab.RightActive:SetTexture("Interface\\OptionsFrame\\UI-OptionsFrame-ActiveTab")
    tab.RightActive:SetWidth(20)
    tab.RightActive:SetPoint("TOPLEFT", tab.MiddleActive, "TOPRIGHT")
    tab.RightActive:SetPoint("BOTTOMLEFT", tab.MiddleActive, "BOTTOMRIGHT")
    tab.RightActive:SetTexCoord(0.84375, 1, 0, 1)
    tab.RightActive:Hide()

    tab.Text = tab:CreateFontString(nil, "OVERLAY")
    tab:SetFontString(tab.Text)
    tab:SetNormalFontObject(GameFontNormalSmall)
    tab:SetHighlightFontObject(GameFontHighlightSmall)
    tab:SetDisabledFontObject(GameFontHighlightSmall)
    tab:SetText(tab.label)
    tab.Text:SetWordWrap(false)
    tab.Text:ClearAllPoints()
    tab.Text:SetPoint("LEFT", tab, "LEFT", 14, tab.deselectedTextY)
    tab.Text:SetPoint("RIGHT", tab, "RIGHT", -12, tab.deselectedTextY)

    tab:SetHighlightTexture("Interface\\PaperDollInfoFrame\\UI-Character-Tab-Highlight", "ADD")
    tab.HighlightTexture = tab:GetHighlightTexture()
    if tab.HighlightTexture then
        tab.HighlightTexture:ClearAllPoints()
        tab.HighlightTexture:SetPoint("LEFT", tab, "LEFT", 10, -4)
        tab.HighlightTexture:SetPoint("RIGHT", tab, "RIGHT", -10, -4)
    end

    local textWidth = tab:GetFontString():GetStringWidth()
    local totalWidth = Clamp(textWidth + 64, layout.minTabWidth, layout.maxTabWidth)
    SetTabWidth(tab, totalWidth)

    tab:SetScript("OnClick", function(self)
        container:SelectTabById(self.id, true)
    end)

    ApplyTabStyle(tab)
    return tab
end

function addon.CreateRibbon(parent, config)
    config = config or {}

    local tabs = config.tabs or {}
    local layoutConfig = config.layout or {}
    local behaviorConfig = config.behavior or {}
    local contentConfig = config.content or {}

    local layout = {
        startX = layoutConfig.startX or 0,
        startY = layoutConfig.startY or -10,
        spacing = layoutConfig.spacing or -10,
        minTabWidth = layoutConfig.minTabWidth or 60,
        maxTabWidth = layoutConfig.maxTabWidth or 150,
        height = layoutConfig.height or 24,
        activeTabHeightBoost = layoutConfig.activeTabHeightBoost or 3,
        activeTextLiftRatio = layoutConfig.activeTextLiftRatio or 0.4,
    }

    local behavior = {
        defaultTabId = behaviorConfig.defaultTabId,
        playClickSound = behaviorConfig.playClickSound ~= false,
        onTabChanged = behaviorConfig.onTabChanged,
    }

    local defaultInset = contentConfig.pageInset or { top = 50, bottom = 20, left = 20, right = 20 }

    local container = CreateFrame("Frame", nil, parent)
    container:SetPoint("TOPLEFT", parent, "TOPLEFT", layout.startX, layout.startY)
    container:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -layout.startX, layout.startY)
    container:SetHeight(layout.height + 3)

    container.tabButtons = {}
    container.tabsById = {}
    container.contentPages = {}
    container.activeTabId = nil

    local bottomDivider = container:CreateTexture(nil, "ARTWORK")
    bottomDivider:SetHeight(1)
    bottomDivider:SetPoint("BOTTOMLEFT", container, "BOTTOMLEFT", 0, 0)
    bottomDivider:SetPoint("BOTTOMRIGHT", container, "BOTTOMRIGHT", 0, 0)
    bottomDivider:SetColorTexture(0.2, 0.2, 0.2, 1)

    local function UpdatePages()
        for tabId, page in pairs(container.contentPages) do
            page:SetShown(tabId == container.activeTabId)
        end
    end

    local function ResolveDefaultTabId()
        if behavior.defaultTabId and container.tabsById[behavior.defaultTabId] and not container.tabsById[behavior.defaultTabId].disabled then
            return behavior.defaultTabId
        end
        for _, button in ipairs(container.tabButtons) do
            if not button.disabled then
                return button.id
            end
        end
        return nil
    end

    function container:SelectTabById(tabId, fromClick)
        local target = self.tabsById[tabId]
        if not target or target.disabled then
            return false
        end
        if self.activeTabId == tabId then
            return false
        end

        if fromClick and behavior.playClickSound then
            PlaySound(841)
        end

        self.activeTabId = tabId
        for _, button in ipairs(self.tabButtons) do
            button.selected = (button.id == tabId)
            ApplyTabStyle(button)
        end
        UpdatePages()

        if behavior.onTabChanged then
            behavior.onTabChanged(tabId, target.config or target)
        end
        return true
    end

    function container:GetActiveTabId()
        return self.activeTabId
    end

    function container:SetTabDisabled(tabId, disabled)
        local tab = self.tabsById[tabId]
        if not tab then return end
        tab.disabled = disabled == true
        if tab.disabled and self.activeTabId == tabId then
            self.activeTabId = nil
        end
        ApplyTabStyle(tab)
        if not self.activeTabId then
            local fallback = ResolveDefaultTabId()
            if fallback then
                self:SelectTabById(fallback, false)
            else
                UpdatePages()
            end
        end
    end

    function container:CreatePage(tabId, parentFrame, inset)
        if not self.tabsById[tabId] then
            return nil
        end

        local pageInset = inset or defaultInset
        local page = CreateFrame("Frame", nil, parentFrame)
        page:SetPoint("TOPLEFT", parentFrame, "TOPLEFT", pageInset.left, -pageInset.top)
        page:SetPoint("BOTTOMRIGHT", parentFrame, "BOTTOMRIGHT", -pageInset.right, pageInset.bottom)
        page:Hide()

        self.contentPages[tabId] = page
        if self.activeTabId == tabId then
            page:Show()
        end
        return page
    end

    for i, tabConfig in ipairs(tabs) do
        if tabConfig and tabConfig.id then
            local button = CreateTabButton(container, tabConfig, layout)
            table.insert(container.tabButtons, button)
            container.tabsById[button.id] = button
            if i == 1 then
                button:SetPoint("BOTTOMLEFT", container, "BOTTOMLEFT", 0, 0)
            else
                button:SetPoint("LEFT", container.tabButtons[i - 1], "RIGHT", layout.spacing, 0)
            end
        end
    end

    local defaultTabId = ResolveDefaultTabId()
    if defaultTabId then
        container:SelectTabById(defaultTabId, false)
    end

    return container
end
