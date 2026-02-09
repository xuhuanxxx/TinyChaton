local addonName, addon = ...
local L = addon.L

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
addon.ApplyChatFontSettings = ApplyChatFontSettings

local function UpdateSticky()
    if not addon.db or not addon.db.plugin.chat or not addon.db.plugin.chat.interaction then return end
    local enabled = addon.db.plugin.chat.interaction.sticky
    local types = { "SAY", "YELL", "EMOTE", "PARTY", "RAID", "GUILD", "OFFICER", "CHANNEL" }
    for _, t in ipairs(types) do
        if ChatTypeInfo[t] then
            ChatTypeInfo[t].sticky = enabled and 1 or 0
        end
    end
end

local stickyEditBoxHooked
local function HookEditBoxForSticky()
    if stickyEditBoxHooked then return end
    stickyEditBoxHooked = true
    local function hookEditBox(editBox)
        if not editBox or editBox._TinyChatonStickyHooked then return end
        editBox._TinyChatonStickyHooked = true
        editBox:HookScript("OnShow", function()
            if addon.db and addon.db.plugin.chat and addon.db.plugin.chat.interaction and addon.db.plugin.chat.interaction.sticky then
                UpdateSticky()
            end
        end)
    end
    if ChatFrame1EditBox then hookEditBox(ChatFrame1EditBox) end
    for i = 1, NUM_CHAT_WINDOWS do
        local cf = _G["ChatFrame"..i]
        if cf and cf.editBox then hookEditBox(cf.editBox) end
        local eb = _G["ChatFrame"..i.."EditBox"]
        if eb then hookEditBox(eb) end
    end
end

local function ApplyChatVisualSettings()
    UpdateSticky()
    if addon.ApplyChannelNameHooks then
        addon:ApplyChannelNameHooks()
    end
end
addon.ApplyChatVisualSettings = ApplyChatVisualSettings

-- Use addon.Utils.NormalizeChannelBaseName for normalization

local function GetJoinedChannelNameById(id)
    if not id then return nil end
    local list = { GetChannelList() }
    for i = 1, #list, 3 do
        if list[i] == id then
            return list[i + 1]
        end
    end
    return nil
end

local CHAT_TYPE_TO_LKEY = {
    CHAT_GUILD_GET = "STREAM_GUILD_SHORT", CHAT_OFFICER_GET = "STREAM_OFFICER_SHORT",
    CHAT_PARTY_GET = "STREAM_PARTY_SHORT", CHAT_PARTY_LEADER_GET = "STREAM_PARTY_SHORT", CHAT_MONSTER_PARTY_GET = "STREAM_PARTY_SHORT", CHAT_PARTY_GUIDE_GET = "STREAM_INSTANCE_SHORT",
    CHAT_RAID_GET = "STREAM_RAID_SHORT", CHAT_RAID_LEADER_GET = "STREAM_RAID_SHORT", CHAT_RAID_WARNING_GET = "STREAM_RAID_SHORT",
    CHAT_INSTANCE_CHAT_GET = "STREAM_INSTANCE_SHORT", CHAT_INSTANCE_CHAT_LEADER_GET = "STREAM_INSTANCE_SHORT",
}
-- Channel abbreviation logic moved to Modules/ChannelAbbreviation.lua

function addon:InitVisual()
    addon:ApplyChatVisualSettings()
    addon:ApplyChatFontSettings()
end

-- Hook management for channel name functions
function addon:ApplyChannelNameHooks()
    -- This function is now a no-op as channel name hooks are managed by ChannelAbbreviation module
end

function addon:ApplyChatVisualSettings()
    -- Delegate channel abbreviation to the new module
    if addon.ChannelAbbreviation then
        addon.ChannelAbbreviation:Init()
    end

    UpdateSticky()
    HookEditBoxForSticky()
    if addon.db and addon.db.plugin.chat and addon.db.plugin.chat.interaction and addon.db.plugin.chat.interaction.sticky and C_Timer and C_Timer.After then
        C_Timer.After(2, function()
            if addon.db and addon.db.plugin.chat and addon.db.plugin.chat.interaction and addon.db.plugin.chat.interaction.sticky then
                UpdateSticky()
            end
        end)
    end
end

function addon:ApplyVisualSettings()
    addon:ApplyChatVisualSettings()
    addon:ApplyChatFontSettings()
end
