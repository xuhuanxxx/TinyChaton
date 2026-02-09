local addonName, addon = ...
local L = addon.L

-- =========================================================================
-- Module: LinkHover
-- Description: Shows tooltip when hovering over links in chat
-- =========================================================================

addon.LinkHover = {}

local linkTypes = {
    item = true, spell = true, unit = true, quest = true, enchant = true,
    achievement = true, instancelock = true, talent = true, glyph = true,
    azessence = true, mawpower = true, conduit = true, mount = true, pet = true,
    currency = true, battlepet = true, transmogappearance = true, journal = true, toy = true,
}

local function OnHyperlinkEnter(self, linkData, link)
    if not addon.db or not addon.db.enabled or not addon.db.plugin.chat or not addon.db.plugin.chat.interaction or not addon.db.plugin.chat.interaction.linkHover then return end
    local t = linkData:match("^(.-):")
    if linkTypes[t] then
        GameTooltip:SetOwner(self, "ANCHOR_CURSOR")
        GameTooltip:SetHyperlink(link)
        GameTooltip:Show()
    end
end

local function OnHyperlinkLeave(self)
    if not addon.db or not addon.db.enabled or not addon.db.plugin.chat or not addon.db.plugin.chat.interaction or not addon.db.plugin.chat.interaction.linkHover then return end
    GameTooltip:Hide()
end

function addon:InitLinkHover()
    for i = 1, NUM_CHAT_WINDOWS do
        local frame = _G["ChatFrame"..i]
        if frame then
            frame:HookScript("OnHyperlinkEnter", OnHyperlinkEnter)
            frame:HookScript("OnHyperlinkLeave", OnHyperlinkLeave)
        end
    end
end
