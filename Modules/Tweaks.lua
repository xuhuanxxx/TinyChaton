local addonName, addon = ...
local L = addon.L

addon.Tweaks = {}

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

function addon.Tweaks:InitLinkHover()
    for i = 1, NUM_CHAT_WINDOWS do
        local frame = _G["ChatFrame"..i]
        if frame then
            frame:HookScript("OnHyperlinkEnter", OnHyperlinkEnter)
            frame:HookScript("OnHyperlinkLeave", OnHyperlinkLeave)
        end
    end
end

-- 系统频道轮换顺序
local systemCycleOrder = {
    "SAY", "PARTY", "RAID", "INSTANCE_CHAT", "GUILD", "YELL"
}

-- 归一化 chatType：PARTY_LEADER -> PARTY, INSTANCE_CHAT_LEADER -> INSTANCE_CHAT
local function NormalizeChatType(t)
    if not t then return "SAY" end
    if t == "PARTY_LEADER" then return "PARTY" end
    if t == "RAID_LEADER" then return "RAID" end
    if t == "INSTANCE_CHAT_LEADER" then return "INSTANCE_CHAT" end
    return t
end

-- 获取已加入的动态频道列表
local function GetJoinedDynamicChannels()
    local channelList = { GetChannelList() }
    local joined = {}
    for i = 1, #channelList, 3 do
        local id, name = channelList[i], channelList[i + 1]
        if id and name then
            joined[#joined + 1] = { id = id, name = name }
        end
    end
    return joined
end

-- 构建当前可用的频道轮换列表
local function BuildCycleList()
    local list = {}
    
    -- 添加可用的系统频道
    for _, channel in ipairs(systemCycleOrder) do
        if channel == "SAY" or channel == "YELL" then
            list[#list + 1] = { chatType = channel }
        elseif channel == "PARTY" and IsInGroup() then
            list[#list + 1] = { chatType = channel }
        elseif channel == "RAID" and IsInRaid() then
            list[#list + 1] = { chatType = channel }
        elseif channel == "INSTANCE_CHAT" and IsInGroup(LE_PARTY_CATEGORY_INSTANCE) then
            list[#list + 1] = { chatType = channel }
        elseif channel == "GUILD" and IsInGuild() then
            list[#list + 1] = { chatType = channel }
        end
    end
    
    -- 添加已加入的动态频道
    local joinedChannels = GetJoinedDynamicChannels()
    for _, ch in ipairs(joinedChannels) do
        list[#list + 1] = { chatType = "CHANNEL", channelTarget = ch.id, channelName = ch.name }
    end
    
    return list
end

-- 查找当前频道在轮换列表中的位置
local function FindCurrentIndex(list, currentType, currentTarget)
    currentType = NormalizeChatType(currentType)
    for i, entry in ipairs(list) do
        if entry.chatType == "CHANNEL" then
            if currentType == "CHANNEL" and entry.channelTarget == currentTarget then
                return i
            end
        else
            if entry.chatType == currentType then
                return i
            end
        end
    end
    return 0
end

-- 获取下一个频道
local function GetNextChannel(currentType, currentTarget)
    local list = BuildCycleList()
    if #list == 0 then
        return { chatType = "SAY" }
    end
    
    local currentIdx = FindCurrentIndex(list, currentType, currentTarget)
    local nextIdx = (currentIdx % #list) + 1
    return list[nextIdx]
end

local function OnTabPressed(self)
    if not addon.db or not addon.db.enabled or not addon.db.plugin.chat or not addon.db.plugin.chat.interaction or not addon.db.plugin.chat.interaction.tabCycle then return end
    local text = self:GetText()
    if text:sub(1, 1) ~= "/" then return end
    
    -- 获取当前频道类型（兼容新旧 API）
    local currentType = self:GetAttribute("chatType") or self.chatType
    local currentTarget = self:GetAttribute("channelTarget") or self.channelTarget
    if currentType == "CHANNEL" and type(currentTarget) == "string" then
        currentTarget = tonumber(currentTarget)
    end
    
    local next = GetNextChannel(currentType, currentTarget)
    if not next then return end
    
    -- 使用 SetAttribute 和 ChatEdit_UpdateHeader 正确切换频道
    self:SetAttribute("chatType", next.chatType)
    
    if next.chatType == "CHANNEL" then
        -- 动态频道需要设置 channelTarget
        self:SetAttribute("channelTarget", next.channelTarget)
    else
        -- 非动态频道清除 channelTarget
        self:SetAttribute("channelTarget", nil)
    end
    
    ChatEdit_UpdateHeader(self)
    self:SetText("")  -- 清空输入，保留频道切换
end

-- Store delayed timer reference for cancellation
local delayedHookTimer = nil

function addon.Tweaks:InitTabCycle()
    local function HookEditBox(editBox)
        if not editBox or editBox._TinyChatonTabCycleHooked then return end
        editBox._TinyChatonTabCycleHooked = true
        editBox:HookScript("OnTabPressed", OnTabPressed)
    end
    
    -- 优先使用 ChatFrame1EditBox（Retail 共享 EditBox）
    if ChatFrame1EditBox then
        HookEditBox(ChatFrame1EditBox)
    end
    
    -- 兼容多聊天框：遍历 ChatFrame.editBox 和 ChatFrame*EditBox
    for i = 1, NUM_CHAT_WINDOWS do
        local cf = _G["ChatFrame"..i]
        if cf and cf.editBox then
            HookEditBox(cf.editBox)
        end
        local eb = _G["ChatFrame"..i.."EditBox"]
        if eb then
            HookEditBox(eb)
        end
    end
    
    -- 延迟再尝试一次（EditBox 可能尚未创建）- save timer reference
    delayedHookTimer = C_Timer.NewTimer(1, function()
        delayedHookTimer = nil
        if ChatFrame1EditBox and not ChatFrame1EditBox._TinyChatonTabCycleHooked then
            HookEditBox(ChatFrame1EditBox)
        end
        for i = 1, NUM_CHAT_WINDOWS do
            local cf = _G["ChatFrame"..i]
            if cf and cf.editBox and not cf.editBox._TinyChatonTabCycleHooked then
                HookEditBox(cf.editBox)
            end
        end
    end)
end

-- Cancel delayed hook timer
function addon:CancelTweaksTimer()
    if delayedHookTimer then
        delayedHookTimer:Cancel()
        delayedHookTimer = nil
    end
end

function addon:InitTweaks()
    if not addon.Tweaks then return end
    addon.Tweaks:InitLinkHover()
    addon.Tweaks:InitTabCycle()
end
