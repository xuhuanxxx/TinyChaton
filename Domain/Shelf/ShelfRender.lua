local addonName, addon = ...
local CF = _G["Create" .. "Frame"]
local L = addon.L

addon.ShelfSettingsService = addon.ShelfSettingsService or {}

local Shelf = nil
local shelfEventFrame = nil
local editModeCallbackRegistered = false
local SHELF_ANCHOR_OFFSET_TAB_Y = (addon.CONSTANTS and addon.CONSTANTS.SHELF_ANCHOR_OFFSET_TAB_Y) or 6
local SHELF_ANCHOR_OFFSET_EDITBOX_Y = (addon.CONSTANTS and addon.CONSTANTS.SHELF_ANCHOR_OFFSET_EDITBOX_Y) or 0

local SNAP_THRESHOLD = 50
local function SavePosition()
    if not Shelf then return end
    local db = addon.db and addon.db.profile and addon.db.profile.shelf
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
        addon:CommitSettings("shelf_position_drag", "shelf")
    end
end

local function ApplyPosition(self)
    local db = addon.db and addon.db.profile and addon.db.profile.shelf
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
        local f = CF("Frame", nil, self, "EditModeSystemSelectionTemplate")
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

local TR = addon.TinyReactor
if not TR then
    error("TinyReactor not initialized")
end

local SHELF_BUTTON_TEXT_HPAD = (addon.CONSTANTS and addon.CONSTANTS.SHELF_BUTTON_TEXT_HPAD) or 8
local SHELF_BUTTON_MAX_WIDTH_FACTOR = (addon.CONSTANTS and addon.CONSTANTS.SHELF_BUTTON_MAX_WIDTH_FACTOR) or 1.9
local DEFAULT_FONT_PATH = "Fonts\\FRIZQT__.TTF"

local measureContainer = nil
local measureFontString = nil

local function ResolveThemeFontPath(theme, fallbackFont)
    local themeFont = theme and theme.font
    local fontToUse

    if themeFont == "STANDARD" then
        fontToUse = STANDARD_TEXT_FONT
    elseif themeFont == "CHAT" then
        fontToUse = UNIT_NAME_FONT
    elseif themeFont == "DAMAGE" then
        fontToUse = DAMAGE_TEXT_FONT
    elseif themeFont and themeFont ~= "" then
        fontToUse = themeFont
    else
        fontToUse = fallbackFont
    end

    if type(fontToUse) ~= "string" then
        return DEFAULT_FONT_PATH
    end
    return fontToUse
end

local function EnsureMeasureFontString()
    if measureFontString then
        return measureFontString
    end

    if not measureContainer then
        measureContainer = CF("Frame", nil, UIParent)
        measureContainer:Hide()
    end

    measureFontString = measureContainer:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    return measureFontString
end

function addon.Shelf:ResolveButtonSize(text, theme, btnSize)
    local height = tonumber(btnSize) or addon.CONSTANTS.SHELF_DEFAULT_BUTTON_SIZE or 30
    if type(text) ~= "string" or text == "" then
        return { height, height }
    end

    local fs = EnsureMeasureFontString()
    if not fs then
        return { height, height }
    end

    local currentFont, _, currentOutline = fs:GetFont()
    local fontSize = (theme and theme.fontSize) or addon.CONSTANTS.SHELF_DEFAULT_FONT_SIZE or 14
    local outline = currentOutline or ""
    local fontPath = ResolveThemeFontPath(theme, currentFont)

    fs:SetFont(fontPath, fontSize, outline)
    fs:SetText(text)

    local textWidth = fs:GetStringWidth()
    if not textWidth or textWidth <= 0 then
        return { height, height }
    end

    local maxWidth = math.ceil(height * SHELF_BUTTON_MAX_WIDTH_FACTOR)
    local width = math.ceil(textWidth + (SHELF_BUTTON_TEXT_HPAD * 2))
    width = math.min(math.max(width, height), maxWidth)

    return { width, height }
end

local ShelfButton = TR:Component("ShelfButton")
addon.ShelfButton = ShelfButton


function ShelfButton:Render(props)
    local visualSpec = props.visualSpec or {}
    local theme = visualSpec.themeProps or props.theme or addon:GetShelfThemeProperties()
    local textColor = visualSpec.textColor or addon:GetButtonColor(props.item)
    local state = props.channelState or "joined"
    local buttonSize = props.size

    return TR:CreateElement("Button", {
        key = props.key,
        size = buttonSize,
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
                    local fontToUse = ResolveThemeFontPath(theme, font)
                    fs:SetFont(fontToUse, theme.fontSize, outline)
                end
            end
        end,

        ref = function(btnSelf)
            if not btnSelf.StatusOverlay then
                btnSelf.StatusOverlay = btnSelf:CreateTexture(nil, "OVERLAY")
                btnSelf.StatusOverlay:SetPoint("CENTER")
                btnSelf.StatusOverlay:SetAlpha(0.95)
            end

            local overlay = btnSelf.StatusOverlay
            local width = (buttonSize and buttonSize[1]) or 30
            local height = (buttonSize and buttonSize[2]) or 30
            local s = math.min(width, height) * 0.8
            overlay:SetSize(s, s)

            if state == "unjoined" then
                overlay:SetTexture("Interface\\COMMON\\Indicator-Yellow")
                overlay:SetVertexColor(1, 1, 1, 1)
                overlay:Show()
                if btnSelf:GetFontString() then
                    btnSelf:GetFontString():SetAlpha(0.5)
                end
            elseif state == "muted" then
                overlay:SetTexture("Interface\\Buttons\\UI-GroupLoot-Pass-Down")
                overlay:SetVertexColor(1, 1, 1, 1)
                overlay:Show()
                if btnSelf:GetFontString() then
                    btnSelf:GetFontString():SetAlpha(0.75)
                end
            else
                overlay:Hide()
                if btnSelf:GetFontString() then
                    btnSelf:GetFontString():SetAlpha(1)
                end
            end
        end,
    })
end





function addon.Shelf:Render()
    if not Shelf then return end

    if not addon.db or not addon.db.enabled or not addon.db.profile or not addon.db.profile.buttons or not addon.db.profile.buttons.enabled then
        TR:DebugLog("reconciler", "Shelf:Render skipped - disabled or no db")
        Shelf:Hide()
        return
    end

    TR:DebugLog("reconciler", "Shelf:Render START")
    Shelf:Show()
    local visibleItems = self:GetVisibleItems()

    local themeKey = addon.db.profile.shelf and addon.db.profile.shelf.theme
    local currentTheme = addon:GetShelfThemeProperties(themeKey)
    local shelfVisualSpec = addon.ShelfVisualSpecResolver and addon.ShelfVisualSpecResolver.ResolveButtonVisualSpec
        and addon.ShelfVisualSpecResolver:ResolveButtonVisualSpec(nil, { themeKey = themeKey }) or {}
    currentTheme = shelfVisualSpec.themeProps or currentTheme

    local btnSize = currentTheme.buttonSize or addon.CONSTANTS.SHELF_DEFAULT_BUTTON_SIZE
    local spacing = currentTheme.spacing or addon.CONSTANTS.SHELF_DEFAULT_SPACING

    local elements = {}
    local buttonElements = {}
    local buttonSizes = {}

    local themeAlpha = shelfVisualSpec.alpha or currentTheme.alpha or 1.0
    local themeScale = shelfVisualSpec.scale or currentTheme.scale or 1.0

    Shelf:SetAlpha(themeAlpha)
    Shelf:SetScale(themeScale)

    for _, info in ipairs(visibleItems) do
        local item = info.item
        local bindings = addon.db.profile.buttons and addon.db.profile.buttons.bindings or {}
        local customBind = bindings[item.key]

        local leftActionKey = (customBind and customBind.left) or item.leftClick
        local rightActionKey = (customBind and customBind.right) or item.rightClick
        local actionLeft = leftActionKey and addon.ACTION_REGISTRY and addon.ACTION_REGISTRY[leftActionKey]
        local actionRight = rightActionKey and addon.ACTION_REGISTRY and addon.ACTION_REGISTRY[rightActionKey]

        -- Tooltip logic
        local tooltip = function(tt, btnSelf)
            local headerText = item.label
            if info.isChannel then
                local stream = addon:GetStreamByKey(item.key)
                local identity = stream and addon.ResolveDisplayIdentity and addon:ResolveDisplayIdentity(stream, "channel", {
                    streamMeta = { channelId = info.channelNumber },
                }) or nil
                if identity and identity.fullName then
                    headerText = identity.fullName
                end
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

        local buttonVisualSpec = addon.ShelfVisualSpecResolver and addon.ShelfVisualSpecResolver.ResolveButtonVisualSpec
            and addon.ShelfVisualSpecResolver:ResolveButtonVisualSpec(item, { themeKey = themeKey }) or {}
        local buttonTheme = buttonVisualSpec.themeProps or currentTheme
        local buttonBaseSize = buttonTheme.buttonSize or btnSize
        local buttonSize = self:ResolveButtonSize(info.text, buttonTheme, buttonBaseSize)
        table.insert(buttonSizes, buttonSize)

        table.insert(buttonElements, addon.ShelfButton:Create({
            key = info.key,
            text = info.text,
            item = item,
            channelState = info.channelState,
            size = buttonSize,
            theme = buttonTheme,
            visualSpec = buttonVisualSpec,

            tooltip = tooltip,
            onLeftClick = function(btnSelf)
                addon.Shelf:ExecuteAction(leftActionKey, btnSelf, item)
            end,
            onRightClick = rightActionKey and function(btnSelf)
                addon.Shelf:ExecuteAction(rightActionKey, btnSelf, item)
                if rightActionKey and rightActionKey:match("mute_toggle_") then
                    C_Timer.After(0.1, function()
                        addon.Shelf:Render()
                    end)
                end
            end or nil,
        }))
    end

    -- Root Layout: HStack or VStack based on direction setting
    local direction = addon.db.profile.shelf and addon.db.profile.shelf.direction or "horizontal"
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
                        local fontToUse = ResolveThemeFontPath(currentTheme, font)
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
        local totalMainAxis = 0
        local maxCrossAxis = 0
        for _, size in ipairs(buttonSizes) do
            local w = size[1] or btnSize
            local h = size[2] or btnSize
            if direction == "vertical" then
                totalMainAxis = totalMainAxis + h
                maxCrossAxis = math.max(maxCrossAxis, w)
            else
                totalMainAxis = totalMainAxis + w
                maxCrossAxis = math.max(maxCrossAxis, h)
            end
        end
        totalMainAxis = totalMainAxis + ((count - 1) * spacing)
        if direction == "vertical" then
            Shelf:SetSize(maxCrossAxis, totalMainAxis)
        else
            Shelf:SetSize(totalMainAxis, maxCrossAxis)
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
    if not addon.db or not addon.db.enabled or not addon.db.profile or not addon.db.profile.buttons then return end
    if not addon.db.profile.buttons.enabled then return end

    if not Shelf then
        Shelf = CF("Frame", "TinyChatonShelf", UIParent)
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
        shelfEventFrame = CF("Frame")
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
            if addon.DynamicChannelResolver and addon.DynamicChannelResolver.InvalidateCache then
                addon.DynamicChannelResolver:InvalidateCache()
            end
            addon.Shelf:Render()
        end)
    end

    f:SetScript("OnEvent", function(self, event, ...)
        if addon.DynamicChannelResolver and addon.DynamicChannelResolver.InvalidateCache then
            addon.DynamicChannelResolver:InvalidateCache()
        end
        addon.Shelf:Render()
    end)

    self:Render()
end



function addon:RefreshShelf()
    if addon.Profiler and addon.Profiler.Start then
        addon.Profiler:Start("ShelfService.RefreshShelf")
    end
    if addon.Shelf then
        addon.Shelf:Render()
    end
    if addon.Profiler and addon.Profiler.Stop then
        addon.Profiler:Stop("ShelfService.RefreshShelf")
    end
end

function addon:RegisterChannelButtons()
    if addon.Shelf then
        addon.Shelf:Render()
    end
end

function addon:InitShelf()
    if not addon.Shelf then return end

    addon:RegisterSettingsSubscriber({
        key = "settings.shelf.render",
        phase = "shelf",
        priority = 10,
        apply = function(ctx)
            local service = addon:ResolveRequiredService("ShelfService")
            service:Commit(ctx)
        end,
    })

    if addon.Shelf.InitActionRegistry then
        addon.Shelf:InitActionRegistry()
    end

    if addon.Shelf.InitRender then
        addon.Shelf:InitRender()
    end
end

function addon.ShelfSettingsService:Commit()
    addon:RefreshShelf()
end

addon:RegisterModule("Shelf", addon.InitShelf)
