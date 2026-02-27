local addonName, addon = ...

-- =========================================================================
-- Middleware: Whitelist
-- Stage: FILTER
-- Priority: 21
-- Description: Blocks messages NOT in whitelist rules (Strict Mode)
-- =========================================================================

-- Rule cache
local ruleCache = {
    names = nil,
    keywords = nil,
    version = 0,
}

local function IsPatternSafe(pattern)
    if not pattern then return false end
    local len = #pattern
    if len > 100 then return false end

    local _, count = pattern:gsub("[%%%(%)%.%[%]%*%+%-%?%$%^]", "")
    if count > 20 then return false end

    return true
end

local function IsLuaPattern(pattern)
    if not pattern or pattern == "" then return false end
    if not IsPatternSafe(pattern) then return false end
    if not string.find(pattern, "[%^%$%(%)%%%.%[%]%*%+%-%?]") then return false end
    local success = pcall(function() return string.match("", pattern) end)
    return success
end

local function PreprocessRules(ruleList)
    if not ruleList then return nil end
    local processed = {}
    for _, rule in pairs(ruleList) do
        if rule and rule ~= "" then
            table.insert(processed, {
                pattern = rule,
                patternLower = string.lower(rule),
                isRegex = IsLuaPattern(rule),
            })
        end
    end
    return processed
end

local function GetRuleCache()
    -- Check if we are in whitelist mode
    if not addon.db or not addon.db.plugin.filter or addon.db.plugin.filter.mode ~= "whitelist" then
        return nil
    end

    local config = addon.db.plugin.filter.whitelist
    if not config then return nil end

    local currentVersion = addon.FilterVersion or 0
    if ruleCache.version ~= currentVersion or not ruleCache.names then
        ruleCache.names = PreprocessRules(config.names)
        ruleCache.keywords = PreprocessRules(config.keywords)
        ruleCache.version = currentVersion
    end

    return ruleCache
end

local function MatchRule(text, textLower, rule)
    if rule.isRegex then
        local success, result = pcall(string.match, text, rule.pattern)
        if success and result then return true end
    end
    -- Plain text match
    if string.find(textLower, rule.patternLower, 1, true) then
        return true
    end
    return false
end

addon.Filters = addon.Filters or {}

function addon.Filters.WhitelistProcess(chatData)
    -- Early exit if not enabled or not in whitelist mode
    if not addon.db or not addon.db.enabled then return false end
    local filterSettings = addon.db.plugin and addon.db.plugin.filter
    if not filterSettings or filterSettings.mode ~= "whitelist" then return false end

    local cache = GetRuleCache()
    if not cache then return false end

    local matched = false
    local authorName = chatData.name and string.lower(chatData.name) or ""

    -- 1. Check Names
    if cache.names then
        for _, rule in ipairs(cache.names) do
            if MatchRule(chatData.author, chatData.authorLower, rule) or
               MatchRule(chatData.name or "", authorName, rule) then
                matched = true
                break
            end
        end
    end

    -- 2. Check Keywords (if not already matched)
    if not matched and cache.keywords then
        for _, rule in ipairs(cache.keywords) do
            if MatchRule(chatData.text, chatData.textLower, rule) then
                matched = true
                break
            end
        end
    end

    -- Whitelist logic: Block if NOT matched
    if not matched then
        return true -- Block
    end

    return false
end

local function WhitelistMiddleware(chatData)
    if not chatData then return false end
    chatData.metadata = chatData.metadata or {}
    chatData.metadata.whitelistBlocked = addon.Filters.WhitelistProcess(chatData) == true
    return false
end

function addon:InitWhitelistMiddleware()
    local function EnableWhitelist()
        if addon.EventDispatcher and not addon.EventDispatcher:IsMiddlewareRegistered("FILTER", "Whitelist") then
            addon.EventDispatcher:RegisterMiddleware("FILTER", 21, "Whitelist", WhitelistMiddleware)
        end
    end

    local function DisableWhitelist()
        if addon.EventDispatcher then
            addon.EventDispatcher:UnregisterMiddleware("FILTER", "Whitelist")
        end
    end

    if addon.RegisterFeature then
        addon:RegisterFeature("Whitelist", {
            requires = { "READ_CHAT_EVENT", "PROCESS_CHAT_DATA" },
            onEnable = EnableWhitelist,
            onDisable = DisableWhitelist,
        })
    else
        EnableWhitelist()
    end
end

addon:RegisterModule("WhitelistMiddleware", addon.InitWhitelistMiddleware)
