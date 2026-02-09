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

--[[
    Selection Ribbon Dialog
    Replaces the old SelectionDialog.
    Usage:
    local dialog = addon.CreateSelectionRibbon("MySelectionDialog", UIParent)
    dialog:Open(items, selectedKey, callback)
]]
function addon.CreateSelectionRibbon(name, parent)
    -- User requested "DialogBorderDarkTemplate" for high-res look.
    -- We MUST use ClearAllPoints() because this template likely defaults to full screen anchors.
    local f = CreateFrame("Frame", name, parent, "DialogBorderDarkTemplate")
    f:ClearAllPoints()
    f:SetSize(350, 400)
    f:SetPoint("CENTER")
    f:SetFrameStrata("DIALOG")
    f:EnableMouse(true)
    f:SetMovable(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    f:Hide()

    table.insert(UISpecialFrames, f:GetName())

    -- Title Header (Native Style)
    -- Use the native DialogHeaderTemplate which handles the 3-part texture automatically
    f.Header = CreateFrame("Frame", nil, f, "DialogHeaderTemplate")
    f.Header:SetPoint("TOP", 0, 12)
    -- Ensure it sits above the dialog border
    f.Header:SetFrameLevel(f:GetFrameLevel() + 5)

    -- Alias for compatibility so existing code can change text
    -- DialogHeaderTemplate puts the fontstring in .Text (Capitalized)
    f.Title = f.Header.Text

    -- Safe fallback if .Text isn't directly accessible (varies by version sometimes?)
    if not f.Title then
        for _, region in ipairs({f.Header:GetRegions()}) do
            if region:GetObjectType() == "FontString" then
                f.Title = region
                break
            end
        end
    end

    -- Sync initial text
    if f.Title then f.Title:SetText("Selection") end

    -- Clean up old TitleContainer if it existed (from previous attempts)
    if f.TitleContainer then f.TitleContainer:Hide() end

    -- Close Button
    if not f.CloseButton then
        f.CloseButton = CreateFrame("Button", nil, f, "UIPanelCloseButton")
        f.CloseButton:SetSize(24, 24)
        f.CloseButton:SetPoint("TOPRIGHT", -5, -5)
    else
        f.CloseButton:SetPoint("TOPRIGHT", -5, -5)
        f.CloseButton:SetFrameLevel(f:GetFrameLevel() + 10)
    end

    -- Fixed Categories for now
    local CATEGORY_ORDER = { "channel", "join", "leave", "kit" }

    -- Compact Labels
    local L = addon.L
    local COMPACT_LABELS = {
        channel = "发言",
        join = "进入",
        leave = "退出",
        kit = "工具",
    }
    if GetLocale() ~= "zhCN" then
        COMPACT_LABELS = {
            channel = "Say",
            join = "Join",
            leave = "Leave",
            kit = "Tools",
        }
    end

    local ribbonTabs = {}
    for i, cat in ipairs(CATEGORY_ORDER) do
        table.insert(ribbonTabs, { label = COMPACT_LABELS[cat] or cat, key = cat })
    end

    -- Dynamic Layout: Anchor Ribbon below Header
    f.ribbon = addon.CreateRibbon(f, ribbonTabs, {
        tabWidth = 80,
        tabHeight = 24,
        tabSpacing = 2,
        startX = 10,
        startY = 0, -- Overridden below
        onTabChanged = function() end
    })

    -- Manually re-anchor ribbon to be relative to Header
    f.ribbon:ClearAllPoints()
    f.ribbon:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -40) -- Fallback if no header
    if f.Header then
        f.ribbon:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -32) -- Adjust based on header visual
    end
    f.ribbon:SetPoint("TOPRIGHT", f, "TOPRIGHT", -10, -32)

    -- Pre-create pages with ScrollFrames
    f.pages = {}
    for i, cat in ipairs(CATEGORY_ORDER) do
        -- Dynamic Layout: Anchor Content below Ribbon
        -- We ignore the 'top' inset from CreateContentPage and re-anchor manually
        local pageContainer = f.ribbon:CreateContentPage(i, f, { top = 0, bottom = 40, left = 10, right = 10 })

        pageContainer:ClearAllPoints()
        pageContainer:SetPoint("TOPLEFT", f.ribbon, "BOTTOMLEFT", 0, -5) -- 5px gap below tabs
        pageContainer:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -10, 40) -- 40px bottom for buttons

        local scroll = CreateFrame("ScrollFrame", nil, pageContainer, "UIPanelScrollFrameTemplate")
        scroll:SetPoint("TOPLEFT", 0, 0)
        scroll:SetPoint("BOTTOMRIGHT", -26, 0)

        local child = CreateFrame("Frame")
        child:SetSize(460, 1) -- Estimated width
        scroll:SetScrollChild(child)

        f.pages[cat] = { container = pageContainer, scroll = scroll, child = child, buttons = {} }
    end

    -- Bottom Buttons
    -- Bottom Buttons
    f.DefaultButton = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    f.DefaultButton:SetSize(100, 22)
    f.DefaultButton:SetPoint("BOTTOMRIGHT", -20, 10) -- Swapped to Right
    f.DefaultButton:SetText(L["LABEL_DEFAULT"])
    f.DefaultButton:SetScript("OnClick", function()
        if f.callback then f.callback(nil) end
        f:Hide()
    end)

    f.ClearButton = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    f.ClearButton:SetSize(100, 22)
    f.ClearButton:SetPoint("BOTTOMLEFT", 20, 10) -- Swapped to Left
    f.ClearButton:SetText(L["LABEL_NONE"])
    f.ClearButton:SetScript("OnClick", function()
        if f.callback then f.callback(false) end
        f:Hide()
    end)

    -- ESC Handling
    f:EnableKeyboard(true)
    f:SetScript("OnKeyDown", function(self, key)
        if key == "ESCAPE" then
            self:SetPropagateKeyboardInput(false)
            self:Hide()
        else
            self:SetPropagateKeyboardInput(true)
        end
    end)


    function f:Open(items, selectedKey, title, callback)
        f.callback = callback
        f.selectedKey = selectedKey
        f.Title:SetText(title or addon.L["LABEL_SELECT_ACTION"])

        -- Distribute items
        local categorized = {}
        for _, cat in ipairs(CATEGORY_ORDER) do categorized[cat] = {} end

        local defaultCat = "channel"
        local selectedCat = "channel"

        for _, item in ipairs(items) do
            -- Filter out special items (nil/false) as they are now handled by buttons
            if item.key ~= nil and item.key ~= false then
                local c = item.category or "other"
                if not categorized[c] then c = "other" end -- Fallback
                table.insert(categorized[c], item)

                if item.key == selectedKey then selectedCat = c end
            end
        end

        -- Render each page
        for cat, list in pairs(categorized) do
            local page = f.pages[cat]
            if page then
                -- Sort
                table.sort(list, function(a, b) return (a.label or "") < (b.label or "") end)

                -- Grid Layout
                local COLS = 3
                local ROW_HEIGHT = 28
                local COL_WIDTH = (page.child:GetWidth()) / COLS

                -- Hide all existing
                for _, btn in ipairs(page.buttons) do btn:Hide() end

                for i, item in ipairs(list) do
                    local btn = page.buttons[i]
                    if not btn then
                        btn = CreateFrame("Button", nil, page.child)
                        btn:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
                        btn.Text = btn:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
                        btn.Text:SetPoint("LEFT", 4, 0)
                        btn.Text:SetPoint("RIGHT", -4, 0)
                        btn.Text:SetJustifyH("LEFT")
                        btn.Text:SetWordWrap(false)

                        btn:SetScript("OnClick", function(self)
                            if f.callback then f.callback(self.data.key) end
                            f:Hide()
                        end)
                        table.insert(page.buttons, btn)
                    end

                    btn:SetSize(COL_WIDTH, ROW_HEIGHT)
                    local col = (i - 1) % COLS
                    local row = math.floor((i - 1) / COLS)
                    btn:SetPoint("TOPLEFT", col * COL_WIDTH, -(row * ROW_HEIGHT))

                    btn.Text:SetText(item.label or item.key)
                    btn.data = item

                    if item.key == selectedKey then
                        btn.Text:SetTextColor(1, 0.82, 0)
                    else
                        btn.Text:SetTextColor(1, 1, 1)
                    end

                    btn:Show()
                end

                local totalRows = math.ceil(#list / COLS)
                page.child:SetHeight(math.max(1, totalRows * ROW_HEIGHT))
            end
        end

        -- Select Tab
        local tabIdx = 1
        for i, cat in ipairs(CATEGORY_ORDER) do
            if cat == selectedCat then tabIdx = i break end
        end
        f.ribbon:SetActiveTab(tabIdx)

        f:Show()
    end

    return f
end
