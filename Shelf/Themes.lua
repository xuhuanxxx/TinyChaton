local addonName, addon = ...
local L = addon.L

-- =========================================================================
-- Shelf Themes - 使用 ThemeRegistry 注册 Shelf 主题
-- =========================================================================

-- 注册 Modern 主题
addon.ThemeRegistry:RegisterPreset("Modern", {
    name = L["LABEL_SHELF_THEME_MODERN"],
    description = "Clean modern appearance with subtle borders",
    properties = {
        backdrop = {
            bgFile = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Buttons\\WHITE8x8",
            tile = false, tileSize = 0, edgeSize = 1,
            insets = { left = 0, right = 0, top = 0, bottom = 0 }
        },
        bgColor = {0.1, 0.1, 0.1, 0.6},
        borderColor = {0, 0, 0, 1},
        hoverBorderColor = {0.5, 0.5, 0.5, 1},
        -- 注意：textColor 不再在主题中定义，由每个按钮的 color 字段决定
        
        font = addon.CONSTANTS.SHELF_DEFAULT_FONT,
        fontSize = 14,
        scale = 1.0,
        alpha = 1.0,
        buttonSize = addon.CONSTANTS.SHELF_DEFAULT_BUTTON_SIZE,
        offset = 0,
        spacing = addon.CONSTANTS.SHELF_DEFAULT_SPACING,
        fontSize = addon.CONSTANTS.SHELF_DEFAULT_FONT_SIZE,
        font = addon.CONSTANTS.SHELF_DEFAULT_FONT,
        alpha = addon.CONSTANTS.SHELF_DEFAULT_ALPHA,
        scale = addon.CONSTANTS.SHELF_DEFAULT_SCALE,
        colorSet = addon.CONSTANTS.SHELF_DEFAULT_COLORSET,
    }
})

-- 注册 Legacy 主题
addon.ThemeRegistry:RegisterPreset("Legacy", {
    name = L["LABEL_SHELF_THEME_LEGACY"],
    description = "Classic WoW tooltip style",
    properties = {
        backdrop = {
            bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true, tileSize = 16, edgeSize = 16,
            insets = { left = 4, right = 4, top = 4, bottom = 4 }
        },
        bgColor = {0.1, 0.1, 0.1, 0.9},
        borderColor = {0.8, 0.8, 0.8, 1},
        hoverBorderColor = {1, 0.82, 0, 1},
        
        font = addon.CONSTANTS.SHELF_DEFAULT_FONT,
        fontSize = addon.CONSTANTS.SHELF_DEFAULT_FONT_SIZE,
        scale = addon.CONSTANTS.SHELF_DEFAULT_SCALE,
        alpha = addon.CONSTANTS.SHELF_DEFAULT_ALPHA,
        buttonSize = addon.CONSTANTS.SHELF_DEFAULT_BUTTON_SIZE,
        offset = 0,
        spacing = addon.CONSTANTS.SHELF_DEFAULT_SPACING,
        colorSet = "blizzard",
    }
})

-- 注册 Soft 主题
addon.ThemeRegistry:RegisterPreset("Soft", {
    name = L["LABEL_SHELF_THEME_SOFT"],
    description = "Soft rounded appearance",
    properties = {
        backdrop = {
            bgFile = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Buttons\\WHITE8x8",
            tile = false, tileSize = 0, edgeSize = 1,
            insets = { left = 0, right = 0, top = 0, bottom = 0 }
        },
        bgColor = {0.2, 0.2, 0.2, 0.5},
        borderColor = {0.3, 0.3, 0.3, 0.5},
        hoverBorderColor = {0.6, 0.6, 0.6, 0.8},
        
        font = addon.CONSTANTS.SHELF_DEFAULT_FONT,
        fontSize = 16, -- Soft theme uses slightly larger font by default, keeping it hardcoded or creating a new constant? Let's just use constant for consistency or keep 16? Plan said remove hardcoded 30/2 etc. Let's stick to using constants where values match defaults, but Soft uses 16. I will change it to constant (14) for consistency or keep it? User wants to extract "defaults". I should probably respect the theme's unique default if it differs, or standardise it. 
        -- Wait, the user asked to extract "30", "2", "1.0". 
        -- Soft uses 16. Flat uses 16.
        -- Usage: "SHELF_DEFAULT_FONT_SIZE" is 14.
        -- I will apply constant to Modern/Legacy/Retro which use 14.
        -- For Soft/Flat, I should probably keep 16 or use `addon.CONSTANTS.SHELF_DEFAULT_FONT_SIZE + 2`? Or just leave them as 16 if they are intentionally different.
        -- Plan said: "SHELF_DEFAULT_FONT_SIZE 14".
        -- I will replace standard ones.
        -- However, buttonSize 30 and spacing 2 are common.
        
        scale = addon.CONSTANTS.SHELF_DEFAULT_SCALE,
        alpha = addon.CONSTANTS.SHELF_DEFAULT_ALPHA,
        buttonSize = addon.CONSTANTS.SHELF_DEFAULT_BUTTON_SIZE,
        offset = 0,
        spacing = addon.CONSTANTS.SHELF_DEFAULT_SPACING,
        colorSet = "rainbow",
    }
})

-- 注册 Flat 主题
addon.ThemeRegistry:RegisterPreset("Flat", {
    name = L["LABEL_SHELF_THEME_FLAT"],
    description = "Flat design without borders",
    properties = {
        backdrop = {
            bgFile = "Interface\\Buttons\\WHITE8x8",
            edgeFile = nil,
            tile = false, tileSize = 0, edgeSize = 0,
            insets = { left = 0, right = 0, top = 0, bottom = 0 }
        },
        bgColor = {0.15, 0.15, 0.15, 0.8},
        borderColor = {0, 0, 0, 0},
        hoverBorderColor = {0.4, 0.4, 0.4, 1},
        
        font = addon.CONSTANTS.SHELF_DEFAULT_FONT,
        fontSize = 16,
        scale = addon.CONSTANTS.SHELF_DEFAULT_SCALE,
        alpha = addon.CONSTANTS.SHELF_DEFAULT_ALPHA,
        buttonSize = addon.CONSTANTS.SHELF_DEFAULT_BUTTON_SIZE,
        offset = 0,
        spacing = addon.CONSTANTS.SHELF_DEFAULT_SPACING,
        colorSet = "white",
    }
})

-- 注册 Retro 主题（经典红色 - UIPanelButton红色按钮样式）
addon.ThemeRegistry:RegisterPreset("Retro", {
    name = L["LABEL_SHELF_THEME_RETRO"],
    description = "Classic WoW UIPanelButton red button style",
    properties = {
        template = "UIPanelButtonTemplate",
        backdrop = nil,
        bgColor = nil,
        borderColor = nil,
        hoverBorderColor = nil,
        -- 注意：没有 textColor，文字颜色由每个按钮的 color 字段决定
        
        font = addon.CONSTANTS.SHELF_DEFAULT_FONT,
        fontSize = addon.CONSTANTS.SHELF_DEFAULT_FONT_SIZE,
        scale = addon.CONSTANTS.SHELF_DEFAULT_SCALE,
        alpha = addon.CONSTANTS.SHELF_DEFAULT_ALPHA,
        buttonSize = addon.CONSTANTS.SHELF_DEFAULT_BUTTON_SIZE,
        offset = 0,
        spacing = addon.CONSTANTS.SHELF_DEFAULT_SPACING,
        colorSet = "blizzard",
    }
})

-- 注册 Shelf 组件绑定
addon.ThemeRegistry:RegisterComponent("shelf", 
    {"Modern", "Legacy", "Soft", "Flat", "Retro"}, 
    "Modern"
)

-- =========================================================================
-- 辅助函数：获取 Shelf 当前主题属性
-- =========================================================================

function addon:GetShelfThemeProperties(themeKey)
    themeKey = themeKey or (addon.db and addon.db.plugin and addon.db.plugin.shelf and addon.db.plugin.shelf.theme) or addon.CONSTANTS.SHELF_DEFAULT_THEME
    
    local preset = addon.ThemeRegistry:GetPreset(themeKey)
    if not preset then
        preset = addon.ThemeRegistry:GetPreset(addon.CONSTANTS.SHELF_DEFAULT_THEME)
    end
    
    local props = {}
    if preset and preset.properties then
        for k, v in pairs(preset.properties) do
            props[k] = v
        end
        
        local db = addon.db and addon.db.plugin and addon.db.plugin.shelf
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

-- =========================================================================
-- 辅助函数：验证和清理主题配置
-- =========================================================================

function addon:ValidateShelfThemeConfig()
    local db = addon.db and addon.db.plugin and addon.db.plugin.shelf
    if not db then return end
    
    if not db.themes then
        db.themes = {}
    end
    
    local themes = addon.ThemeRegistry:GetComponentThemes("shelf")
    
    for _, themeKey in ipairs(themes) do
        if not db.themes[themeKey] then
            db.themes[themeKey] = {}
        end
        
        local preset = addon.ThemeRegistry:GetPreset(themeKey)
        if preset and preset.properties then
            local numericProps = {"fontSize", "scale", "alpha", "buttonSize", "offset", "spacing"}
            for _, prop in ipairs(numericProps) do
                if db.themes[themeKey][prop] == nil then
                    db.themes[themeKey][prop] = preset.properties[prop]
                end
            end
        end
    end
    
    for themeKey in pairs(db.themes) do
        local exists = false
        for _, availableTheme in ipairs(themes) do
            if availableTheme == themeKey then
                exists = true
                break
            end
        end
        if not exists then
            db.themes[themeKey] = nil
        end
    end
end
