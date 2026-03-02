local addonName, addon = ...

addon.ThemeProvider = addon.ThemeProvider or {}

local ThemeProvider = addon.ThemeProvider

function ThemeProvider:GetShelfThemeProperties(themeKey)
    themeKey = addon.Utils and addon.Utils.EnsureString
        and addon.Utils.EnsureString(themeKey, "")
        or themeKey
    if themeKey == "" then
        themeKey = nil
    end
    themeKey = themeKey
        or (addon.db and addon.db.profile and addon.db.profile.shelf and addon.db.profile.shelf.theme)
        or addon.CONSTANTS.SHELF_DEFAULT_THEME

    local props = {}
    if not addon.ThemeRegistry or not addon.ThemeRegistry.GetPreset then
        return props
    end

    local preset = addon.ThemeRegistry:GetPreset(themeKey)
    if not preset then
        preset = addon.ThemeRegistry:GetPreset(addon.CONSTANTS.SHELF_DEFAULT_THEME)
    end

    if preset and preset.properties then
        for k, v in pairs(preset.properties) do
            props[k] = v
        end

        local db = addon.db and addon.db.profile and addon.db.profile.shelf
        if db and db.themes and db.themes[themeKey] then
            for k, v in pairs(db.themes[themeKey]) do
                if type(v) ~= "table" or k == "bgColor" or k == "borderColor" or k == "hoverBorderColor" or k == "textColor" then
                    props[k] = v
                end
            end
        end
    end

    return props
end

function ThemeProvider:GetThemeProperty(prop)
    if not addon.db or not addon.db.profile or not addon.db.profile.shelf then
        return nil
    end
    local db = addon.db.profile.shelf
    local theme = db.theme or addon.CONSTANTS.SHELF_DEFAULT_THEME
    if not db.themes then db.themes = {} end
    if not db.themes[theme] then db.themes[theme] = {} end

    local val = db.themes[theme][prop]
    if val == nil then
        local preset = addon.ThemeRegistry and addon.ThemeRegistry:GetPreset(theme)
        if preset and preset.properties then
            val = preset.properties[prop]
        end
    end
    return val
end

function ThemeProvider:SetThemeProperty(prop, val)
    if not addon.db or not addon.db.profile or not addon.db.profile.shelf then
        return
    end
    local db = addon.db.profile.shelf
    local theme = db.theme or addon.CONSTANTS.SHELF_DEFAULT_THEME
    if not db.themes then db.themes = {} end
    if not db.themes[theme] then db.themes[theme] = {} end

    db.themes[theme][prop] = val
    addon:RefreshShelf()
end
