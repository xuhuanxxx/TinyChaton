local addonName, addon = ...
local CF = _G["Create" .. "Frame"]

-- Selection Ribbon dialog moved from Libs/Ribbon.lua
function addon.CreateSelectionRibbon(name, parent)
    -- User requested "DialogBorderDarkTemplate" for high-res look.
    -- We MUST use ClearAllPoints() because this template likely defaults to full screen anchors.
    local f = CF("Frame", name, parent, "DialogBorderDarkTemplate")
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
    f.Header = CF("Frame", nil, f, "DialogHeaderTemplate")
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

    if f.TitleContainer then f.TitleContainer:Hide() end

    -- Close Button
    if not f.CloseButton then
        f.CloseButton = CF("Button", nil, f, "UIPanelCloseButton")
        f.CloseButton:SetSize(24, 24)
        f.CloseButton:SetPoint("TOPRIGHT", -5, -5)
    else
        f.CloseButton:SetPoint("TOPRIGHT", -5, -5)
        f.CloseButton:SetFrameLevel(f:GetFrameLevel() + 10)
    end

    -- Fixed Categories for now
    local CATEGORY_ORDER = { "channel", "kit" }

    -- Compact Labels
    local L = addon.L
    local COMPACT_LABELS = {
        channel = L["LABEL_COMPACT_CHANNEL"] or "Channel",
        kit = L["LABEL_COMPACT_KIT"] or "Tools",
    }

    -- Dynamic Layout: Anchor Ribbon below Header
    f.ribbon = addon.CreateRibbon(f, {
        tabs = {
            { id = "channel", label = COMPACT_LABELS.channel or "channel" },
            { id = "kit", label = COMPACT_LABELS.kit or "kit" },
        },
        layout = {
            startX = 10,
            startY = 0, -- Overridden below
            spacing = -10,
            minTabWidth = 60,
            maxTabWidth = 80,
            height = 24,
        },
        behavior = {
            defaultTabId = "channel",
            playClickSound = true,
            onTabChanged = function() end,
        },
        content = {
            pageInset = { top = 0, bottom = 40, left = 10, right = 10 },
        },
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
        local pageContainer = f.ribbon:CreatePage(cat, f)

        pageContainer:ClearAllPoints()
        pageContainer:SetPoint("TOPLEFT", f.ribbon, "BOTTOMLEFT", 0, -5) -- 5px gap below tabs
        pageContainer:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -10, 40) -- 40px bottom for buttons

        local scroll = CF("ScrollFrame", nil, pageContainer, "UIPanelScrollFrameTemplate")
        scroll:SetPoint("TOPLEFT", 0, 0)
        scroll:SetPoint("BOTTOMRIGHT", -26, 0)

        local child = CF("Frame")
        child:SetSize(460, 1) -- Estimated width
        scroll:SetScrollChild(child)

        f.pages[cat] = { container = pageContainer, scroll = scroll, child = child, buttons = {} }
    end

    -- Bottom Buttons
    -- Bottom Buttons
    f.DefaultButton = CF("Button", nil, f, "UIPanelButtonTemplate")
    f.DefaultButton:SetSize(100, 22)
    f.DefaultButton:SetPoint("BOTTOMRIGHT", -20, 10) -- Swapped to Right
    f.DefaultButton:SetText(L["LABEL_DEFAULT"])
    f.DefaultButton:SetScript("OnClick", function()
        if f.callback then f.callback(nil) end
        f:Hide()
    end)

    f.ClearButton = CF("Button", nil, f, "UIPanelButtonTemplate")
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
                local c = item.category or defaultCat
                if not categorized[c] then c = defaultCat end
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
                        btn = CF("Button", nil, page.child)
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
        f.ribbon:SelectTabById(selectedCat)

        f:Show()
    end

    return f
end
