local addonName, addon = ...

--[[
Usage:
local ribbon = addon.CreateRibbon(
    parentFrame,
    {
        { label = "Tab1", key = "tab1" },
        { label = "Tab2", key = "tab2" },
    },
    {
        tabWidth = 120,
        tabHeight = 28,
        tabSpacing = 12,
        onTabChanged = function(index, tab) end
    }
)

local page = ribbon:CreateContentPage(1, parentFrame, {top=60, bottom=20, left=20, right=20})
ribbon:SetActiveTab(2)
]]

function addon.CreateRibbon(parent, tabsConfig, options)
    options = options or {}
    local tabWidth = options.tabWidth or 120
    local tabHeight = options.tabHeight or 28
    local tabSpacing = options.tabSpacing or 12
    local startX = options.startX or 20
    local startY = options.startY or -10
    
    local container = CreateFrame("Frame", nil, parent)
    container:SetPoint("TOPLEFT", parent, "TOPLEFT", startX, startY)
    container:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -startX, startY)
    container:SetHeight(tabHeight + 3)
    
    container.activeTabIndex = 1
    container.tabButtons = {}
    container.contentPages = {}
    container.onTabChanged = options.onTabChanged
    local COLOR_TEXT_ACTIVE = {1, 1, 1, 1}
    local COLOR_TEXT_INACTIVE = {1, 1, 1, 0.35}
    local COLOR_TEXT_HOVER = {0.7, 0.7, 0.7, 1}
    local COLOR_BG = {0, 0, 0, 0.4}
    local COLOR_BORDER = {0.25, 0.25, 0.25, 1}
    local COLOR_DIVIDER = {0.2, 0.2, 0.2, 1}
    local COLOR_INDICATOR = {1, 0.843, 0, 1}
    
    container.baseHeight = tabHeight
    container.activeHeight = tabHeight + 3
    container.inactiveHeight = tabHeight * 0.95

    for i, tab in ipairs(tabsConfig) do
        local btn = CreateFrame("Button", nil, container)
        btn:SetSize(tabWidth, container.inactiveHeight)

        if i == 1 then
            btn:SetPoint("BOTTOMLEFT", container, "BOTTOMLEFT", 0, 0)
        else
            btn:SetPoint("BOTTOMLEFT", container.tabButtons[i-1], "BOTTOMRIGHT", tabSpacing, 0)
        end

        btn.Bg = btn:CreateTexture(nil, "BACKGROUND")
        btn.Bg:SetAllPoints()
        btn.Bg:SetColorTexture(unpack(COLOR_BG))

        btn.Glow = btn:CreateTexture(nil, "BORDER")
        btn.Glow:SetAllPoints()
        btn.Glow:SetGradient("VERTICAL",
            CreateColor(0.4, 0.4, 0.4, 0.2),
            CreateColor(0.4, 0.4, 0.4, 0))
        btn.Glow:SetColorTexture(1, 1, 1, 1)
        btn.Glow:Hide()

        btn.BorderTop = btn:CreateTexture(nil, "BORDER")
        btn.BorderTop:SetHeight(1)
        btn.BorderTop:SetPoint("TOPLEFT", btn, "TOPLEFT", 0, 0)
        btn.BorderTop:SetPoint("TOPRIGHT", btn, "TOPRIGHT", 0, 0)
        btn.BorderTop:SetColorTexture(unpack(COLOR_BORDER))

        btn.BorderLeft = btn:CreateTexture(nil, "BORDER")
        btn.BorderLeft:SetWidth(1)
        btn.BorderLeft:SetPoint("TOPLEFT", btn, "TOPLEFT", 0, 0)
        btn.BorderLeft:SetPoint("BOTTOMLEFT", btn, "BOTTOMLEFT", 0, 1)
        btn.BorderLeft:SetColorTexture(unpack(COLOR_BORDER))

        btn.BorderRight = btn:CreateTexture(nil, "BORDER")
        btn.BorderRight:SetWidth(1)
        btn.BorderRight:SetPoint("TOPRIGHT", btn, "TOPRIGHT", 0, 0)
        btn.BorderRight:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", 0, 1)
        btn.BorderRight:SetColorTexture(unpack(COLOR_BORDER))

        if i < #tabsConfig then
            btn.VertDivider = btn:CreateTexture(nil, "ARTWORK")
            btn.VertDivider:SetWidth(1)
            btn.VertDivider:SetPoint("TOPRIGHT", btn, "TOPRIGHT", math.floor(tabSpacing/2), 0)
            btn.VertDivider:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", math.floor(tabSpacing/2), 0)
            btn.VertDivider:SetColorTexture(1, 1, 1, 0.1)
        end

        btn.Indicator = btn:CreateTexture(nil, "OVERLAY")
        btn.Indicator:SetHeight(2)
        btn.Indicator:SetPoint("BOTTOMLEFT", btn, "BOTTOMLEFT", 0, 0)
        btn.Indicator:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", 0, 0)
        btn.Indicator:SetColorTexture(unpack(COLOR_INDICATOR))
        btn.Indicator:Hide()

        btn.Text = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        btn.Text:SetPoint("CENTER", btn, "CENTER", 0, 0)
        btn.Text:SetText(tab.label)
        btn:SetScript("OnClick", function(self)
            container:SetActiveTab(self.tabIndex)
        end)

        btn:SetScript("OnEnter", function(self)
            if self.tabIndex ~= container.activeTabIndex then
                self.Text:SetTextColor(unpack(COLOR_TEXT_HOVER))
            end
        end)

        btn:SetScript("OnLeave", function(self)
            if self.tabIndex ~= container.activeTabIndex then
                self.Text:SetTextColor(unpack(COLOR_TEXT_INACTIVE))
            end
        end)

        btn.tabIndex = i
        table.insert(container.tabButtons, btn)
    end

    local bottomDivider = container:CreateTexture(nil, "ARTWORK")
    bottomDivider:SetHeight(1)
    bottomDivider:SetPoint("BOTTOMLEFT", container, "BOTTOMLEFT", 0, 0)
    bottomDivider:SetPoint("BOTTOMRIGHT", container, "BOTTOMRIGHT", 0, 0)
    bottomDivider:SetColorTexture(unpack(COLOR_DIVIDER))

    container.SetActiveTab = function(self, index)
        self.activeTabIndex = index
        
        for i, btn in ipairs(self.tabButtons) do
            if i == index then
                btn:SetAlpha(1.0)
                btn:EnableMouse(false)
                btn:SetHeight(self.activeHeight)
                btn.Glow:Show()
                btn.Indicator:Show()
                btn.Text:SetTextColor(unpack(COLOR_TEXT_ACTIVE))
                btn.Text:SetFontObject("GameFontHighlightSmall")
            else
                btn:SetAlpha(0.75)
                btn:EnableMouse(true)
                btn:SetHeight(self.inactiveHeight)
                btn.Glow:Hide()
                btn.Indicator:Hide()
                btn.Text:SetTextColor(unpack(COLOR_TEXT_INACTIVE))
                btn.Text:SetFontObject("GameFontNormalSmall")
            end
        end
        
        for i, page in ipairs(self.contentPages) do
            if page then
                page:SetShown(i == index)
            end
        end
        
        if self.onTabChanged then
            self.onTabChanged(index, tabsConfig[index])
        end
    end
    
    container.GetActiveTab = function(self)
        return self.activeTabIndex
    end

    container.CreateContentPage = function(self, index, parentFrame, inset)
        inset = inset or { top = 50, bottom = 20, left = 20, right = 20 }
        
        local page = CreateFrame("Frame", nil, parentFrame)
        page:SetPoint("TOPLEFT", parentFrame, "TOPLEFT", inset.left, -inset.top)
        page:SetPoint("BOTTOMRIGHT", parentFrame, "BOTTOMRIGHT", -inset.right, inset.bottom)
        page:Hide()
        
        self.contentPages[index] = page
        return page
    end
    
    container:SetActiveTab(1)
    return container
end
