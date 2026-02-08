local addonName, addon = ...

addon.Social = {}

local lastWelcome = {}
local pendingWelcomeTimers = {}

local function buildPattern(formatStr)
    if not formatStr or type(formatStr) ~= "string" then return nil end
    return formatStr:gsub("%%s", "(.+)")
end

local function getJoinedPlayer(msg, scene)
    local pattern
    if scene == "guild" and ERR_GUILD_JOIN_S then
        pattern = buildPattern(ERR_GUILD_JOIN_S)
    elseif scene == "party" then
        if ERR_PARTY_MEMBER_JOINED_S then
            pattern = buildPattern(ERR_PARTY_MEMBER_JOINED_S)
        else
            pattern = "(.+) joins the party"
        end
    elseif scene == "raid" then
        if ERR_RAID_MEMBER_ADDED_S then
            pattern = buildPattern(ERR_RAID_MEMBER_ADDED_S)
        else
            pattern = "(.+) has joined the raid"
        end
    end
    if pattern then
        return msg:match(pattern)
    end
    return nil
end

local function trySendWelcome(playerName, scene)
    if not addon.db or not addon.db.enabled then return end
    local c = addon.db.plugin.automation
    local cfg = scene == "guild" and c.welcomeGuild or scene == "party" and c.welcomeParty or c.welcomeRaid
    if not cfg or not cfg.enabled then return end
    
    -- Handle templates as function or table
    local templates = cfg.templates
    if type(templates) == "function" then
        templates = templates()
    end
    if not templates or type(templates) ~= "table" then return end
    
    -- Check permissions: party/raid requires leader, guild does not
    if scene == "party" or scene == "raid" then
        if not UnitIsGroupLeader("player") then
            return
        end
    end
    local n = #templates
    if n == 0 then return end
    local cooldownMin = c.welcomeCooldownMinutes or 0
    if cooldownMin > 0 then
        local last = lastWelcome[playerName] or 0
        if (time() - last) < cooldownMin * 60 then return end
    end
    local line = templates[math.random(n)]
    local text = (line or ""):gsub("%%s", playerName)
    if text == "" then return end
    local useWhisper = (cfg.sendMode == "whisper")
    local chatType = (useWhisper and "WHISPER") or (scene == "guild" and "GUILD") or (scene == "party" and "PARTY") or "RAID"
    local timerKey = playerName .. "_" .. scene
    local timer = C_Timer.NewTimer(math.random(2, 5), function()
        pendingWelcomeTimers[timerKey] = nil
        -- Re-check settings before sending (user may have disabled)
        if not addon.db or not addon.db.plugin.automation then return end
        local cfgNow = scene == "guild" and addon.db.plugin.automation.welcomeGuild or scene == "party" and addon.db.plugin.automation.welcomeParty or addon.db.plugin.automation.welcomeRaid
        if not cfgNow or not cfgNow.enabled then return end
        
        -- Re-check permissions (may have lost leader status during delay)
        if scene == "party" or scene == "raid" then
            if not UnitIsGroupLeader("player") then
                return
            end
        end
        
        if chatType == "WHISPER" then
            SendChatMessage(text, "WHISPER", nil, playerName)
        elseif scene == "guild" and IsInGuild() then
            SendChatMessage(text, "GUILD")
        elseif scene == "party" and IsInGroup() and not IsInRaid() then
            SendChatMessage(text, "PARTY")
        elseif scene == "raid" and IsInRaid() then
            SendChatMessage(text, "RAID")
        else
            return
        end
        lastWelcome[playerName] = time()
    end)
    pendingWelcomeTimers[timerKey] = timer
end

-- Cancel all pending welcome timers
function addon:CancelPendingWelcomeTimers()
    for key, timer in pairs(pendingWelcomeTimers) do
        if timer and timer.Cancel then
            timer:Cancel()
        end
        pendingWelcomeTimers[key] = nil
    end
end

local function AutoWelcomeFilter(self, event, msg, ...)
    if not addon.db or not addon.db.enabled or not addon.db.plugin.automation then return false, msg, ... end
    local player
    player = getJoinedPlayer(msg, "guild")
    if player then
        trySendWelcome(player, "guild")
        return false, msg, ...
    end
    player = getJoinedPlayer(msg, "party")
    if player then
        trySendWelcome(player, "party")
        return false, msg, ...
    end
    player = getJoinedPlayer(msg, "raid")
    if player then
        trySendWelcome(player, "raid")
        return false, msg, ...
    end
    return false, msg, ...
end

function addon:ApplyAutomationSettings()
    -- Reserved for future automation-level sync if needed
end

function addon:InitSocial()
    local f = CreateFrame("Frame")
    f:RegisterEvent("CHAT_MSG_SYSTEM")
    f:SetScript("OnEvent", function(self, event, arg1)
        AutoWelcomeFilter(self, event, arg1)
    end)
end

-- Auto Join Channels Configuration Helpers

function addon:GetAutoJoinChannelsItems()
    local items = {}
    for _, reg in ipairs(addon.CHANNEL_REGISTRY) do
        if reg.isDynamic then
            table.insert(items, { 
                key = reg.key, 
                label = reg.label or reg.key,
                value = reg.key,
                text = reg.label or reg.key,
            })
        end
    end
    return items
end

function addon:GetAutoJoinChannelSelection()
    if not self.db or not self.db.plugin.automation or not self.db.plugin.automation.autoJoinChannels then 
        return {}
    end
    local ajc = self.db.plugin.automation.autoJoinChannels
    local items = self:GetAutoJoinChannelsItems()
    local selection = {}
    for _, item in ipairs(items) do
        selection[item.key] = (ajc[item.key] ~= false)
    end
    return selection
end

function addon:SetAutoJoinChannelSelection(selection)
    if not self.db or not self.db.plugin.automation then 
        return
    end
    if not self.db.plugin.automation.autoJoinChannels then
        self.db.plugin.automation.autoJoinChannels = {}
    end
    local ajc = self.db.plugin.automation.autoJoinChannels
    local items = self:GetAutoJoinChannelsItems()
    
    for _, item in ipairs(items) do
        ajc[item.key] = selection[item.key] and true or false
    end
    
    if addon.ApplyAllSettings then addon:ApplyAllSettings() end
end
