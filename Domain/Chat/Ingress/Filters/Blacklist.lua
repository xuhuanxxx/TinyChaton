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
        if addon.EventDispatcher and not addon.EventDispatcher:IsMiddlewareRegistered("FILTER", "Blacklist") then
            addon.EventDispatcher:RegisterMiddleware("FILTER", 20, "Blacklist", BlacklistMiddleware)
        end
    end

    local function DisableBlacklist()
        if addon.EventDispatcher then
            addon.EventDispatcher:UnregisterMiddleware("FILTER", "Blacklist")
        end
    end

    if addon.RegisterFeature then
        addon:RegisterFeature("Blacklist", {
            requires = { "READ_CHAT_EVENT", "PROCESS_CHAT_DATA" },
            plane = addon.RUNTIME_PLANES and addon.RUNTIME_PLANES.CHAT_DATA or "CHAT_DATA",
            onEnable = EnableBlacklist,
            onDisable = DisableBlacklist,
        })
    else
        EnableBlacklist()
    end
end

addon:RegisterModule("BlacklistMiddleware", addon.InitBlacklistMiddleware)
