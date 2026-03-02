local addonName, addon = ...

addon.Filters = addon.Filters or {}

local function GetRuleCache()
    if not addon.db or not addon.db.profile.filter or addon.db.profile.filter.mode ~= "whitelist" then
        return nil
    end

    local config = addon.db.profile.filter.whitelist
    if not config then return nil end

    return addon.RuleMatcher.GetRuleCache("whitelist", config, addon.FilterVersion or 0)
end

function addon.Filters.WhitelistProcess(chatData)
    if not addon.db or not addon.db.enabled then return false end
    local filterSettings = addon.db.profile and addon.db.profile.filter
    if not filterSettings or filterSettings.mode ~= "whitelist" then return false end

    local cache = GetRuleCache()
    if not cache then return false end

    local matched = false
    local authorName = chatData.name and string.lower(chatData.name) or ""

    if cache.names then
        for _, rule in ipairs(cache.names) do
            if addon.RuleMatcher.MatchRule(chatData.author, chatData.authorLower, rule) or
               addon.RuleMatcher.MatchRule(chatData.name or "", authorName, rule) then
                matched = true
                break
            end
        end
    end

    if not matched and cache.keywords then
        for _, rule in ipairs(cache.keywords) do
            if addon.RuleMatcher.MatchRule(chatData.text, chatData.textLower, rule) then
                matched = true
                break
            end
        end
    end

    return not matched
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
            plane = addon.RUNTIME_PLANES and addon.RUNTIME_PLANES.CHAT_DATA or "CHAT_DATA",
            onEnable = EnableWhitelist,
            onDisable = DisableWhitelist,
        })
    else
        EnableWhitelist()
    end
end

addon:RegisterModule("WhitelistMiddleware", addon.InitWhitelistMiddleware)
