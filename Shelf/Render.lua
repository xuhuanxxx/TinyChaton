local addonName, addon = ...
local L = addon.L

local Shelf = nil
local shelfEventFrame = nil
local editModeCallbackRegistered = false
local SHELF_ANCHOR_OFFSET_TAB_Y = (addon.CONSTANTS and addon.CONSTANTS.SHELF_ANCHOR_OFFSET_TAB_Y) or 6
local SHELF_ANCHOR_OFFSET_EDITBOX_Y = (addon.CONSTANTS and addon.CONSTANTS.SHELF_ANCHOR_OFFSET_EDITBOX_Y) or 0

local SNAP_THRESHOLD = 50
local function SavePosition()
    if not Shelf then return end
    local db = addon.db and addon.db.plugin and addon.db.plugin.shelf
    if not db then return end

    local sl, sr, st, sb = Shelf:GetLeft(), Shelf:GetRight(), Shelf:GetTop(), Shelf:GetBottom()
    if not sl or not sr or not st or not sb then return end

    local parL, parR, parT, parB = UIParent:GetLeft(), UIParent:GetRight(), UIParent:GetTop(), UIParent:GetBottom()
    if not parL or not parR or not parT or not parB then return end

    local point, relPoint, snapX, snapY

    local nearLeft = (sl - parL) < SNAP_THRESHOLD
    local nearRight = (parR - sr) < SNAP_THRESHOLD
    local nearTop = (parT - st) < SNAP_THRESHOLD
    local nearBottom = (sb - parB) < SNAP_THRESHOLD

    if nearTop then
        if nearLeft then
            point, relPoint = "TOPLEFT", "TOPLEFT"
            snapX = nearLeft and 0 or (sl - parL)
            snapY = nearTop and 0 or (st - parT)
        elseif nearRight then
            point, relPoint = "TOPRIGHT", "TOPRIGHT"
            snapX = nearRight and 0 or (sr - parR)
            snapY = nearTop and 0 or (st - parT)
        else
            point, relPoint = "TOP", "TOP"
            snapX = ((sl + sr) / 2) - ((parL + parR) / 2)
            snapY = nearTop and 0 or (st - parT)
        end
    elseif nearBottom then
        if nearLeft then
            point, relPoint = "BOTTOMLEFT", "BOTTOMLEFT"
            snapX = nearLeft and 0 or (sl - parL)
            snapY = nearBottom and 0 or (sb - parB)
        elseif nearRight then
            point, relPoint = "BOTTOMRIGHT", "BOTTOMRIGHT"
            snapX = nearRight and 0 or (sr - parR)
            snapY = nearBottom and 0 or (sb - parB)
        else
            point, relPoint = "BOTTOM", "BOTTOM"
            snapX = ((sl + sr) / 2) - ((parL + parR) / 2)
            snapY = nearBottom and 0 or (sb - parB)
        end
    else
        point, relPoint = "BOTTOMLEFT", "BOTTOMLEFT"
        snapX = nearLeft and 0 or (sl - parL)
        snapY = sb - parB
    end

    Shelf:ClearAllPoints()
    Shelf:SetPoint(point, UIParent, relPoint, snapX, snapY)

    local p, _, rp, x, y = Shelf:GetPoint(1)
    db.savedPoint = { p, rp, x, y }
    db.anchor = "custom"

    if SettingsPanel and SettingsPanel:IsShown() then
        addon:ApplyAllSettings()
    end
end

local function ApplyPosition(self)
    local db = addon.db and addon.db.plugin and addon.db.plugin.shelf
    if not db then return end
    self:ClearAllPoints()

    self:SetClampedToScreen(true)

    local applied = false
    local anchors = addon.AnchorRegistry and addon.AnchorRegistry:GetAnchors()

    if db.anchor == "custom" then
        if db.savedPoint and #db.savedPoint > 0 then
            local sp = db.savedPoint
            local rp = (#sp >= 4) and sp[2] or sp[1]
            self:SetPoint(sp[1], UIParent, rp, sp[#sp - 1], sp[#sp])
            applied = true
        else
            local defaultPos = addon.CONSTANTS.SHELF_DEFAULT_POSITION
            if anchors then
                for _, cfg in ipairs(anchors) do
                    if cfg.name == defaultPos and cfg.isValid() then
                        cfg.apply(self)
                        applied = true
                        break
                    end
                end
            end
        end
    end

    if not applied and anchors then
        for _, cfg in ipairs(anchors) do
            if cfg.name == db.anchor then
                if cfg.isValid() then
                    cfg.apply(self)
                    applied = true
                end
                break
            end
        end
    end

    if not applied and anchors then
        for _, cfg in ipairs(anchors) do
            if cfg.isValid() then
                cfg.apply(self)
                applied = true
                break
            end
        end
    end

    if not applied then
        self:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    end
end

local function UpdateEditModeShelf(self)
    if not self.selectionFrame then
        local f = CreateFrame("Frame", nil, self, "EditModeSystemSelectionTemplate")
        f:SetAllPoints()

        f.system = {
            GetSystemName = function() return L["LABEL_EDIT_MODE"] end,
            IsSelected = function() return self.isSelected end,
        }

        f:SetScript("OnMouseDown", function()
            if EditModeManagerFrame and EditModeManagerFrame.ClearSelectedSystem then
                EditModeManagerFrame:ClearSelectedSystem()
            end
            self.isSelected = true
            f:ShowSelected(true)
            self:StartMoving()
        end)

        f:SetScript("OnMouseUp", function()
            self:StopMovingOrSizing()
            SavePosition()
        end)

        self.selectionFrame = f
    end

    if self.isEditing then
        self.selectionFrame:Show()
        self.selectionFrame:ShowHighlighted()
    elseif self.selectionFrame and self.selectionFrame:IsShown() then
        self.selectionFrame:Hide()
        self.isSelected = false
    end
end

local function ToggleEditMode(self, enabled)
    if self.isEditing == enabled then return end
    self.isEditing = enabled
    self:SetMovable(enabled)
    self:EnableMouse(enabled)
    UpdateEditModeShelf(self)
end

local TR = _G.TinyReactor

local ShelfButton = TR:Component("ShelfButton")
addon.ShelfButton = ShelfButton


function ShelfButton:Render(props)
    local theme = props.theme or addon:GetShelfThemeProperties(addon.CONSTANTS.SHELF_DEFAULT_THEME)

    local textColor = addon:GetButtonColor(props.item)

    -- Gray out if inactive
    -- Gray out if inactive? No, user requested "Cross out" (叉号)
    -- So we will use an overlay texture instead of dimming.
    if props.isActive == false then
        -- Optional: slight dim to make the cross pop more?
        -- textColor = { textColor[1], textColor[2], textColor[3], (textColor[4] or 1) * 0.6 }
    end

    return TR:CreateElement("Button", {
        key = props.key,
        size = {props.size or 30, props.size or 30},
        point = props.point,
        text = props.text,
        textColor = textColor,

        template = theme.template,
        backdrop = theme.backdrop,
        backdropColor = theme.bgColor,
        backdropBorderColor = theme.borderColor,

        onClick = function(btnSelf, button)
             if button == "LeftButton" and props.onLeftClick then
                 props.onLeftClick(btnSelf)
             elseif button == "RightButton" and props.onRightClick then
                 props.onRightClick(btnSelf)
             end
        end,

        onEnter = function(btnSelf)
            -- Ensure clicks are registered (fix for right-click issue)
            btnSelf:RegisterForClicks("AnyUp")

            if theme.hoverBorderColor then
                btnSelf:SetBackdropBorderColor(unpack(theme.hoverBorderColor))
            end

            if props.tooltip then
                GameTooltip:SetOwner(btnSelf, "ANCHOR_RIGHT")
                if type(props.tooltip) == "function" then
                    props.tooltip(GameTooltip, btnSelf)
                else
                    GameTooltip:SetText(props.tooltip)
                end
                GameTooltip:Show()
            end
        end,

        onLeave = function(btnSelf)
            if theme.borderColor then
                btnSelf:SetBackdropBorderColor(unpack(theme.borderColor))
            end
            GameTooltip:Hide()
        end,

        onShow = function(btnSelf)
            btnSelf:RegisterForClicks("AnyUp")

            if theme.fontSize then
                local fs = btnSelf:GetFontString()
                if fs then
                    local font, _, outline = fs:GetFont()
                    if not font then font = "Fonts\\FRIZQT__.TTF" end

                    local themeFont = theme.font
                    local fontToUse

                    if themeFont == "STANDARD" then fontToUse = STANDARD_TEXT_FONT
                    elseif themeFont == "CHAT" then fontToUse = UNIT_NAME_FONT
                    elseif themeFont == "DAMAGE" then fontToUse = DAMAGE_TEXT_FONT
                    elseif themeFont and themeFont ~= "" then fontToUse = themeFont
                    else fontToUse = font end

                    if type(fontToUse) ~= "string" then fontToUse = "Fonts\\FRIZQT__.TTF" end

                    fs:SetFont(fontToUse, theme.fontSize, outline)
                end
            end
        end,

        ref = function(btnSelf)
            if not btnSelf.DisabledOverlay then
                btnSelf.DisabledOverlay = btnSelf:CreateTexture(nil, "OVERLAY")
                btnSelf.DisabledOverlay:SetTexture("Interface\\Buttons\\UI-GroupLoot-Pass-Up")
                btnSelf.DisabledOverlay:SetPoint("CENTER")
                btnSelf.DisabledOverlay:SetAlpha(0.9)
            end

            local s = (props.size or 30) * 0.8
            btnSelf.DisabledOverlay:SetSize(s, s)

            if props.isActive == false then
                btnSelf.DisabledOverlay:Show()
                if btnSelf:GetFontString() then
                    btnSelf:GetFontString():SetAlpha(0.5)
                end
            else
                btnSelf.DisabledOverlay:Hide()
                if btnSelf:GetFontString() then
                    btnSelf:GetFontString():SetAlpha(1)
                end
            end
        end,
    })
end





function addon.Shelf:Render()
    if not Shelf then return end

    if not addon.db or not addon.db.enabled or not addon.db.plugin or not addon.db.plugin.shelf or not addon.db.plugin.shelf.enabled then
        TR:DebugLog("reconciler", "Shelf:Render skipped - disabled or no db")
        Shelf:Hide()
        return
    end

    TR:DebugLog("reconciler", "Shelf:Render START")
    Shelf:Show()
    local visibleItems = self:GetVisibleItems()

    local themeKey = (addon.db.plugin.shelf.theme) or addon.CONSTANTS.SHELF_DEFAULT_THEME
    local currentTheme = addon:GetShelfThemeProperties(themeKey)

    local btnSize = currentTheme.buttonSize or addon.CONSTANTS.SHELF_DEFAULT_BUTTON_SIZE
    local spacing = currentTheme.spacing or addon.CONSTANTS.SHELF_DEFAULT_SPACING
    local currentX = 0

    local elements = {}
    local buttonElements = {}

    local dbTheme = addon.db.plugin.shelf.themes and addon.db.plugin.shelf.themes[themeKey] or {}
    local themeAlpha = dbTheme.alpha or currentTheme.alpha or 1.0
    local themeScale = dbTheme.scale or currentTheme.scale or 1.0

    Shelf:SetAlpha(themeAlpha)
    Shelf:SetScale(themeScale)

    for _, info in ipairs(visibleItems) do
        local item = info.item
        local bindings = addon.db.plugin.shelf.bindings or {}
        local customBind = bindings[item.key]

        local leftActionKey = (customBind and customBind.left) or item.leftClick
        local rightActionKey = (customBind and customBind.right) or item.rightClick
        local actionLeft = leftActionKey and addon.ACTION_REGISTRY and addon.ACTION_REGISTRY[leftActionKey]
        local actionRight = rightActionKey and addon.ACTION_REGISTRY and addon.ACTION_REGISTRY[rightActionKey]

        -- Tooltip logic
        local tooltip = function(tt, btnSelf)
            local headerText = item.label
            if info.isChannel and item.isDynamic and item.mappingKey then
                 headerText = L[item.mappingKey]
            end
            tt:SetText(headerText, 1, 0.82, 0)

            if actionLeft or actionRight then
                if actionLeft then
                    local leftLabel = type(actionLeft.getLabel) == "function" and actionLeft.getLabel(item.key) or actionLeft.label
                    tt:AddLine(L["LABEL_BINDING_LEFT"] .. "  " .. leftLabel, 1, 1, 1, 1, true)
                end
                if actionRight then
                    local rightLabel = type(actionRight.getLabel) == "function" and actionRight.getLabel(item.key) or actionRight.label
                    tt:AddLine(L["LABEL_BINDING_RIGHT"] .. "  " .. rightLabel, 1, 1, 1, 1, true)
                end
            end
        end

        table.insert(buttonElements, addon.ShelfButton:Create({
            key = info.key,
            text = info.text,
            item = item,
            key = info.key,
            text = info.text,
            item = item,
            isActive = info.isActive, -- Pass active state
            size = btnSize,
            theme = currentTheme, -- Pass the theme!

            tooltip = tooltip,
            onLeftClick = function(btnSelf)
                addon.Shelf:ExecuteAction(leftActionKey, btnSelf, item)
            end,
            onRightClick = rightActionKey and function(btnSelf)
                addon.Shelf:ExecuteAction(rightActionKey, btnSelf, item)
                if rightActionKey and rightActionKey:match("toggle_") then
                    C_Timer.After(0.1, function()
                        addon.Shelf:Render()
                    end)
                end
            end or nil,
        }))

        currentX = currentX + btnSize + spacing
    end

    -- Root Layout: HStack or VStack based on direction setting
    local direction = addon.db.plugin.shelf.direction or "horizontal"
    local StackComponent = (direction == "vertical") and TR.VStack or TR.HStack
    local anchorPoint = (direction == "vertical") and {"TOP", Shelf, "TOP", 0, 0} or {"LEFT", Shelf, "LEFT", 0, 0}

    table.insert(elements, StackComponent:Create({
        key = "MainStack",
        gap = spacing,
        point = anchorPoint,
    }, buttonElements))

    -- TinyReactor Magic!
    TR.Reconciler:Render(Shelf, elements)

    if currentTheme.fontSize then
        local function ApplyFontRecursively(frame)
            if not frame or not frame.GetChildren then return end
            local children = { frame:GetChildren() }
            for _, child in ipairs(children) do
                if child:GetObjectType() == "Button" and child.GetFontString then
                    local fs = child:GetFontString()
                    if fs then
                        local font, _, outline = fs:GetFont()
                        if not font then font = "Fonts\\FRIZQT__.TTF" end

                        local themeFont = currentTheme.font
                        local fontToUse

                        if themeFont == "STANDARD" then fontToUse = STANDARD_TEXT_FONT
                        elseif themeFont == "CHAT" then fontToUse = UNIT_NAME_FONT
                        elseif themeFont == "DAMAGE" then fontToUse = DAMAGE_TEXT_FONT
                        elseif themeFont and themeFont ~= "" then fontToUse = themeFont
                        else fontToUse = font end

                        if type(fontToUse) ~= "string" then fontToUse = "Fonts\\FRIZQT__.TTF" end

                        fs:SetFont(fontToUse, currentTheme.fontSize, outline)
                    end
                end
                ApplyFontRecursively(child)
            end
        end
        ApplyFontRecursively(Shelf)
    end

    local count = #buttonElements
    if count > 0 then
        local totalLength = (count * btnSize) + ((count - 1) * spacing)
        if direction == "vertical" then
            Shelf:SetSize(btnSize, totalLength)
        else
            Shelf:SetSize(totalLength, btnSize)
        end
    else
        Shelf:SetSize(btnSize, btnSize)
    end

    ApplyPosition(Shelf)

    if Shelf.isEditing and Shelf.UpdateEditModeShelf then
        Shelf:UpdateEditModeShelf()
    end
end



function addon.Shelf:InitRender()
    if not addon.db or not addon.db.enabled or not addon.db.plugin or not addon.db.plugin.shelf then return end
    if not addon.db.plugin.shelf.enabled then return end

    if not Shelf then
        Shelf = CreateFrame("Frame", "TinyChatonShelf", UIParent)
        Shelf:SetFrameStrata("MEDIUM")
        Shelf:SetFrameLevel(100)

        Shelf:Hide()

        Shelf.UpdateEditModeShelf = UpdateEditModeShelf
        Shelf.ToggleEditMode = ToggleEditMode
        Shelf.SavePosition = SavePosition
        Shelf.ApplyPosition = ApplyPosition

        self.frame = Shelf

        self.SavePosition = SavePosition
        self.ApplyPosition = ApplyPosition
    end
    local function SyncEditMode()
        if EditModeManagerFrame then
            ToggleEditMode(Shelf, EditModeManagerFrame:IsEditModeActive())
        end
    end

    if EventRegistry and EventRegistry.RegisterFrameEventAndCallback and not editModeCallbackRegistered then
        EventRegistry:RegisterFrameEventAndCallback("EDIT_MODE_LAYOUTS_UPDATED", SyncEditMode)
        editModeCallbackRegistered = true
    end

    if EditModeManagerFrame then
        EditModeManagerFrame:HookScript("OnShow", function() ToggleEditMode(Shelf, true) end)
        EditModeManagerFrame:HookScript("OnHide", function() ToggleEditMode(Shelf, false) end)
    end

    SyncEditMode()

    if not shelfEventFrame then
        shelfEventFrame = CreateFrame("Frame")
        shelfEventFrame:RegisterEvent("CHAT_MSG_CHANNEL_NOTICE")
        shelfEventFrame:RegisterEvent("CHANNEL_UI_UPDATE")
        shelfEventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    end
    local f = shelfEventFrame

    local channelRefreshTimer = nil
    local function DebouncedRefresh()
        if channelRefreshTimer then
            channelRefreshTimer:Cancel()
        end
        channelRefreshTimer = C_Timer.NewTimer(0.5, function()
            channelRefreshTimer = nil
            if addon.Shelf and addon.Shelf.InvalidateChannelListCache then
                addon.Shelf:InvalidateChannelListCache()
            end
            addon.Shelf:Render()
        end)
    end

    f:SetScript("OnEvent", function(self, event, ...)
        if event == "CHAT_MSG_CHANNEL_NOTICE" then
            local noticeType = ...
            if noticeType == "YOU_JOINED" or noticeType == "YOU_LEFT" then
                DebouncedRefresh()
            end
        else
            if addon.Shelf and addon.Shelf.InvalidateChannelListCache then
                addon.Shelf:InvalidateChannelListCache()
            end
            addon.Shelf:Render()
        end
    end)

    self:Render()
end



function addon:RefreshShelf()
    if addon.Shelf then
        addon.Shelf:Render()
    end
end

-- Alias for settings hooks to ensure real-time updates
function addon:ApplyShelfSettings()
    self:RefreshShelf()
end

function addon:RegisterChannelButtons()
    if addon.Shelf then
        addon.Shelf:Render()
    end
end

function addon:InitShelf()
    if not addon.Shelf then return end

    if addon.Shelf.InitActionRegistry then
        addon.Shelf:InitActionRegistry()
    end

    if addon.Shelf.InitRender then
        addon.Shelf:InitRender()
    end
end

addon:RegisterModule("Shelf", addon.InitShelf)
