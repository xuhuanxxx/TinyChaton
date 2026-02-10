local addonName, addon = ...

-- =========================================================================
-- Module: AutoWelcome
-- Automatically sends welcome messages when players join guild/party/raid
-- =========================================================================

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
    -- Note: RecursiveSync now handles function defaults automatically,
    -- so templates will be a table here.
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

--- Greeting Middleware (PRE_PROCESS stage)
--- Detects player join messages and sends automated greetings
local function OnSystemMessage(self, event, msg)
    -- P0: Config Access
    if not addon:GetConfig("plugin.automation", true) then return end
    if not msg then return end

    -- Check each scene
    local player = getJoinedPlayer(msg, "guild")
    if player then
        trySendWelcome(player, "guild")
        return
    end

    player = getJoinedPlayer(msg, "party")
    if player then
        trySendWelcome(player, "party")
        return
    end

    player = getJoinedPlayer(msg, "raid")
    if player then
        trySendWelcome(player, "raid")
        return
    end
end

function addon:InitAutoWelcome()
    if addon.AutoWelcomeListener then return end
    
    local listener = CreateFrame("Frame")
    listener:RegisterEvent("CHAT_MSG_SYSTEM")
    listener:SetScript("OnEvent", OnSystemMessage)
    
    addon.AutoWelcomeListener = listener
end

-- P0: Register Module
addon:RegisterModule("AutoWelcome", addon.InitAutoWelcome)
