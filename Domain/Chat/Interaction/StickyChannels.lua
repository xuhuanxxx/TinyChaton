local addonName, addon = ...
local L = addon.L

-- =========================================================================
-- Module: StickyChannels
-- Description: Manages sticky channel settings (remembering last channel)
-- =========================================================================

addon.StickyChannels = {}

local function UpdateSticky()
    if not addon.db or not addon.db.profile.chat or not addon.db.profile.chat.interaction then return end
    local enabled = addon.db.profile.chat.interaction.sticky
    local types = { "SAY", "YELL", "EMOTE", "PARTY", "RAID", "GUILD", "OFFICER", "CHANNEL", "WHISPER", "BN_WHISPER" }
    for _, t in ipairs(types) do
        if ChatTypeInfo[t] then
            ChatTypeInfo[t].sticky = enabled and 1 or 0
        end
    end
end
addon.ApplyStickyChannelSettings = UpdateSticky

local stickyEditBoxHooked = false
local function HookEditBoxForSticky()
    if stickyEditBoxHooked then return end
    stickyEditBoxHooked = true
    local function hookEditBox(editBox)
        if not editBox or editBox._TinyChatonStickyHooked then return end
        editBox._TinyChatonStickyHooked = true
        editBox:HookScript("OnShow", function()
            if addon.db and addon.db.profile.chat and addon.db.profile.chat.interaction and addon.db.profile.chat.interaction.sticky then
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

function addon:InitStickyChannels()
    UpdateSticky()
    HookEditBoxForSticky()

    if addon:GetConfig("profile.chat.interaction.sticky", true) and C_Timer and C_Timer.After then
        C_Timer.After(2, function()
            if addon:GetConfig("profile.chat.interaction.sticky", true) then
                UpdateSticky()
            end
        end)
    end
end

addon:RegisterModule("StickyChannels", addon.InitStickyChannels)
