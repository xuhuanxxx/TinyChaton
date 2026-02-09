local addonName, addon = ...

-- =========================================================================
-- Middleware: Blacklist
-- Stage: FILTER
-- Priority: 20
-- Description: Blocks messages based on blacklist rules
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
    if len > 100 then return false end -- Length check

    -- Complexity check: count special characters
    -- If > 30% of characters are special, it might be complex/malicious
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
    -- Check if we are in blacklist mode
    if not addon.db or not addon.db.plugin.filter or addon.db.plugin.filter.mode ~= "blacklist" then
        return nil 
    end
    
    local config = addon.db.plugin.filter.blacklist
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

local function BlacklistMiddleware(chatData)
    -- Early exit if not enabled or not in blacklist mode
    if not addon.db or not addon.db.enabled then return end
    local filterSettings = addon.db.plugin and addon.db.plugin.filter
    if not filterSettings or filterSettings.mode ~= "blacklist" then return end
    
    local cache = GetRuleCache()
    if not cache then return end
    
    -- 1. Check Names
    if cache.names then
        for _, rule in ipairs(cache.names) do
            -- Match against raw author or pure name
            if MatchRule(chatData.author, chatData.authorLower, rule) or 
               MatchRule(chatData.name, string.lower(chatData.name), rule) then
                return true -- Block
            end
        end
    end
    
    -- 2. Check Keywords
    if cache.keywords then
        for _, rule in ipairs(cache.keywords) do
            if MatchRule(chatData.text, chatData.textLower, rule) then
                return true -- Block
            end
        end
    end
    
    return false
end

addon.EventDispatcher:RegisterMiddleware("FILTER", 20, "Blacklist", BlacklistMiddleware)
