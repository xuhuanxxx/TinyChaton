local addonName, addon = ...

addon.RuleMatcher = addon.RuleMatcher or {}
local RuleMatcher = addon.RuleMatcher

local MODE_CACHES = {
    blacklist = { names = nil, keywords = nil, version = 0 },
    whitelist = { names = nil, keywords = nil, version = 0 },
}

local function RuleCount(rules)
    return (type(rules) == "table" and #rules) or 0
end

function RuleMatcher.ClearCache(mode, reason)
    local modeCache = MODE_CACHES[mode]
    if not modeCache then
        return false
    end

    modeCache.names = nil
    modeCache.keywords = nil
    modeCache.version = 0

    if addon.Debug then
        addon:Debug("RuleMatcher cache cleared: %s (reason=%s)", tostring(mode), tostring(reason or "manual"))
    end
    return true
end

function RuleMatcher.ClearAllCaches(reason)
    local cleared = 0
    for mode in pairs(MODE_CACHES) do
        if RuleMatcher.ClearCache(mode, reason) then
            cleared = cleared + 1
        end
    end
    return cleared
end

function RuleMatcher.GetCacheStats()
    local stats = {}
    for mode, modeCache in pairs(MODE_CACHES) do
        stats[mode] = {
            version = modeCache.version,
            namesCount = RuleCount(modeCache.names),
            keywordsCount = RuleCount(modeCache.keywords),
        }
    end
    return stats
end

function RuleMatcher.IsPatternSafe(pattern)
    if not pattern then return false end
    local len = #pattern
    if len > 100 then return false end

    local _, count = pattern:gsub("[%%%(%)%.%[%]%*%+%-%?%$%^]", "")
    if count > 20 then return false end

    return true
end

function RuleMatcher.IsLuaPattern(pattern)
    if not pattern or pattern == "" then return false end
    if not RuleMatcher.IsPatternSafe(pattern) then return false end

    if not string.find(pattern, "[%^%$%(%)%%%.%[%]%*%+%-%?]") then
        return false
    end
    local success = pcall(function() return string.match("", pattern) end)
    return success
end

function RuleMatcher.PreprocessRules(ruleList)
    if not ruleList then return nil end
    local processed = {}
    for _, rule in pairs(ruleList) do
        if rule and rule ~= "" then
            processed[#processed + 1] = {
                pattern = rule,
                patternLower = string.lower(rule),
                isRegex = RuleMatcher.IsLuaPattern(rule),
            }
        end
    end
    return processed
end

function RuleMatcher.MatchRule(text, textLower, rule)
    if rule.isRegex then
        local success, result = pcall(string.match, text, rule.pattern)
        if success and result then return true end
    end

    if string.find(textLower, rule.patternLower, 1, true) then
        return true
    end
    return false
end

function RuleMatcher.GetRuleCache(mode, config, currentVersion)
    local modeCache = MODE_CACHES[mode]
    if not modeCache or type(config) ~= "table" then
        return nil
    end

    if modeCache.version ~= currentVersion or not modeCache.names then
        modeCache.names = RuleMatcher.PreprocessRules(config.names)
        modeCache.keywords = RuleMatcher.PreprocessRules(config.keywords)
        modeCache.version = currentVersion
    end

    return modeCache
end
