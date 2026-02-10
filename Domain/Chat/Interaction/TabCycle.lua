local addonName, addon = ...
local L = addon.L

-- =========================================================================
-- Module: TabCycle
-- Description: Cycles through available channels using TAB key
-- =========================================================================

addon.TabCycle = {}

-- System channel cycle order
local systemCycleOrder = {
    "SAY", "PARTY", "RAID", "INSTANCE_CHAT", "GUILD", "YELL"
}

-- Normalize chatType: PARTY_LEADER -> PARTY, INSTANCE_CHAT_LEADER -> INSTANCE_CHAT
local function NormalizeChatType(t)
    if not t then return "SAY" end
    if t == "PARTY_LEADER" then return "PARTY" end
    if t == "RAID_LEADER" then return "RAID" end
    if t == "INSTANCE_CHAT_LEADER" then return "INSTANCE_CHAT" end
    return t
end

-- Get joined dynamic channels
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

-- Build current cycle list
local function BuildCycleList()
    local list = {}

    -- Add available system channels
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

    -- Add joined dynamic channels
    local joinedChannels = GetJoinedDynamicChannels()
    for _, ch in ipairs(joinedChannels) do
        list[#list + 1] = { chatType = "CHANNEL", channelTarget = ch.id, channelName = ch.name }
    end

    return list
end

-- Find current index in cycle list
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

-- Get next channel
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
    if addon.IsFeatureEnabled and not addon:IsFeatureEnabled("TabCycle") then return end
    if addon.Can and not addon:Can(addon.CAPABILITIES.MUTATE_CHAT_DISPLAY) then return end
    if not addon.db or not addon.db.enabled or not addon.db.plugin.chat or not addon.db.plugin.chat.interaction or not addon.db.plugin.chat.interaction.tabCycle then return end
    local text = self:GetText()
    if text:sub(1, 1) ~= "/" then return end

    -- Get current chat type (compatible with modern/legacy API)
    local currentType = self:GetAttribute("chatType") or self.chatType
    local currentTarget = self:GetAttribute("channelTarget") or self.channelTarget
    if currentType == "CHANNEL" and type(currentTarget) == "string" then
        currentTarget = tonumber(currentTarget)
    end

    local next = GetNextChannel(currentType, currentTarget)
    if not next then return end

    -- Use SetAttribute and ChatEdit_UpdateHeader to switch channel correctly
    self:SetAttribute("chatType", next.chatType)

    if next.chatType == "CHANNEL" then
        -- Dynamic channel needs channelTarget
        self:SetAttribute("channelTarget", next.channelTarget)
    else
        -- Non-dynamic channel clears channelTarget
        self:SetAttribute("channelTarget", nil)
    end

    ChatEdit_UpdateHeader(self)
    self:SetText("")  -- Clear input while keeping the target channel.
end

-- Store delayed timer reference for cancellation
local delayedHookTimer = nil

function addon:InitTabCycle()
    local function HookEditBox(editBox)
        if not editBox or editBox._TinyChatonTabCycleHooked then return end
        editBox._TinyChatonTabCycleHooked = true
        editBox:HookScript("OnTabPressed", OnTabPressed)
    end

    local function HookAllEditBoxes()
        -- Prioritize ChatFrame1EditBox (Retail shared EditBox).
        if ChatFrame1EditBox then
            HookEditBox(ChatFrame1EditBox)
        end

        -- Compatibility loop: ChatFrame.editBox and ChatFrame*EditBox.
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
    end
    local function EnableTabCycle()
        HookAllEditBoxes()
    end

    local function DisableTabCycle()
        -- HookScript is not reversible, so disable via runtime guards in callbacks.
    end

    if addon.RegisterFeature then
        addon:RegisterFeature("TabCycle", {
            requires = { "MUTATE_CHAT_DISPLAY" },
            onEnable = EnableTabCycle,
            onDisable = DisableTabCycle,
        })
    else
        EnableTabCycle()
    end

    -- Retry with delay in case edit boxes were created late.
    delayedHookTimer = C_Timer.NewTimer(1, function()
        delayedHookTimer = nil
        HookAllEditBoxes()
    end)
end

addon:RegisterModule("TabCycle", addon.InitTabCycle)

-- Cancel delayed hook timer
function addon:CancelTabCycleTimer()
    if delayedHookTimer then
        delayedHookTimer:Cancel()
        delayedHookTimer = nil
    end
end
