local addonName, addon = ...
local L = addon.L

addon.UI = {}

-- ============================================
-- Canvas Style & Layout
-- ============================================

local CanvasStyle = {
    topPadding = 24,
    contentWidth = 580,
    leftMargin = 20,
    rowHeight = 32,
    sectionSpacing = 16,
    headerFontSize = 18,
    headerColor = {1, 0.82, 0},
    headerTopSpacing = 12,
    headerBottomSpacing = 8,
    dividerColor = {0.3, 0.3, 0.3, 1},
    descColor = {0.7, 0.7, 0.7},
}
addon.UI.CanvasStyle = CanvasStyle

function addon.UI.CreateCanvas(parentFrame, opts)
    opts = opts or {}
    local style = CanvasStyle
    local frameWidth = opts.frameWidth or 620
    local frameHeight = opts.frameHeight or 500

    parentFrame = parentFrame or CreateFrame("Frame", nil, UIParent)
    parentFrame:SetSize(frameWidth, frameHeight)

    local scrollFrame = CreateFrame("ScrollFrame", nil, parentFrame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", parentFrame, "TOPLEFT", 0, -10)
    scrollFrame:SetPoint("BOTTOMRIGHT", parentFrame, "BOTTOMRIGHT", -26, 10)

    local scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetSize(style.contentWidth, 800)
    scrollFrame:SetScrollChild(scrollChild)

    local yOffset = style.topPadding

    local layout = {}

    function layout.AddHeader(text)
        local header = scrollChild:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
        header:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", style.leftMargin, -yOffset)
        local font, size, flags = header:GetFont()
        header:SetFont(font, style.headerFontSize, flags)
        header:SetText(text)
        header:SetTextColor(unpack(style.headerColor))
        yOffset = yOffset + style.headerFontSize + style.headerTopSpacing

        local divider = scrollChild:CreateTexture(nil, "ARTWORK")
        divider:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", style.leftMargin, -yOffset)
        divider:SetSize(style.contentWidth - 40, 1)
        divider:SetColorTexture(unpack(style.dividerColor))
        yOffset = yOffset + style.headerBottomSpacing + style.sectionSpacing
    end

    function layout.AddCheckbox(label, checked, onChange)
        local row = CreateFrame("Frame", nil, scrollChild)
        row:SetSize(style.contentWidth, style.rowHeight)
        row:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", style.leftMargin, -yOffset)

        local cb = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate")
        cb:SetSize(26, 26)
        cb:SetPoint("LEFT", row, "LEFT", 0, 0)
        cb:SetChecked(checked)
        cb:SetScript("OnClick", function(self) if onChange then onChange(self:GetChecked()) end end)

        local lbl = row:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        lbl:SetPoint("LEFT", cb, "RIGHT", 8, 0)
        lbl:SetText(label)

        yOffset = yOffset + style.rowHeight
        return cb
    end

    function layout.AddSlider(label, value, minVal, maxVal, step, onChange)
        local row = CreateFrame("Frame", nil, scrollChild)
        row:SetSize(style.contentWidth, style.rowHeight + 10)
        row:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", style.leftMargin, -yOffset)

        local lbl = row:CreateFontString(nil, "ARTWORK", "GameFontNormal")
        lbl:SetPoint("LEFT", row, "LEFT", 0, 0)
        lbl:SetText(label)

        local slider = CreateFrame("Slider", nil, row, "OptionsSliderTemplate")
        slider:SetPoint("LEFT", lbl, "RIGHT", 20, 0)
        slider:SetWidth(180)
        slider:SetMinMaxValues(minVal, maxVal)
        slider:SetValueStep(step)
        slider:SetObeyStepOnDrag(true)
        slider:SetValue(value)
        slider.Low:SetText(tostring(minVal))
        slider.High:SetText(tostring(maxVal))
        slider.Text:SetText(tostring(value))
        slider:SetScript("OnValueChanged", function(self, val)
            val = math.floor(val / step) * step
            self.Text:SetText(tostring(val))
            if onChange then onChange(val) end
        end)

        yOffset = yOffset + style.rowHeight + 10
        return slider
    end

    function layout.AddButton(label, buttonText, onClick)
        local row = CreateFrame("Frame", nil, scrollChild)
        row:SetSize(style.contentWidth, style.rowHeight)
        row:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", style.leftMargin, -yOffset)

        local lbl = row:CreateFontString(nil, "ARTWORK", "GameFontNormal")
        lbl:SetPoint("LEFT", row, "LEFT", 0, 0)
        lbl:SetText(label)

        local btn = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
        btn:SetSize(100, 24)
        btn:SetPoint("LEFT", lbl, "RIGHT", 20, 0)
        btn:SetText(buttonText)
        btn:SetScript("OnClick", onClick)

        yOffset = yOffset + style.rowHeight
        return btn
    end

    function layout.AddText(text, color)
        local lbl = scrollChild:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        lbl:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", style.leftMargin, -yOffset)
        lbl:SetWidth(style.contentWidth - 40)
        lbl:SetJustifyH("LEFT")
        lbl:SetText(text)
        lbl:SetTextColor(unpack(color or style.descColor))
        yOffset = yOffset + 20
        return lbl
    end

    function layout.AddSpace(height)
        yOffset = yOffset + (height or style.sectionSpacing)
    end

    function layout.GetYOffset() return yOffset end
    function layout.AdvanceY(amount) yOffset = yOffset + amount end
    function layout.SetScrollHeight(h) scrollChild:SetHeight(h) end

    local defaultsBtn
    if opts.showDefaults ~= false then
        defaultsBtn = CreateFrame("Button", nil, parentFrame, "UIPanelButtonTemplate")
        defaultsBtn:SetSize(96, 22)
        defaultsBtn:SetPoint("TOPRIGHT", parentFrame, "TOPRIGHT", -30, 0)
        defaultsBtn:SetText(DEFAULTS)
        defaultsBtn:SetScript("OnClick", opts.onDefaults or function() end)
    end

    return parentFrame, scrollFrame, scrollChild, layout, defaultsBtn
end

-- ============================================
-- Editor Popup System
-- ============================================
local EditorFrame
function addon.UI.ShowEditor(title, dbTable, dbKey, hint, validateFunc)
    if not EditorFrame then
        EditorFrame = CreateFrame("Frame", "TinyChatonEditor", UIParent, "BackdropTemplate")
        EditorFrame:SetSize(400, 300)
        EditorFrame:SetPoint("CENTER")
        EditorFrame:SetFrameStrata("DIALOG")
        EditorFrame:SetBackdrop({
            bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
            tile = true, tileSize = 32, edgeSize = 32,
            insets = { left = 11, right = 12, top = 12, bottom = 11 }
        })
        EditorFrame:EnableMouse(true)

        local header = EditorFrame:CreateTexture(nil, "ARTWORK")
        header:SetTexture("Interface\\DialogFrame\\UI-DialogBox-Header")
        header:SetWidth(256); header:SetHeight(64)
        header:SetPoint("TOP", 0, 12)
        EditorFrame.HeaderTitle = EditorFrame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
        EditorFrame.HeaderTitle:SetPoint("TOP", header, "TOP", 0, -14)

        local hintText = EditorFrame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        hintText:SetPoint("BOTTOM", EditorFrame, "BOTTOM", 0, 45)
        EditorFrame.Hint = hintText

        local scroll = CreateFrame("ScrollFrame", nil, EditorFrame, "UIPanelScrollFrameTemplate")
        scroll:SetPoint("TOPLEFT", 24, -30)
        scroll:SetPoint("BOTTOMRIGHT", -40, 50)

        local edit = CreateFrame("EditBox", nil, scroll)
        edit:SetMultiLine(true)
        edit:SetSize(330, 220)
        edit:SetFontObject("GameFontHighlight")
        edit:SetAutoFocus(false)
        scroll:SetScrollChild(edit)
        EditorFrame.Edit = edit

        local btnSave = CreateFrame("Button", nil, EditorFrame, "UIPanelButtonTemplate")
        btnSave:SetSize(90, 22)
        btnSave:SetPoint("BOTTOMRIGHT", -20, 16)
        btnSave:SetText(SAVE)
        btnSave:SetScript("OnClick", function()
            local text = EditorFrame.Edit:GetText()
            local lines = {}
            for line in (text .. "\n"):gmatch("([^\n]*)\n") do
                line = line:match("^%s*(.-)%s*$") or line
                if line ~= "" then table.insert(lines, line) end
            end

            -- 验证函数检查
            if EditorFrame.validateFunc then
                local isValid, errorMsg = EditorFrame.validateFunc(lines)
                if not isValid then
                    -- 显示错误提示
                    if StaticPopupDialogs["TINYCHATON_EDITOR_ERROR"] then
                        StaticPopupDialogs["TINYCHATON_EDITOR_ERROR"].text = errorMsg or "验证失败"
                    else
                        StaticPopupDialogs["TINYCHATON_EDITOR_ERROR"] = {
                            text = errorMsg or "验证失败",
                            button1 = OKAY,
                            hideOnEscape = true,
                            timeout = 0,
                        }
                    end
                    StaticPopup_Show("TINYCHATON_EDITOR_ERROR")
                    return
                end
            end

            if type(EditorFrame.dbTable[EditorFrame.dbKey]) ~= "table" then
                EditorFrame.dbTable[EditorFrame.dbKey] = {}
            end
            table.wipe(EditorFrame.dbTable[EditorFrame.dbKey])
            for _, v in ipairs(lines) do EditorFrame.dbTable[EditorFrame.dbKey][#EditorFrame.dbTable[EditorFrame.dbKey] + 1] = v end
            addon:ApplyAllSettings()
            EditorFrame:Hide()
        end)

        local btnCancel = CreateFrame("Button", nil, EditorFrame, "UIPanelButtonTemplate")
        btnCancel:SetSize(90, 22)
        btnCancel:SetPoint("RIGHT", btnSave, "LEFT", -10, 0)
        btnCancel:SetText(CANCEL)
        btnCancel:SetScript("OnClick", function() EditorFrame:Hide() end)

        if SettingsPanel then
            SettingsPanel:HookScript("OnHide", function()
                if EditorFrame and EditorFrame:IsShown() then
                    EditorFrame:Hide()
                end
            end)
        end
    end

    EditorFrame.HeaderTitle:SetText(title)
    EditorFrame.Hint:SetText(hint or "")
    EditorFrame.dbTable = dbTable
    EditorFrame.dbKey = dbKey
    EditorFrame.validateFunc = validateFunc

    local t = dbTable[dbKey]
    -- Handle function-type templates (returns default values)
    if type(t) == "function" then
        t = t()
    end
    if type(t) == "table" then
        local lines = {}
        for _, v in ipairs(t) do if v and v ~= "" then table.insert(lines, v) end end
        EditorFrame.Edit:SetText(table.concat(lines, "\n"))
    else
        EditorFrame.Edit:SetText("")
    end

    EditorFrame:Show()
end

-- ============================================
-- Generic Dialog Creator
-- ============================================
function addon.UI.CreateDialog(name, title, width, height)
    local dialog = CreateFrame("Frame", name, UIParent, "DialogBorderDarkTemplate")
    dialog:ClearAllPoints()
    dialog:SetSize(width or 400, height or 300)
    dialog:SetPoint("CENTER")
    dialog:SetFrameStrata("DIALOG")
    dialog:SetClampedToScreen(true)
    dialog:EnableMouse(true)
    dialog:Hide()

    -- Close on Right Click
    dialog:SetScript("OnMouseUp", function(self, button)
        if button == "RightButton" then
            self:Hide()
        end
    end)
    
    -- Register for ESC
    table.insert(UISpecialFrames, name)

    -- Header
    dialog.Header = CreateFrame("Frame", nil, dialog, "DialogHeaderTemplate")
    dialog.Header:SetPoint("TOP", 0, 12)
    if dialog.Header.Text then
        dialog.Header.Text:SetText(title)
    else
         for _, region in ipairs({dialog.Header:GetRegions()}) do
             if region:GetObjectType() == "FontString" then
                 region:SetText(title)
                 break
             end
         end
    end
    dialog.Header:SetFrameLevel(dialog:GetFrameLevel() + 5)
    dialog.Header:EnableMouse(true)
    dialog.Header:SetScript("OnMouseUp", function(self, button)
        if button == "RightButton" then dialog:Hide() end
    end)

    -- Close Button
    dialog.CloseButton = CreateFrame("Button", nil, dialog, "UIPanelCloseButton")
    dialog.CloseButton:SetSize(24, 24)
    dialog.CloseButton:SetPoint("TOPRIGHT", -5, -5)
    dialog.CloseButton:RegisterForClicks("AnyUp")
    dialog.CloseButton:SetScript("OnClick", function() dialog:Hide() end)

    return dialog
end
