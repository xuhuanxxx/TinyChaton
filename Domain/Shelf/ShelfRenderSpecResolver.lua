local addonName, addon = ...
local CF = _G["Create" .. "Frame"]

addon.ShelfRenderSpecResolver = addon.ShelfRenderSpecResolver or {}

local Resolver = addon.ShelfRenderSpecResolver

local SHELF_BUTTON_TEXT_HPAD = (addon.CONSTANTS and addon.CONSTANTS.SHELF_BUTTON_TEXT_HPAD) or 8
local SHELF_BUTTON_MAX_WIDTH_FACTOR = (addon.CONSTANTS and addon.CONSTANTS.SHELF_BUTTON_MAX_WIDTH_FACTOR) or 1.9
local DEFAULT_FONT_PATH = "Fonts\\FRIZQT__.TTF"
local DEFAULT_BUTTON_SIZE = (addon.CONSTANTS and addon.CONSTANTS.SHELF_DEFAULT_BUTTON_SIZE) or 30
local DEFAULT_SPACING = (addon.CONSTANTS and addon.CONSTANTS.SHELF_DEFAULT_SPACING) or 2
local DEFAULT_ALPHA = (addon.CONSTANTS and addon.CONSTANTS.SHELF_DEFAULT_ALPHA) or 1.0
local DEFAULT_SCALE = (addon.CONSTANTS and addon.CONSTANTS.SHELF_DEFAULT_SCALE) or 1.0
local DEFAULT_FONT_SIZE = (addon.CONSTANTS and addon.CONSTANTS.SHELF_DEFAULT_FONT_SIZE) or 14

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

local function ResolveButtonSize(text, fontSpec, btnSize)
    local height = tonumber(btnSize) or DEFAULT_BUTTON_SIZE
    if type(text) ~= "string" or text == "" then
        return { height, height }
    end

    local fs = EnsureMeasureFontString()
    if not fs then
        return { height, height }
    end

    local currentFont, _, currentOutline = fs:GetFont()
    local outline = currentOutline or ""
    local fontPath = (fontSpec and fontSpec.path) or ResolveThemeFontPath(nil, currentFont)
    local fontSize = (fontSpec and fontSpec.size) or DEFAULT_FONT_SIZE

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

local function ResolveStatusIndicator(channelState)
    if channelState == "unjoined" then
        return {
            kind = "unjoined",
            texture = "Interface\\COMMON\\Indicator-Yellow",
            alpha = 0.95,
            textAlpha = 0.5,
        }
    end

    if channelState == "muted" then
        return {
            kind = "muted",
            texture = "Interface\\Buttons\\UI-GroupLoot-Pass-Down",
            alpha = 0.95,
            textAlpha = 0.75,
        }
    end

    return {
        kind = "none",
        texture = nil,
        alpha = 0,
        textAlpha = 1,
    }
end

local function ResolveTheme(themeKey)
    if addon.ThemeProvider and addon.ThemeProvider.GetShelfThemeProperties then
        return addon.ThemeProvider:GetShelfThemeProperties(themeKey)
    end
    if addon.GetShelfThemeProperties then
        return addon:GetShelfThemeProperties(themeKey)
    end
    return {}
end

local function BuildTooltipBindings(descriptor)
    local bindings = {}

    if descriptor.leftActionLabel then
        table.insert(bindings, {
            button = "left",
            label = descriptor.leftActionLabel,
        })
    end

    if descriptor.rightActionLabel then
        table.insert(bindings, {
            button = "right",
            label = descriptor.rightActionLabel,
        })
    end

    return bindings
end

function Resolver:Build(descriptors, context)
    local ctx = addon.Utils and addon.Utils.EnsureTable and addon.Utils.EnsureTable(context) or (type(context) == "table" and context or {})
    local themeKey = ctx.themeKey or (addon.db and addon.db.profile and addon.db.profile.shelf and addon.db.profile.shelf.theme)
    local theme = ResolveTheme(themeKey)
    local fontSpec = {
        path = ResolveThemeFontPath(theme),
        size = theme.fontSize or DEFAULT_FONT_SIZE,
    }
    local buttonBaseSize = theme.buttonSize or DEFAULT_BUTTON_SIZE
    local spacing = theme.spacing or DEFAULT_SPACING
    local alpha = theme.alpha or DEFAULT_ALPHA
    local scale = theme.scale or DEFAULT_SCALE
    local direction = ctx.direction or (addon.db and addon.db.profile and addon.db.profile.shelf and addon.db.profile.shelf.direction) or "horizontal"
    local items = {}

    for _, descriptor in ipairs(descriptors or {}) do
        local textColor = { 1, 1, 1, 1 }
        if addon.GetButtonColor then
            textColor = addon:GetButtonColor({
                type = descriptor.itemType,
                key = descriptor.itemKey,
            })
        end

        local bindings = BuildTooltipBindings(descriptor)
        local size = ResolveButtonSize(descriptor.displayText, fontSpec, buttonBaseSize)

        table.insert(items, {
            key = descriptor.key,
            text = descriptor.displayText,
            size = size,
            visual = {
                template = theme.template,
                backdrop = theme.backdrop,
                bgColor = theme.bgColor,
                borderColor = theme.borderColor,
                hoverBorderColor = theme.hoverBorderColor,
                textColor = textColor,
                fontPath = fontSpec.path,
                fontSize = fontSpec.size,
            },
            statusIndicator = ResolveStatusIndicator(descriptor.channelState),
            actions = {
                left = descriptor.leftActionKey and {
                    actionKey = descriptor.leftActionKey,
                    label = descriptor.leftActionLabel,
                } or nil,
                right = descriptor.rightActionKey and {
                    actionKey = descriptor.rightActionKey,
                    label = descriptor.rightActionLabel,
                } or nil,
            },
            tooltip = {
                mode = descriptor.tooltipMode,
                header = descriptor.fullLabel or descriptor.displayText,
                bindings = bindings,
            },
            intentItem = descriptor.intentItem,
            descriptor = descriptor,
        })
    end

    return {
        direction = direction,
        spacing = spacing,
        alpha = alpha,
        scale = scale,
        buttonBaseSize = buttonBaseSize,
        fontSpec = fontSpec,
        items = items,
    }
end
