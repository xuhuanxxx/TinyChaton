local addonName, addon = ...

addon.StreamRuleMatcher = addon.StreamRuleMatcher or {}
local Matcher = addon.StreamRuleMatcher

local NAMESPACE_CACHES = {}

local function RuleCount(rules)
    return (type(rules) == "table" and #rules) or 0
end

function Matcher.ClearCache(namespace, reason)
    if type(namespace) ~= "string" or namespace == "" then
        return false
    end

    NAMESPACE_CACHES[namespace] = nil

    if addon.Debug then
        addon:Debug("StreamRuleMatcher cache cleared: %s (reason=%s)", tostring(namespace), tostring(reason or "manual"))
    end
    return true
end

function Matcher.ClearAllCaches(reason)
    local cleared = 0
    for namespace in pairs(NAMESPACE_CACHES) do
        NAMESPACE_CACHES[namespace] = nil
        cleared = cleared + 1
    end
    if addon.Debug then
        addon:Debug("StreamRuleMatcher all caches cleared (count=%s, reason=%s)", tostring(cleared), tostring(reason or "manual"))
    end
    return cleared
end

function Matcher.GetCacheStats()
    local stats = {}
    for namespace, cache in pairs(NAMESPACE_CACHES) do
        stats[namespace] = {
            version = cache.version,
            namesCount = RuleCount(cache.names),
            keywordsCount = RuleCount(cache.keywords),
        }
    end
    return stats
end

function Matcher.IsPatternSafe(pattern)
    if not pattern then return false end
    local len = #pattern
    if len > 100 then return false end

    local _, count = pattern:gsub("[%%%(%)%.%[%]%*%+%-%?%$%^]", "")
    if count > 20 then return false end

    return true
end

function Matcher.IsLuaPattern(pattern)
    if not pattern or pattern == "" then return false end
    if not Matcher.IsPatternSafe(pattern) then return false end

    if not string.find(pattern, "[%^%$%(%)%%%.%[%]%*%+%-%?]") then
        return false
    end
    local success = pcall(function() return string.match("", pattern) end)
    return success
end

function Matcher.PreprocessRules(ruleList)
    if not ruleList then return nil end
    local processed = {}
    for _, rule in pairs(ruleList) do
        if rule and rule ~= "" then
            processed[#processed + 1] = {
                pattern = rule,
                patternLower = string.lower(rule),
                isRegex = Matcher.IsLuaPattern(rule),
            }
        end
    end
    return processed
end

function Matcher.MatchRule(text, textLower, rule)
    if rule.isRegex then
        local success, result = pcall(string.match, text, rule.pattern)
        if success and result then return true end
    end

    if string.find(textLower, rule.patternLower, 1, true) then
        return true
    end
    return false
end

function Matcher.GetRuleCache(namespace, config, currentVersion)
    if type(namespace) ~= "string" or namespace == "" or type(config) ~= "table" then
        return nil
    end

    local cache = NAMESPACE_CACHES[namespace]
    if type(cache) ~= "table" then
        cache = { names = nil, keywords = nil, version = 0 }
        NAMESPACE_CACHES[namespace] = cache
    end

    if cache.version ~= currentVersion or cache.names == nil then
        cache.names = Matcher.PreprocessRules(config.names)
        cache.keywords = Matcher.PreprocessRules(config.keywords)
        cache.version = currentVersion
    end

    return cache
end
