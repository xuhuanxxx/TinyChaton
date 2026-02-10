local addonName, addon = ...
local L = addon.L

-- =========================================================================
-- AnchorRegistry - 锚点位置注册表
-- 管理 Shelf 的可停靠位置
-- =========================================================================

addon.AnchorRegistry = {}
local AR = addon.AnchorRegistry

-- Constants (Lazy accessed inside functions to ensure Config.lua is loaded)
local function GetTabYOffset()
    return (addon.CONSTANTS and addon.CONSTANTS.SHELF_ANCHOR_OFFSET_TAB_Y) or 6
end

local function GetEditBoxYOffset()
    return (addon.CONSTANTS and addon.CONSTANTS.SHELF_ANCHOR_OFFSET_EDITBOX_Y) or 0
end

AR.anchors = {
    {
        name = "chat_top",
        isValid = function()
            local chatTab = _G.ChatFrame1Tab
            local chatFrame = _G.ChatFrame1
            -- STRICT: Must be visible AND have dimensions
            return chatTab and chatTab:IsVisible() and (chatTab:GetWidth() or 0) > 0
               and chatFrame and chatFrame:IsVisible()
        end,
        apply = function(self)
            local chatFrame = _G.ChatFrame1
            local chatTab = _G.ChatFrame1Tab
            local chatLeft = chatFrame:GetLeft() or 0
            local tabLeft = chatTab:GetLeft() or 0
            local xOffset = chatLeft - tabLeft
            self:SetPoint("BOTTOMLEFT", chatTab, "TOPLEFT", xOffset, GetTabYOffset())
        end
    },
    {
        name = "input_top",
        isValid = function()
            local editBox = _G.ChatFrame1EditBox
            return editBox and editBox:IsVisible() and (editBox:GetWidth() or 0) > 0
        end,
        apply = function(self)
            local editBox = _G.ChatFrame1EditBox
            self:SetPoint("BOTTOMLEFT", editBox, "TOPLEFT", 0, GetEditBoxYOffset())
        end
    },
    {
        name = "input_bottom",
        isValid = function()
            local editBox = _G.ChatFrame1EditBox
            return editBox and editBox:IsVisible() and (editBox:GetWidth() or 0) > 0
        end,
        apply = function(self)
            local editBox = _G.ChatFrame1EditBox
            -- Aligned to left of edit box instead of center
            self:SetPoint("TOPLEFT", editBox, "BOTTOMLEFT", 0, GetEditBoxYOffset())
        end
    },
    {
        name = "social_right",
        isValid = function()
            local q = QuickJoinToastButton
            return q and q:IsVisible() and (q:GetWidth() or 0) > 0
        end,
        apply = function(self)
            self:SetPoint("LEFT", QuickJoinToastButton, "RIGHT", 4, 0)
        end
    },
    {
        name = "fallback_frame",
        isValid = function()
            local chatFrame = _G.ChatFrame1
            return chatFrame and chatFrame:IsVisible() and (chatFrame:GetWidth() or 0) > 0
        end,
        apply = function(self)
            local chatFrame = _G.ChatFrame1
            self:SetPoint("BOTTOMLEFT", chatFrame, "TOPLEFT", 0, GetTabYOffset())
        end
    }
}

--- 获取所有注册的锚点配置
function AR:GetAnchors()
    return self.anchors
end
