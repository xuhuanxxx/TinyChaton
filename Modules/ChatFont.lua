local addonName, addon = ...
local L = addon.L

-- =========================================================================
-- Module: ChatFont
-- Description: Manages chat frame font settings
-- =========================================================================

addon.ChatFont = {}

addon.FONT_PATHS = {
    Default = nil,
}

local function ApplyChatFontSettings()
    if not addon.db then return end
    
    -- Use registry value for managed toggle
    if not addon:GetSettingValue("fontManaged") then return end
    
    local font = addon.db.plugin.chat.font.font
    local size = addon:GetSettingValue("fontSize")
    local outline = addon:GetSettingValue("fontOutline")
    
    if font == "Default" then font = nil end
    if font and addon.FONT_PATHS[font] then font = addon.FONT_PATHS[font] end
    
    -- We should only apply if there's something to apply
    if not font and not size and not outline then return end

    for i = 1, NUM_CHAT_WINDOWS do
        local cf = _G["ChatFrame"..i]
        if cf then
            local currentFont, currentSize, currentOutline = cf:GetFont()
            local newFont = font or currentFont
            local newSize = size or currentSize
            local newOutline = (outline == "NONE") and "" or (outline or currentOutline)
            if newFont ~= currentFont or newSize ~= currentSize or newOutline ~= currentOutline then
                cf:SetFont(newFont, newSize, newOutline)
            end
        end
    end
end
-- Keep global reference for external calls (e.g. from Settings)
addon.ApplyChatFontSettings = ApplyChatFontSettings

function addon:InitChatFont()
    ApplyChatFontSettings()
end
