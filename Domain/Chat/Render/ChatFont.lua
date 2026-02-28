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

    local font = addon.db.profile.chat.font.font
    local size = addon:GetSettingValue("fontSize")
    local outline = addon:GetSettingValue("fontOutline")

    -- Resolve standard font if needed
    local standardFont, standardSize, standardOutline = ChatFontNormal:GetFont()
    
    if font == "Default" or font == "STANDARD" then font = nil end
    if font and addon.FONT_PATHS[font] then font = addon.FONT_PATHS[font] end

    -- If no custom font is set, fallback to standard game font
    -- IMPORTANT: Do not fallback to 'currentFont', as that might be the custom font we want to remove
    if not font then 
        font = standardFont 
    end

    -- If size is not set (shouldn't happen with slider), fallback to standard
    if not size then size = standardSize end
    
    -- Outline handling
    if outline == "NONE" then 
        outline = "" 
    elseif not outline then
        outline = standardOutline
    end

    for i = 1, NUM_CHAT_WINDOWS do
        local cf = _G["ChatFrame"..i]
        if cf then
            local currentFont, currentSize, currentOutline = cf:GetFont()
            
            -- Check if we really need to update to avoid spamming SetFont
            if font ~= currentFont or size ~= currentSize or outline ~= currentOutline then
                cf:SetFont(font, size, outline)
            end
        end
    end
end
-- Keep global reference for external calls (e.g. from Settings)
addon.ApplyChatFontSettings = ApplyChatFontSettings

function addon:InitChatFont()
    ApplyChatFontSettings()
end

addon:RegisterModule("ChatFont", addon.InitChatFont)
