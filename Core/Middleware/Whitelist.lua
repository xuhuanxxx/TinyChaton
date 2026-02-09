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

local function IsLuaPattern(pattern)
    if not pattern or pattern == "" then return false end
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

local function WhitelistMiddleware(chatData)
    -- Early exit if not enabled or not in whitelist mode
    if not addon.db or not addon.db.enabled then return end
    local filterSettings = addon.db.plugin and addon.db.plugin.filter
    if not filterSettings or filterSettings.mode ~= "whitelist" then return end

    local cache = GetRuleCache()
    if not cache then return end

    local matched = false

    -- 1. Check Names
    if cache.names then
        for _, rule in ipairs(cache.names) do
            if MatchRule(chatData.author, chatData.authorLower, rule) or
               MatchRule(chatData.name, string.lower(chatData.name), rule) then
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

addon.EventDispatcher:RegisterMiddleware("FILTER", 21, "Whitelist", WhitelistMiddleware)
