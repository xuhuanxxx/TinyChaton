local addonName, addon = ...
local CF = _G["Create" .. "Frame"]

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
    if addon.Can and not addon:Can(addon.CAPABILITIES.EMIT_CHAT_ACTION) then
        return
    end
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
        -- Belt-and-suspenders for delayed callback: policy may change after timer creation.
        if addon.Can and not addon:Can(addon.CAPABILITIES.EMIT_CHAT_ACTION) then
            return
        end
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
            addon:EmitChatMessage(text, "WHISPER", nil, playerName)
        elseif scene == "guild" and IsInGuild() then
            addon:EmitChatMessage(text, "GUILD")
        elseif scene == "party" and IsInGroup() and not IsInRaid() then
            addon:EmitChatMessage(text, "PARTY")
        elseif scene == "raid" and IsInRaid() then
            addon:EmitChatMessage(text, "RAID")
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
    if addon.Can then
        -- Belt-and-suspenders: listener is managed by FeatureRegistry,
        -- but keep runtime checks for safety under async/policy drift.
        if not addon:Can(addon.CAPABILITIES.READ_CHAT_EVENT) then
            return
        end
        if not addon:Can(addon.CAPABILITIES.EMIT_CHAT_ACTION) then
            return
        end
    end
    if not addon:GetConfig("plugin.automation", true) then return end
    if type(msg) ~= "string" or msg == "" then return end

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
    local function EnableAutoWelcomeListener()
        if not addon.AutoWelcomeListener then
            addon.AutoWelcomeListener = CF("Frame")
            addon.AutoWelcomeListener:SetScript("OnEvent", OnSystemMessage)
        end

        if not addon.AutoWelcomeListener:IsEventRegistered("CHAT_MSG_SYSTEM") then
            addon.AutoWelcomeListener:RegisterEvent("CHAT_MSG_SYSTEM")
        end
    end

    local function DisableAutoWelcomeListener()
        if addon.AutoWelcomeListener and addon.AutoWelcomeListener:IsEventRegistered("CHAT_MSG_SYSTEM") then
            addon.AutoWelcomeListener:UnregisterEvent("CHAT_MSG_SYSTEM")
        end
        addon:CancelPendingWelcomeTimers()
    end

    if addon.RegisterFeature then
        addon:RegisterFeature("AutoWelcome", {
            requires = { "READ_CHAT_EVENT", "EMIT_CHAT_ACTION" },
            onEnable = EnableAutoWelcomeListener,
            onDisable = DisableAutoWelcomeListener,
        })
    else
        EnableAutoWelcomeListener()
    end
end

addon:RegisterModule("AutoWelcome", addon.InitAutoWelcome)
