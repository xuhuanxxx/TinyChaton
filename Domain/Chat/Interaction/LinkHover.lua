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

local linkHoverHooked = false

local function OnHyperlinkEnter(self, linkData, link)
    if addon.IsFeatureEnabled and not addon:IsFeatureEnabled("LinkHover") then return end
    if addon.Can and not addon:Can(addon.CAPABILITIES.MUTATE_CHAT_DISPLAY) then return end
    if not addon.db or not addon.db.enabled or not addon.db.profile.chat or not addon.db.profile.chat.interaction or not addon.db.profile.chat.interaction.linkHover then return end
    local t = linkData:match("^(.-):")
    if linkTypes[t] then
        GameTooltip:SetOwner(self, "ANCHOR_CURSOR")
        GameTooltip:SetHyperlink(link)
        GameTooltip:Show()
    end
end

local function OnHyperlinkLeave(self)
    if addon.IsFeatureEnabled and not addon:IsFeatureEnabled("LinkHover") then return end
    if addon.Can and not addon:Can(addon.CAPABILITIES.MUTATE_CHAT_DISPLAY) then return end
    if not addon.db or not addon.db.enabled or not addon.db.profile.chat or not addon.db.profile.chat.interaction or not addon.db.profile.chat.interaction.linkHover then return end
    GameTooltip:Hide()
end

function addon:InitLinkHover()
    local function HookFrames()
        if linkHoverHooked then return end
        for i = 1, NUM_CHAT_WINDOWS do
            local frame = _G["ChatFrame"..i]
            if frame then
                frame:HookScript("OnHyperlinkEnter", OnHyperlinkEnter)
                frame:HookScript("OnHyperlinkLeave", OnHyperlinkLeave)
            end
        end
        linkHoverHooked = true
    end

    local function EnableLinkHover()
        HookFrames()
    end

    local function DisableLinkHover()
        -- HookScript is not reversible, so disable via runtime guards in callbacks.
    end

    if addon.RegisterFeature then
        addon:RegisterFeature("LinkHover", {
            requires = { "MUTATE_CHAT_DISPLAY" },
            onEnable = EnableLinkHover,
            onDisable = DisableLinkHover,
        })
    else
        EnableLinkHover()
    end
end

addon:RegisterModule("LinkHover", addon.InitLinkHover)
