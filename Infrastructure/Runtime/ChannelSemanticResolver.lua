local addonName, addon = ...

addon.ChannelSemanticResolver = addon.ChannelSemanticResolver or {}

local UNKNOWN_DYNAMIC = "unknown_dynamic"

local function Trim(s)
    if type(s) ~= "string" then return nil end
    local v = s:match("^%s*(.-)%s*$")
    if not v or v == "" then return nil end
    return v
end

local function NormalizeBaseName(name)
    local v = Trim(name)
    if not v then return nil end
    v = v:gsub("%s*%-%s*.+$", "")
    return Trim(v)
end

local function CanonicalizeName(name)
    local v = NormalizeBaseName(name)
    if not v then return nil end
    v = v:gsub("（", "("):gsub("）", ")")
    v = v:gsub("%s*%(%s*", "("):gsub("%s*%)%s*", ")")
    v = v:gsub("%s+", " ")
    v = v:gsub("^%s*(.-)%s*$", "%1")
    if v == "" then return nil end
    return string.lower(v)
end

local function GetLocaleKey(locale)
    if type(locale) == "string" and locale ~= "" then
        return locale
    end
    return (type(GetLocale) == "function" and GetLocale()) or "enUS"
end

local function ApiGetChannelName(arg)
    if _G and type(_G.GetChannelName) == "function" then
        return _G.GetChannelName(arg)
    end
    return nil, nil
end

local function ApiGetChannelList()
    if _G and type(_G.GetChannelList) == "function" then
        return { _G.GetChannelList() }
    end
    return {}
end

local function BuildDynamicStreamDescriptors()
    local out = {}
    local candidatesIdToStreamKey = {}

    if not addon.IterateAllStreams then
        return out, candidatesIdToStreamKey
    end

    for _, stream in addon:IterateAllStreams() do
        local kind = addon.GetStreamKind and addon:GetStreamKind(stream.key) or stream.kind
        local group = addon.GetStreamGroup and addon:GetStreamGroup(stream.key) or stream.group
        if kind == "channel" and group == "dynamic" then
            local identity = stream and stream.identity or nil
            local candidatesId = identity and identity.candidatesId
            if type(candidatesId) == "string" and candidatesId ~= "" then
                out[#out + 1] = {
                    streamKey = stream.key,
                    candidatesId = candidatesId,
                    stream = stream,
                }
                if not candidatesIdToStreamKey[candidatesId] then
                    candidatesIdToStreamKey[candidatesId] = stream.key
                end
            end
        end
    end

    return out, candidatesIdToStreamKey
end

local function GetMappedName(locale, candidatesId)
    local registry = addon.ChannelCandidatesRegistry
    if not registry then return nil end
    if type(registry.GetChannelName) ~= "function" then return nil end
    return registry:GetChannelName(locale, candidatesId)
end

local function BuildCanonicalIndex(locale)
    local registry = addon.ChannelCandidatesRegistry
    if registry and type(registry.BuildCanonicalIndex) == "function" then
        return registry:BuildCanonicalIndex(locale)
    end

    local index = {}
    local dynamicStreams = BuildDynamicStreamDescriptors()
    for _, item in ipairs(dynamicStreams) do
        local mapped = GetMappedName(locale, item.candidatesId)
        local canonical = CanonicalizeName(mapped)
        if canonical and not index[canonical] then
            index[canonical] = item.candidatesId
        end
    end

    return index
end

local function BuildPrimaryCanonicalIndex(locale)
    local registry = addon.ChannelCandidatesRegistry
    if registry and type(registry.BuildPrimaryCanonicalIndex) == "function" then
        return registry:BuildPrimaryCanonicalIndex(locale)
    end
    return BuildCanonicalIndex(locale)
end

local function BuildMessageCanonicalIndex(locale)
    local registry = addon.ChannelCandidatesRegistry
    if registry and type(registry.BuildMessageCanonicalIndex) == "function" then
        return registry:BuildMessageCanonicalIndex(locale)
    end
    return BuildCanonicalIndex(locale)
end

local function ParseNameFromChannelString(channelString)
    if type(channelString) ~= "string" or channelString == "" then
        return nil
    end
    local parsed = channelString:match("^%d+%.%s*(.+)$")
    if type(parsed) ~= "string" or parsed == "" then
        return nil
    end
    return parsed
end

local function ResolveByRawName(rawName, byMessageCanonical, candidatesIdToStreamKey)
    if type(rawName) ~= "string" or rawName == "" then
        return nil, nil
    end

    local canonical = CanonicalizeName(rawName)
    local candidatesId = canonical and byMessageCanonical[canonical] or nil
    local streamKey = candidatesId and candidatesIdToStreamKey[candidatesId] or nil
    return streamKey, candidatesId
end

local function ResolveByChannelId(channelId, locale, candidatesIdToStreamKey)
    local id = tonumber(channelId)
    if not id or id <= 0 then
        return nil
    end

    local resolvedId, resolvedName = ApiGetChannelName(id)
    if not resolvedId or resolvedId <= 0 or type(resolvedName) ~= "string" then
        return nil
    end

    local canonical = CanonicalizeName(resolvedName)
    local index = BuildPrimaryCanonicalIndex(locale)
    local candidatesId = canonical and index[canonical] or nil
    local streamKey = candidatesId and candidatesIdToStreamKey[candidatesId] or nil
    if not streamKey then return nil end

    return {
        streamKey = streamKey,
        candidatesId = candidatesId,
        channelId = resolvedId,
        activeName = NormalizeBaseName(resolvedName),
        reason = "channel_id",
    }
end

local function BuildJoinedChannelIndex()
    local byCanonical = {}

    local list = ApiGetChannelList()
    for i = 1, #list, 3 do
        local id = tonumber(list[i])
        local name = list[i + 1]
        if id and id > 0 and type(name) == "string" then
            local normalized = NormalizeBaseName(name)
            local canonical = CanonicalizeName(name)
            if canonical then
                byCanonical[canonical] = {
                    channelId = id,
                    channelName = normalized,
                }
            end
        end
    end

    return byCanonical
end

function addon.ChannelSemanticResolver.Canonicalize(name)
    return CanonicalizeName(name)
end

function addon.ChannelSemanticResolver.ResolveEventChannelName(channelBaseName, channelString, channelId)
    local baseName = (type(channelBaseName) == "string" and channelBaseName ~= "") and channelBaseName or nil
    local stringName = ParseNameFromChannelString(channelString)

    if not baseName then
        return stringName
    end
    if not stringName then
        return baseName
    end

    local cBase = CanonicalizeName(baseName)
    local cString = CanonicalizeName(stringName)
    if cBase and cString and cBase ~= cString then
        if addon.WarnOnce then
            addon:WarnOnce(
                "channel_semantic:event_name_conflict:" .. tostring(channelId),
                "CHAT_MSG_CHANNEL name conflict (id=%s): base=%s, string=%s. Prefer string name.",
                tostring(channelId),
                tostring(baseName),
                tostring(stringName)
            )
        end
        return stringName
    end

    return baseName
end

function addon.ChannelSemanticResolver.GetJoinedDynamicChannels(locale)
    local keyLocale = GetLocaleKey(locale)
    local dynamicStreams, candidatesIdToStreamKey = BuildDynamicStreamDescriptors()
    local canonicalIndex = BuildPrimaryCanonicalIndex(keyLocale)
    local joinedByCanonical = BuildJoinedChannelIndex()

    local byStreamKey = {}
    for canonical, joined in pairs(joinedByCanonical) do
        local candidatesId = canonicalIndex[canonical]
        local streamKey = candidatesId and candidatesIdToStreamKey[candidatesId] or nil
        if streamKey then
            byStreamKey[streamKey] = {
                channelId = joined.channelId,
                channelName = joined.channelName,
                canonicalName = canonical,
                candidatesId = candidatesId,
            }
        end
    end

    local streams = {}
    for _, item in ipairs(dynamicStreams) do
        streams[#streams + 1] = item.streamKey
    end

    return {
        locale = keyLocale,
        streams = streams,
        byStreamKey = byStreamKey,
    }
end

function addon.ChannelSemanticResolver.ResolveStreamKey(context)
    context = context or {}
    local keyLocale = GetLocaleKey(context.locale)
    local _, candidatesIdToStreamKey = BuildDynamicStreamDescriptors()
    local byMessageCanonical = BuildMessageCanonicalIndex(keyLocale)

    local byId = ResolveByChannelId(context.channelId, keyLocale, candidatesIdToStreamKey)
    local byNameStreamKey, byNameCandidatesId = ResolveByRawName(context.channelName, byMessageCanonical, candidatesIdToStreamKey)

    if byId and byNameStreamKey and byId.streamKey ~= byNameStreamKey then
        if addon.WarnOnce then
            addon:WarnOnce(
                string.format(
                    "channel_semantic:conflict:%s:%s:%s",
                    tostring(context.channelId),
                    tostring(byId.streamKey),
                    tostring(byNameStreamKey)
                ),
                "Channel semantic conflict (id=%s): byId=%s(%s), byName=%s(%s), rawName=%s. Prefer byName.",
                tostring(context.channelId),
                tostring(byId.streamKey),
                tostring(byId.activeName),
                tostring(byNameStreamKey),
                tostring(byNameCandidatesId) .. ";source=message",
                tostring(context.channelName)
            )
        end
        return byNameStreamKey
    end

    if byNameStreamKey then
        return byNameStreamKey
    end

    if byId then
        return byId.streamKey
    end

    return UNKNOWN_DYNAMIC
end

function addon.ChannelSemanticResolver.ResolveDynamic(context)
    context = context or {}
    local keyLocale = GetLocaleKey(context.locale)
    local streamKey = context.streamKey

    if type(streamKey) ~= "string" or streamKey == "" then
        streamKey = addon.ChannelSemanticResolver.ResolveStreamKey(context)
    end

    if streamKey == UNKNOWN_DYNAMIC then
        return {
            streamKey = UNKNOWN_DYNAMIC,
            candidatesId = nil,
            channelId = tonumber(context.channelId),
            activeName = NormalizeBaseName(context.channelName),
            reason = "unknown",
        }
    end

    local stream = addon.GetStreamByKey and addon:GetStreamByKey(streamKey) or nil
    local identity = stream and stream.identity or nil
    local candidatesId = identity and identity.candidatesId
    if type(candidatesId) ~= "string" or candidatesId == "" then
        return {
            streamKey = UNKNOWN_DYNAMIC,
            candidatesId = nil,
            channelId = tonumber(context.channelId),
            activeName = NormalizeBaseName(context.channelName),
            reason = "missing_candidates_id",
        }
    end

    local mapped = GetMappedName(keyLocale, candidatesId)

    local byId = ResolveByChannelId(context.channelId, keyLocale, { [candidatesId] = streamKey })
    if byId and byId.streamKey == streamKey then
        return byId
    end

    if mapped then
        local id, resolved = ApiGetChannelName(mapped)
        if id and id > 0 then
            return {
                streamKey = streamKey,
                candidatesId = candidatesId,
                channelId = id,
                activeName = NormalizeBaseName(resolved) or NormalizeBaseName(mapped),
                reason = "mapped_name_api",
            }
        end

        local joinedByCanonical = BuildJoinedChannelIndex()
        local canonical = CanonicalizeName(mapped)
        local joined = canonical and joinedByCanonical[canonical] or nil
        if joined then
            return {
                streamKey = streamKey,
                candidatesId = candidatesId,
                channelId = joined.channelId,
                activeName = joined.channelName,
                reason = "mapped_name_joined",
            }
        end
    end

    local fromMessage = NormalizeBaseName(context.channelName)
    if fromMessage then
        return {
            streamKey = streamKey,
            candidatesId = candidatesId,
            channelId = tonumber(context.channelId),
            activeName = fromMessage,
            reason = "message_name",
        }
    end

    return {
        streamKey = streamKey,
        candidatesId = candidatesId,
        channelId = tonumber(context.channelId),
        activeName = mapped,
        reason = "mapped_name_fallback",
    }
end
