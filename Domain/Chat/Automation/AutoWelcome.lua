local addonName, addon = ...
local CF = _G["Create" .. "Frame"]

-- =========================================================================
-- Module: AutoWelcome
-- Explicit state machine for automated guild/party/raid welcome messages.
-- =========================================================================

local state = {
    featureEnabled = false,
    listenerEnabled = false,
    pendingByKey = {},
    lastSentAtByKey = {},
    patternByScene = {},
}

local function EscapeLuaPattern(text)
    if type(text) ~= "string" then return "" end
    return (text:gsub("([%(%)%.%%%+%-%*%?%[%]%^%$])", "%%%1"))
end

local function buildPattern(formatStr)
    if type(formatStr) ~= "string" or formatStr == "" then return nil end
    local token = "\001TINYCHATON_NAME\001"
    local withToken = formatStr:gsub("%%s", token)
    local escaped = EscapeLuaPattern(withToken)
    escaped = escaped:gsub(token, "(.+)")
    local pattern = "^" .. escaped .. "$"
    if not pcall(string.match, "", pattern) then
        return nil
    end
    return pattern
end

local function getSceneFormatString(scene)
    if scene == "guild" then
        return ERR_GUILD_JOIN_S
    elseif scene == "party" then
        return ERR_PARTY_MEMBER_JOINED_S
    elseif scene == "raid" then
        return ERR_RAID_MEMBER_ADDED_S
    end
    return nil
end

local function getScenePattern(scene)
    if state.patternByScene[scene] ~= nil then
        return state.patternByScene[scene] or nil
    end
    local pattern = buildPattern(getSceneFormatString(scene))
    state.patternByScene[scene] = pattern or false
    return pattern
end

local function normalizePlayerName(name)
    if type(name) ~= "string" then return nil, nil end
    local trimmed = name:match("^%s*(.-)%s*$")
    if not trimmed or trimmed == "" then return nil, nil end
    local lowered = (strlower and strlower(trimmed)) or string.lower(trimmed)
    return trimmed, lowered
end

local function makeWelcomeKey(scene, normalizedLowerName)
    if not scene or not normalizedLowerName then return nil end
    return scene .. ":" .. normalizedLowerName
end

local function getAutomationConfig()
    if not addon.db or not addon.db.profile then return nil end
    return addon.db.profile.automation
end

local function getWelcomeRoot()
    local automation = getAutomationConfig()
    return automation and automation.welcome or nil
end

local function isCapabilityReady()
    if not addon.Can then return true end
    return addon:Can(addon.CAPABILITIES.READ_CHAT_EVENT) and addon:Can(addon.CAPABILITIES.EMIT_CHAT_ACTION)
end

local function isWelcomeEnabled()
    local welcome = getWelcomeRoot()
    return welcome and welcome.enabled == true
end

local function getSceneConfig(scene)
    local automation = getAutomationConfig()
    if not automation then return nil end
    if scene == "guild" then return automation.welcomeGuild end
    if scene == "party" then return automation.welcomeParty end
    if scene == "raid" then return automation.welcomeRaid end
    return nil
end

local function isSceneAvailable(scene)
    if scene == "guild" then
        return IsInGuild()
    elseif scene == "party" then
        return IsInGroup() and not IsInRaid()
    elseif scene == "raid" then
        return IsInRaid()
    end
    return false
end

local function hasWelcomePermission(scene)
    if scene == "party" or scene == "raid" then
        return UnitIsGroupLeader("player")
    end
    return true
end

local function getJoinedPlayer(msg, scene)
    local pattern = getScenePattern(scene)
    if not pattern then return nil end
    return msg:match(pattern)
end

local function cancelPendingTimer(key)
    local timer = state.pendingByKey[key]
    if timer and timer.Cancel then
        timer:Cancel()
    end
    state.pendingByKey[key] = nil
end

local function emitWelcome(playerName, scene, key)
    if not addon.db or not addon.db.enabled then return end
    if not isCapabilityReady() or not isWelcomeEnabled() then return end
    if not hasWelcomePermission(scene) then return end

    local cfg = getSceneConfig(scene)
    if not cfg or not cfg.enabled then return end
    if type(cfg.templates) ~= "table" or #cfg.templates == 0 then return end

    local line = cfg.templates[math.random(#cfg.templates)]
    local text = (line or ""):gsub("%%s", playerName)
    if text == "" then return end

    local useWhisper = (cfg.sendMode == "whisper")
    if useWhisper then
        addon:EmitChatMessage(text, "WHISPER", nil, playerName)
    elseif scene == "guild" and isSceneAvailable("guild") then
        addon:EmitChatMessage(text, "GUILD")
    elseif scene == "party" and isSceneAvailable("party") then
        addon:EmitChatMessage(text, "PARTY")
    elseif scene == "raid" and isSceneAvailable("raid") then
        addon:EmitChatMessage(text, "RAID")
    else
        return
    end

    state.lastSentAtByKey[key] = time()
end

local function scheduleWelcome(playerName, scene)
    if not addon.db or not addon.db.enabled then return end
    if not isCapabilityReady() or not isWelcomeEnabled() then return end
    if not hasWelcomePermission(scene) then return end

    local cfg = getSceneConfig(scene)
    if not cfg or not cfg.enabled then return end
    if type(cfg.templates) ~= "table" or #cfg.templates == 0 then return end

    local normalizedName, lowerName = normalizePlayerName(playerName)
    if not normalizedName or not lowerName then return end

    local key = makeWelcomeKey(scene, lowerName)
    if not key then return end

    local automation = getAutomationConfig()
    local welcome = automation and automation.welcome or {}
    local cooldownMin = welcome.cooldownMinutes or 0
    if cooldownMin > 0 then
        local last = state.lastSentAtByKey[key] or 0
        if (time() - last) < (cooldownMin * 60) then
            return
        end
    end

    cancelPendingTimer(key)
    state.pendingByKey[key] = C_Timer.NewTimer(math.random(2, 5), function()
        state.pendingByKey[key] = nil

        local automationNow = getAutomationConfig()
        local welcomeNow = automationNow and automationNow.welcome or {}
        local cooldownNow = welcomeNow.cooldownMinutes or 0
        if cooldownNow > 0 then
            local last = state.lastSentAtByKey[key] or 0
            if (time() - last) < (cooldownNow * 60) then
                return
            end
        end

        emitWelcome(normalizedName, scene, key)
    end)
end

local function enableListener()
    if state.listenerEnabled then return end
    if not addon.AutoWelcomeListener then
        addon.AutoWelcomeListener = CF("Frame")
        addon.AutoWelcomeListener:SetScript("OnEvent", function(_, event, msg)
            if event ~= "CHAT_MSG_SYSTEM" then return end
            if type(msg) ~= "string" or msg == "" then return end
            if not isCapabilityReady() or not isWelcomeEnabled() then return end

            local player = getJoinedPlayer(msg, "guild")
            if player then
                scheduleWelcome(player, "guild")
                return
            end

            player = getJoinedPlayer(msg, "party")
            if player then
                scheduleWelcome(player, "party")
                return
            end

            player = getJoinedPlayer(msg, "raid")
            if player then
                scheduleWelcome(player, "raid")
            end
        end)
    end

    if not addon.AutoWelcomeListener:IsEventRegistered("CHAT_MSG_SYSTEM") then
        addon.AutoWelcomeListener:RegisterEvent("CHAT_MSG_SYSTEM")
    end
    state.listenerEnabled = true
end

local function disableListener()
    if addon.AutoWelcomeListener and addon.AutoWelcomeListener:IsEventRegistered("CHAT_MSG_SYSTEM") then
        addon.AutoWelcomeListener:UnregisterEvent("CHAT_MSG_SYSTEM")
    end
    state.listenerEnabled = false
    addon:CancelPendingWelcomeTimers()
end

function addon:CancelPendingWelcomeTimers()
    for key, timer in pairs(state.pendingByKey) do
        if timer and timer.Cancel then
            timer:Cancel()
        end
        state.pendingByKey[key] = nil
    end
end

function addon:ApplyAutoWelcomeSettings()
    local shouldEnable = addon.db
        and addon.db.enabled
        and state.featureEnabled
        and isCapabilityReady()
        and isWelcomeEnabled()

    if shouldEnable then
        enableListener()
    else
        disableListener()
    end
end

function addon:InitAutoWelcome()
    if addon.RegisterFeature then
        addon:RegisterFeature("AutoWelcome", {
            requires = { "READ_CHAT_EVENT", "EMIT_CHAT_ACTION" },
            onEnable = function()
                state.featureEnabled = true
                addon:ApplyAutoWelcomeSettings()
            end,
            onDisable = function()
                state.featureEnabled = false
                addon:ApplyAutoWelcomeSettings()
            end,
        })
    else
        state.featureEnabled = true
        addon:ApplyAutoWelcomeSettings()
    end
end

addon:RegisterModule("AutoWelcome", addon.InitAutoWelcome)
