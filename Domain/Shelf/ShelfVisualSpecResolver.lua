local addonName, addon = ...

addon.ShelfVisualSpecResolver = addon.ShelfVisualSpecResolver or {}

local Resolver = addon.ShelfVisualSpecResolver

function Resolver:ResolveButtonVisualSpec(item, context)
    local ctx = addon.Utils and addon.Utils.EnsureTable and addon.Utils.EnsureTable(context) or (type(context) == "table" and context or {})
    local themeProps = {}

    if addon.ThemeProvider and addon.ThemeProvider.GetShelfThemeProperties then
        themeProps = addon.ThemeProvider:GetShelfThemeProperties(ctx.themeKey)
    elseif addon.GetShelfThemeProperties then
        themeProps = addon:GetShelfThemeProperties(ctx.themeKey)
    end

    local textColor = { 1, 1, 1, 1 }
    if item and addon.GetButtonColor then
        textColor = addon:GetButtonColor(item)
    end
    local alpha = themeProps.alpha or 1.0
    local scale = themeProps.scale or 1.0

    return {
        themeProps = themeProps,
        textColor = textColor,
        alpha = alpha,
        scale = scale,
        font = themeProps.font,
    }
end
