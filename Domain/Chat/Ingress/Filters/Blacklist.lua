local addonName, addon = ...

addon.Filters = addon.Filters or {}

local function GetRuleCache()
    if not addon.db or not addon.db.profile.filter or addon.db.profile.filter.mode ~= "blacklist" then
        return nil
    end

    local config = addon.db.profile.filter.blacklist
    if not config then return nil end

    return addon.RuleMatcher.GetRuleCache("blacklist", config, addon.FilterVersion or 0)
end

function addon.Filters.BlacklistProcess(chatData)
    if not addon.db or not addon.db.enabled then return false end
    local filterSettings = addon.db.profile and addon.db.profile.filter
    if not filterSettings or filterSettings.mode ~= "blacklist" then return false end
    local streamKey = chatData and chatData.streamKey
    if type(streamKey) ~= "string" or streamKey == "" then return false end
    if addon.GetStreamKind and addon:GetStreamKind(streamKey) ~= "channel" then
        return false
    end

    local cache = GetRuleCache()
    if not cache then return false end

    local authorName = chatData.name and string.lower(chatData.name) or ""

    if cache.names then
        for _, rule in ipairs(cache.names) do
            if addon.RuleMatcher.MatchRule(chatData.author, chatData.authorLower, rule) or
               addon.RuleMatcher.MatchRule(chatData.name or "", authorName, rule) then
                return true
            end
        end
    end

    if cache.keywords then
        for _, rule in ipairs(cache.keywords) do
            if addon.RuleMatcher.MatchRule(chatData.text, chatData.textLower, rule) then
                return true
            end
        end
    end

    return false
end

local function BlacklistMiddleware(chatData)
    if not chatData then return false end
    chatData.metadata = chatData.metadata or {}
    chatData.metadata.blacklistMatched = addon.Filters.BlacklistProcess(chatData) == true
    return false
end

function addon:InitBlacklistMiddleware()
    local function EnableBlacklist()
        if addon.ChatPipeline and not addon.ChatPipeline:IsMiddlewareRegistered("BLOCK", "Blacklist") then
            addon.ChatPipeline:RegisterMiddleware("BLOCK", 20, "Blacklist", BlacklistMiddleware)
        end
    end

    local function DisableBlacklist()
        if addon.ChatPipeline then
            addon.ChatPipeline:UnregisterMiddleware("BLOCK", "Blacklist")
        end
    end

    addon:RegisterFeature("Blacklist", {
        requires = { "READ_CHAT_EVENT", "PROCESS_CHAT_DATA" },
        plane = addon.RUNTIME_PLANES and addon.RUNTIME_PLANES.CHAT_DATA or "CHAT_DATA",
        onEnable = EnableBlacklist,
        onDisable = DisableBlacklist,
    })
end

addon:RegisterModule("BlacklistMiddleware", addon.InitBlacklistMiddleware)
