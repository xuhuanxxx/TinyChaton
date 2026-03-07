local addonName, addon = ...

addon.ChannelRulesStrategy = addon.ChannelRulesStrategy or {}
local Strategy = addon.ChannelRulesStrategy

local lastMessage = {}
local lastAccess = {}
local cleanupCounter = 0
local CLEANUP_INTERVAL = 100
local MAX_IDLE_TIME = 300

local function CleanupOldEntries()
    local now = GetTime()
    for author, timestamp in pairs(lastAccess) do
        if now - timestamp > MAX_IDLE_TIME then
            lastMessage[author] = nil
            lastAccess[author] = nil
        end
    end
end

local function BuildNormalizedMessage(msg)
    if type(msg) ~= "string" then
        return msg
    end
    if #msg <= 4 then
        return msg
    end

    local cleanMsg = msg
    cleanMsg = cleanMsg:gsub("([^%s]+)%s+%1", "%1")
    cleanMsg = cleanMsg:gsub("([^%s]+)%s+%1", "%1")
    return cleanMsg
end

local function GetFilterModeSettings()
    if not addon.db or not addon.db.enabled then
        return nil, nil
    end
    local filterSettings = addon.db.profile and addon.db.profile.filter
    if type(filterSettings) ~= "table" then
        return nil, nil
    end
    return filterSettings.mode, filterSettings
end

local function MatchBlacklist(streamContext)
    local mode, filterSettings = GetFilterModeSettings()
    if mode ~= "blacklist" or type(filterSettings.blacklist) ~= "table" then
        return false
    end

    local cache = addon.StreamRuleMatcher and addon.StreamRuleMatcher.GetRuleCache
        and addon.StreamRuleMatcher.GetRuleCache("channel.blacklist", filterSettings.blacklist, addon.FilterVersion or 0)
    if type(cache) ~= "table" then
        return false
    end

    local authorName = streamContext.name and string.lower(streamContext.name) or ""

    if cache.names then
        for _, rule in ipairs(cache.names) do
            if addon.StreamRuleMatcher.MatchRule(streamContext.author, streamContext.authorLower, rule)
                or addon.StreamRuleMatcher.MatchRule(streamContext.name or "", authorName, rule) then
                return true
            end
        end
    end

    if cache.keywords then
        for _, rule in ipairs(cache.keywords) do
            if addon.StreamRuleMatcher.MatchRule(streamContext.text, streamContext.textLower, rule) then
                return true
            end
        end
    end

    return false
end

local function MatchWhitelistBlocked(streamContext)
    local mode, filterSettings = GetFilterModeSettings()
    if mode ~= "whitelist" or type(filterSettings.whitelist) ~= "table" then
        return false
    end

    local cache = addon.StreamRuleMatcher and addon.StreamRuleMatcher.GetRuleCache
        and addon.StreamRuleMatcher.GetRuleCache("channel.whitelist", filterSettings.whitelist, addon.FilterVersion or 0)
    if type(cache) ~= "table" then
        return false
    end

    local matched = false
    local authorName = streamContext.name and string.lower(streamContext.name) or ""

    if cache.names then
        for _, rule in ipairs(cache.names) do
            if addon.StreamRuleMatcher.MatchRule(streamContext.author, streamContext.authorLower, rule)
                or addon.StreamRuleMatcher.MatchRule(streamContext.name or "", authorName, rule) then
                matched = true
                break
            end
        end
    end

    if not matched and cache.keywords then
        for _, rule in ipairs(cache.keywords) do
            if addon.StreamRuleMatcher.MatchRule(streamContext.text, streamContext.textLower, rule) then
                matched = true
                break
            end
        end
    end

    return not matched
end

local function MatchDuplicate(streamContext)
    if not addon.db or not addon.db.enabled then return false end
    local chatContent = addon.db.profile and addon.db.profile.chat and addon.db.profile.chat.content
    if not chatContent or not chatContent.repeatFilter then return false end
    if streamContext.sourceMode ~= "realtime" then return false end

    local author = streamContext.author
    local msg = streamContext.text
    local t = GetTime()

    cleanupCounter = cleanupCounter + 1
    if cleanupCounter >= CLEANUP_INTERVAL then
        CleanupOldEntries()
        cleanupCounter = 0
    end

    local normalizedMsg = BuildNormalizedMessage(msg)
    local last = lastMessage[author]
    local window = addon.REPEAT_BLOCK_WINDOW or 10

    if last and last.msg == normalizedMsg and (t - last.time) < window then
        lastAccess[author] = t
        return true
    end

    lastMessage[author] = { msg = normalizedMsg, time = t }
    lastAccess[author] = t

    return false
end

function Strategy:Evaluate(streamContext)
    if type(streamContext) ~= "table" then
        return { blocked = false }
    end

    local blacklistMatched = MatchBlacklist(streamContext)
    local whitelistBlocked = MatchWhitelistBlocked(streamContext)
    local duplicateBlocked = MatchDuplicate(streamContext)

    local reasons = {}
    if blacklistMatched then reasons[#reasons + 1] = "channel.blacklist" end
    if whitelistBlocked then reasons[#reasons + 1] = "channel.whitelist" end
    if duplicateBlocked then reasons[#reasons + 1] = "channel.duplicate" end

    return {
        blocked = (#reasons > 0),
        reasons = reasons,
        metadataPatch = {
            blacklistMatched = blacklistMatched,
            whitelistBlocked = whitelistBlocked,
            duplicateBlocked = duplicateBlocked,
        },
    }
end

function Strategy:ClearCaches()
    lastMessage = {}
    lastAccess = {}
    cleanupCounter = 0
end

if addon.StreamRuleEngine and addon.StreamRuleEngine.RegisterKindStrategy then
    addon.StreamRuleEngine:RegisterKindStrategy("channel", Strategy)
end
