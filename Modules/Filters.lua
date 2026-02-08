local addonName, addon = ...
local L = addon.L

local lastMessage = {}

-- Rule cache: preprocessed rules with isRegex flag
local ruleCache = {
    blockNames = nil,
    blockKeywords = nil,
    version = 0,
}

-- Check if a pattern is actually a Lüa pattern (contains special characters)
local function IsLuaPattern(pattern)
    if not pattern or pattern == "" then return false end
    -- If it doesn't contain any magic characters, it's not a pattern we need string.match for
    if not string.find(pattern, "[%^%$%(%)%%%.%[%]%*%+%-%?]") then
        return false
    end
    local success = pcall(function() return string.match("", pattern) end)
    return success
end

-- Preprocess rules: determine if each rule is regex or plain text
local function PreprocessRules(ruleList)
    if not ruleList then return nil end
    local processed = {}
    for _, rule in pairs(ruleList) do
        if rule and rule ~= "" then
            local isRegex = IsLuaPattern(rule)
            table.insert(processed, {
                pattern = rule,
                patternLower = string.lower(rule),
                isRegex = isRegex,
            })
        end
    end
    return processed
end

-- Get or rebuild rule cache
local function GetRuleCache()
    local blockConfig = addon.db and addon.db.plugin.filter and addon.db.plugin.filter.block
    if not blockConfig then return nil end
    
    -- Simple version check: rebuild if config tables changed
    -- Use a combined string hash or just the concat of all words as version?
    -- Actually, simpler: just use a unique counter that increments on ApplyFilterSettings
    local currentVersion = addon.FilterVersion or 0
    
    if ruleCache.version ~= currentVersion or not ruleCache.blockNames then
        ruleCache.blockNames = PreprocessRules(blockConfig.names)
        ruleCache.blockKeywords = PreprocessRules(blockConfig.keywords)
        ruleCache.version = currentVersion
    end
    
    return ruleCache
end

-- Invalidate cache (call when config changes)
function addon:InvalidateFilterCache()
    ruleCache.version = -1
    ruleCache.blockNames = nil
    ruleCache.blockKeywords = nil
    addon.FilterVersion = (addon.FilterVersion or 0) + 1
end

-- Match a single preprocessed rule against text
local function MatchRule(text, textLower, rule)
    if rule.isRegex then
        local success, result = pcall(string.match, text, rule.pattern)
        if success and result then return true end
    end
    -- Plain text fallback (case-insensitive)
    if string.find(textLower, rule.patternLower, 1, true) then
        return true
    end
    return false
end

-- Capture phase: Check if matches capture rules based on content/sender
-- Uses preprocessed cache for better performance
local function CaptureMessage(msg, author, namesList, keywordsList)
    if not namesList and not keywordsList then
        return { matched = false }
    end
    
    local body = msg or ""
    local sender = author or ""
    local bodyLower = string.lower(body)
    local senderLower = string.lower(sender)
    
    local result = {
        matched = false,
        nameMatched = false,
        keywordMatched = false,
        matchedNames = {},
        matchedKeywords = {},
    }
    
    -- Check name match using preprocessed rules
    if namesList then
        for _, rule in ipairs(namesList) do
            if MatchRule(sender, senderLower, rule) then
                result.matched = true
                result.nameMatched = true
                table.insert(result.matchedNames, rule.pattern)
            end
        end
    end
    
    -- Check keyword match using preprocessed rules
    if keywordsList then
        for _, rule in ipairs(keywordsList) do
            if MatchRule(body, bodyLower, rule) then
                result.matched = true
                result.keywordMatched = true
                table.insert(result.matchedKeywords, rule.pattern)
            end
        end
    end
    
    return result
end

-- Decision phase: Decide action based on capture and config
local function ShouldBlock(captureResult, blockConfig)
    if not blockConfig.enabled then
        return false
    end
    
    local shouldBlock = false
    
    -- Check if should be blocked
    if captureResult.nameMatched then
        shouldBlock = true
    end
    if captureResult.keywordMatched then
        shouldBlock = true
    end
    
    -- Inverse logic: Block if not matched (Whitelist Mode)
    if blockConfig.inverse then
        return not captureResult.matched
    end
    
    return shouldBlock
end

local function StripRedundantSenderPrefix(self, event, msg, author, ...)
    if not addon.db or not addon.db.enabled then return false, msg, author, ... end
    if not msg or type(msg) ~= "string" or msg == "" then return false, msg, author, ... end
    local sayColon = L["LABEL_PATTERN_STRIP_SAY"]
    local colon = L["LABEL_PATTERN_STRIP_COLON"]
    local rest = msg:match("^%[%[%d+%] [^%]]+%]" .. sayColon .. " ?(.*)$")
    if rest then return false, rest, author, ... end
    rest = msg:match("^%[%[%d+%] [^%]]+%]" .. colon .. " ?(.*)$")
    if rest then return false, rest, author, ... end
    return false, msg, author, ...
end

local function FilterFunc(self, event, msg, author, ...)
    if not addon.db or not addon.db.enabled then
        return false, msg, author, ...
    end
    
    local blockConfig = addon.db.plugin.filter.block
    
    -- Check blocking (if enabled) - use preprocessed cache
    if blockConfig and blockConfig.enabled then
        local cache = GetRuleCache()
        if cache then
            local captureResult = CaptureMessage(msg, author, cache.blockNames, cache.blockKeywords)
            if ShouldBlock(captureResult, blockConfig) then
                return true -- Block message
            end
        end
    end
    
    -- Duplicate message filtering (standalone)
    if addon.db.plugin.filter.repeatFilter then
        local t = GetTime()
        local last = lastMessage[author]
        
        local window = addon.REPEAT_FILTER_WINDOW or 10
        if last and last.msg == msg and (t - last.time) < window then
            return true -- Treated as duplicate, block
        end
        
        -- Clean duplicate characters
        local len = #msg
        if len > 4 then
            local cleanMsg = msg
            cleanMsg = cleanMsg:gsub("([^%s]+)%s+%1", "%1")
            cleanMsg = cleanMsg:gsub("([^%s]+)%s+%1", "%1")
            
            if cleanMsg ~= msg then
                lastMessage[author] = { msg = cleanMsg, time = t }
                return false, cleanMsg, author, ...
            end
        end
        
        lastMessage[author] = { msg = msg, time = t }
    end
    
    return false, msg, author, ...
end

function addon:InitFilters()
    local events = addon.CHAT_EVENTS or {}
    -- Fallback if CHAT_EVENTS is empty
    if #events == 0 and addon.STREAM_REGISTRY then
        for _, category in pairs(addon.STREAM_REGISTRY.CHANNEL or {}) do
            for _, stream in ipairs(category) do
                if stream.events then
                    for _, ev in ipairs(stream.events) do
                        table.insert(events, ev)
                    end
                end
            end
        end
    end
    
    for _, event in ipairs(events) do
        ChatFrame_AddMessageEventFilter(event, StripRedundantSenderPrefix)
        ChatFrame_AddMessageEventFilter(event, FilterFunc)
    end
end

function addon:ApplyFilterSettings()
    addon:InvalidateFilterCache()
end
