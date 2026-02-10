local addonName, addon = ...
local L = addon.L

local panel
local buttons = {}
local currentPage = 1
local maxPage = 1

local function GetPageSize()
    return addon.CONSTANTS and addon.CONSTANTS.EMOTE_PAGE_SIZE or 40
end

local function UpdateEmotePanel()
    if not panel then return end
    
    -- Ensure EmotesRender module is loaded and has data
    if not addon.EmotesRender or not addon.EmotesRender.emotes then return end
    local emotes = addon.EmotesRender.emotes

    local pageSize = GetPageSize()
    local total = #emotes
    maxPage = math.ceil(total / pageSize)
    if currentPage > maxPage then currentPage = maxPage end
    if currentPage < 1 then currentPage = 1 end

    local startIndex = (currentPage - 1) * pageSize

    for i = 1, GetPageSize() do
        local btn = buttons[i]
        local emoteIndex = startIndex + i
        local emote = emotes[emoteIndex]

        if emote then
            btn:SetNormalTexture(emote.file)
            btn.emoteKey = emote.key
            btn:Show()
        else
            btn:Hide()
        end
    end

    panel.pageLabel:SetText(currentPage .. " / " .. maxPage)

    panel.prevBtn:SetEnabled(currentPage > 1)
    panel.nextBtn:SetEnabled(currentPage < maxPage)
end

function addon:ToggleEmotePanel(anchorFrame)
    if not panel then
        panel = addon.UI.CreateDialog("TinyChatonEmotePanel", L["KIT_EMOTE"])

        local size = 24
        local padding = 6
        local cols = 8
        local rows = 5

        -- Adaptive Grid Container
        if not panel.Content then
            panel.Content = CreateFrame("Frame", nil, panel)
        end
        panel.Content:ClearAllPoints()
        -- Anchor content relative to the Header's bottom
        panel.Content:SetPoint("TOP", panel.Header, "BOTTOM", 0, -10)

        local gridWidth = (cols * (size + padding)) - padding
        local gridHeight = (rows * (size + padding)) - padding
        panel.Content:SetSize(gridWidth, gridHeight)

        -- Resize main panel to wrap content
        -- Width: Grid + Side Margins (approx 32 total)
        -- Height: Grid + Top Margin (Header area) + Bottom Margin (Nav area)
        -- We estimate header area takes ~40 space, Nav area ~30
        panel:SetSize(gridWidth + 40, gridHeight + 70)

        -- Create Buttons
        for i = 1, GetPageSize() do
            local btn = CreateFrame("Button", nil, panel.Content) -- Parent to Content
            btn:SetSize(size, size)
            local row = math.floor((i-1) / cols)
            local col = (i-1) % cols

            -- Relative to Content Frame (0,0 is TopLeft of content)
            btn:SetPoint("TOPLEFT", col * (size + padding), -(row * (size + padding)))

            btn:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight")

            -- Register right-click to close
            btn:RegisterForClicks("AnyUp")
            btn:SetScript("OnClick", function(self, button)
                if button == "RightButton" then
                    panel:Hide()
                    return
                end

                local editBox = ChatEdit_ChooseBoxForSend()
                if editBox then
                    ChatEdit_ActivateChat(editBox)
                    -- ... insert logic ...
                    editBox:Insert(self.emoteKey)
                    if not IsShiftKeyDown() then
                        panel:Hide()
                    end
                end
            end)

            btn:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetText(self.emoteKey)
                GameTooltip:Show()
            end)
            btn:SetScript("OnLeave", function() GameTooltip:Hide() end)

            buttons[i] = btn
        end

        -- Create Navigation
        local navHeight = 20
        local prevBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
        prevBtn:SetSize(20, navHeight)
        prevBtn:SetPoint("BOTTOMLEFT", 16, 12) -- Fixed margin from bottom
        -- i18n
        prevBtn:SetText(L["NAV_PREVIOUS"] or "<")
        prevBtn:RegisterForClicks("AnyUp")
        prevBtn:SetScript("OnClick", function(self, button)
            if button == "RightButton" then panel:Hide() return end
            if currentPage > 1 then
                currentPage = currentPage - 1
                UpdateEmotePanel()
            end
        end)
        panel.prevBtn = prevBtn

        local nextBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
        nextBtn:SetSize(20, navHeight)
        nextBtn:SetPoint("BOTTOMRIGHT", -16, 12)
        -- i18n
        nextBtn:SetText(L["NAV_NEXT"] or ">")
        nextBtn:RegisterForClicks("AnyUp")
        nextBtn:SetScript("OnClick", function(self, button)
            if button == "RightButton" then panel:Hide() return end
            if currentPage < maxPage then
                currentPage = currentPage + 1
                UpdateEmotePanel()
            end
        end)
        panel.nextBtn = nextBtn

        local pageLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        pageLabel:SetPoint("CENTER", panel, "BOTTOM", 0, 18)
        panel.pageLabel = pageLabel

        -- Explicitly update content on first creation
        UpdateEmotePanel()

        -- Set initial point if anchor provided, otherwise center
        if anchorFrame then
            panel:SetPoint("BOTTOMLEFT", anchorFrame, "TOPLEFT", 0, 5)
        else
            panel:SetPoint("CENTER")
        end

        -- Show it immediately on creation
        panel:Show()
        return
    end

    if panel:IsShown() then
        panel:Hide()
    else
        panel:ClearAllPoints()
        panel:SetPoint("BOTTOMLEFT", anchorFrame, "TOPLEFT", 0, 5)
        UpdateEmotePanel()
        panel:Show()
    end
end
