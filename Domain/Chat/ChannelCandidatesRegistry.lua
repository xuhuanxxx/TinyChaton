local addonName, addon = ...

addon.ChannelCandidatesRegistry = addon.ChannelCandidatesRegistry or {}

local function GetLocaleKey(locale)
    if type(locale) == "string" and locale ~= "" then
        return locale
    end
    return (type(GetLocale) == "function" and GetLocale()) or "enUS"
end

local function Canonicalize(name)
    local resolver = addon.ChannelSemanticResolver
    if resolver and type(resolver.Canonicalize) == "function" then
        return resolver.Canonicalize(name)
    end
    return nil
end

local function TrimName(name)
    if type(name) ~= "string" then return nil end
    local out = name:match("^%s*(.-)%s*$")
    if not out or out == "" then return nil end
    return out
end

addon.CHANNEL_CANDIDATES = {
    default = {
        general = "General",
        trade = "Trade",
        localdefense = "LocalDefense",
        services = "Service",
        lfg = "LFG",
        world = "World",
    },
    zhCN = {
        general = "综合",
        trade = "交易",
        localdefense = "本地防务",
        services = "服务",
        lfg = "寻求组队",
        world = "大脚世界频道",
    },
    zhTW = {
        general = "綜合",
        trade = "交易",
        localdefense = "本地防務",
        services = "服務",
        lfg = "尋求組隊",
        world = "世界頻道",
    },
    enUS = {
        general = "General",
        trade = "Trade",
        localdefense = "LocalDefense",
        services = "Service",
        lfg = "LFG",
        world = "World",
    },
}

addon.CHANNEL_CANDIDATE_ALIASES = {
    default = {},
    zhCN = {
        services = { "交易（服务）" },
    },
    zhTW = {
        services = { "交易（服務）" },
    },
    enUS = {
        services = { "Trade (Services)" },
    },
}

local function ResolveMappedName(locale, candidatesId)
    local all = addon.CHANNEL_CANDIDATES or {}
    local defaultBucket = all.default or {}
    local localeBucket = all[locale] or {}
    local raw = localeBucket[candidatesId]
    if raw == nil then
        raw = defaultBucket[candidatesId]
    end
    return TrimName(raw)
end

local function ResolveAliases(locale, candidatesId)
    local all = addon.CHANNEL_CANDIDATE_ALIASES or {}
    local defaultBucket = all.default or {}
    local localeBucket = all[locale] or {}
    local raw = localeBucket[candidatesId]
    if raw == nil then
        raw = defaultBucket[candidatesId]
    end

    if raw == nil then
        return {}
    end

    local aliases = {}
    if type(raw) == "string" then
        local trimmed = TrimName(raw)
        if trimmed then
            aliases[#aliases + 1] = trimmed
        end
        return aliases
    end

    if type(raw) == "table" then
        for _, v in ipairs(raw) do
            local trimmed = TrimName(v)
            if trimmed then
                aliases[#aliases + 1] = trimmed
            end
        end
    end
    return aliases
end

local function BuildCandidateIdSet(locale)
    local all = addon.CHANNEL_CANDIDATES or {}
    local defaultBucket = all.default or {}
    local localeBucket = all[locale] or {}

    local ids = {}
    local seenId = {}
    for id in pairs(defaultBucket) do
        ids[#ids + 1] = id
        seenId[id] = true
    end
    for id in pairs(localeBucket) do
        if not seenId[id] then
            ids[#ids + 1] = id
            seenId[id] = true
        end
    end
    table.sort(ids)
    return ids, seenId
end

function addon.ChannelCandidatesRegistry:GetLocaleBucket(locale)
    local all = addon.CHANNEL_CANDIDATES or {}
    return all[locale] or all.default or {}
end

function addon.ChannelCandidatesRegistry:GetChannelName(locale, candidatesId)
    if type(candidatesId) ~= "string" or candidatesId == "" then
        return nil
    end
    return ResolveMappedName(GetLocaleKey(locale), candidatesId)
end

function addon.ChannelCandidatesRegistry:GetChannelAliases(locale, candidatesId)
    if type(candidatesId) ~= "string" or candidatesId == "" then
        return {}
    end
    return ResolveAliases(GetLocaleKey(locale), candidatesId)
end

local function BuildCanonicalIndexByMode(locale, mode)
    local keyLocale = GetLocaleKey(locale)
    local ids = BuildCandidateIdSet(keyLocale)

    local index = {}
    for _, id in ipairs(ids) do
        local mapped = ResolveMappedName(keyLocale, id)
        local names = { mapped }
        if mode == "message" then
            local aliases = ResolveAliases(keyLocale, id)
            for _, alias in ipairs(aliases) do
                names[#names + 1] = alias
            end
        end
        for _, name in ipairs(names) do
            local canonical = Canonicalize(name)
            if canonical and not index[canonical] then
                index[canonical] = id
            end
        end
    end

    return index
end

function addon.ChannelCandidatesRegistry:BuildPrimaryCanonicalIndex(locale)
    return BuildCanonicalIndexByMode(locale, "primary")
end

function addon.ChannelCandidatesRegistry:BuildMessageCanonicalIndex(locale)
    return BuildCanonicalIndexByMode(locale, "message")
end

function addon.ChannelCandidatesRegistry:BuildCanonicalIndex(locale)
    return self:BuildPrimaryCanonicalIndex(locale)
end

function addon.ChannelCandidatesRegistry:Validate(locale)
    local keyLocale = GetLocaleKey(locale)
    local errs = {}

    local reverse = {}
    local ids, seenId = BuildCandidateIdSet(keyLocale)

    for _, id in ipairs(ids) do
        local mapped = ResolveMappedName(keyLocale, id)
        if not mapped then
            errs[#errs + 1] = string.format("candidatesId '%s' has no mapped channel name (locale=%s)", id, keyLocale)
        else
            local canonical = Canonicalize(mapped)
            if not canonical then
                errs[#errs + 1] = string.format("mapped channel name '%s' is invalid after canonicalization (id=%s, locale=%s)", tostring(mapped), id, keyLocale)
            else
                local existing = reverse[canonical]
                if existing and existing ~= id then
                    errs[#errs + 1] = string.format("mapped channel '%s' conflicts: %s vs %s (locale=%s)", tostring(mapped), existing, id, keyLocale)
                else
                    reverse[canonical] = id
                end
            end
        end

        local aliases = ResolveAliases(keyLocale, id)
        for idx, alias in ipairs(aliases) do
            local canonical = Canonicalize(alias)
            if not canonical then
                errs[#errs + 1] = string.format("alias '%s' is invalid after canonicalization (id=%s, locale=%s, index=%d)", tostring(alias), id, keyLocale, idx)
            else
                local existing = reverse[canonical]
                if existing and existing ~= id then
                    errs[#errs + 1] = string.format("alias '%s' conflicts: %s vs %s (locale=%s)", tostring(alias), existing, id, keyLocale)
                else
                    reverse[canonical] = id
                end
            end
        end
    end

    if addon.IterateAllStreams then
        for _, stream in addon:IterateCompiledStreams() do
            local kind = addon:GetStreamKind(stream.key)
            local group = addon:GetStreamGroup(stream.key)
            if kind == "channel" and group == "dynamic" then
                local identity = stream and stream.identity or nil
                local id = identity and identity.candidatesId
                if type(id) ~= "string" or id == "" then
                    errs[#errs + 1] = string.format("dynamic stream '%s' missing identity.candidatesId", tostring(stream and stream.key))
                elseif not seenId[id] then
                    errs[#errs + 1] = string.format("dynamic stream '%s' references missing candidatesId '%s'", tostring(stream and stream.key), id)
                end
            end
        end
    end

    if #errs > 0 then
        return false, errs
    end
    return true, {}
end
