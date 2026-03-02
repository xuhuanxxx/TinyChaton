local addonName, addon = ...
local L = addon.L

addon.NamePolicy = addon.NamePolicy or {}

local function ReadLocaleValue(key)
    if type(key) ~= "string" then return nil end
    return L and L[key] or nil
end

local function GetIdentityLabel(identity, fallback)
    local label = identity and identity.labelKey and ReadLocaleValue(identity.labelKey)
    if type(label) == "string" and label ~= "" then
        return label
    end
    return fallback or ""
end

local function ResolveShortNames(identity, label)
    local shortOne = ReadLocaleValue(identity and identity.shortOneKey)
    local shortTwo = ReadLocaleValue(identity and identity.shortTwoKey)
    if type(shortOne) ~= "string" or shortOne == "" then shortOne = label end
    if type(shortTwo) ~= "string" or shortTwo == "" then shortTwo = label end
    return shortOne, shortTwo
end

local function ResolveDynamicFullName(entity, label, context)
    local streamKey = entity and entity.key
    if type(streamKey) ~= "string" or streamKey == "" then
        return label
    end

    local semantic = addon.ChannelSemanticResolver
    if semantic and type(semantic.ResolveDynamic) == "function" then
        local dynamic = semantic.ResolveDynamic({
            streamKey = streamKey,
            channelId = context and context.channelId,
            channelName = context and context.channelName,
        })
        if dynamic and type(dynamic.activeName) == "string" and dynamic.activeName ~= "" then
            return dynamic.activeName
        end
    end

    local identity = entity and entity.identity or nil
    local candidatesId = identity and identity.candidatesId
    local registry = addon.ChannelCandidatesRegistry
    if registry and type(registry.GetChannelName) == "function" and type(candidatesId) == "string" then
        local locale = (type(GetLocale) == "function" and GetLocale()) or "enUS"
        local mapped = registry:GetChannelName(locale, candidatesId)
        if type(mapped) == "string" and mapped ~= "" then
            return mapped
        end
    end

    return label
end

function addon.NamePolicy.Resolve(entity, kind, context)
    context = context or {}

    if kind == "kit" then
        local identity = entity and entity.identity or {}
        local label = GetIdentityLabel(identity, entity and entity.key)
        local shortOne, shortTwo = ResolveShortNames(identity, label)
        return {
            label = label,
            fullName = label,
            shortOne = shortOne,
            shortTwo = shortTwo,
        }
    end

    local identity = entity and entity.identity or {}
    local label = GetIdentityLabel(identity, entity and entity.key)
    local shortOne, shortTwo = ResolveShortNames(identity, label)

    local fullName = label
    local isDynamic = entity and entity.chatType == "CHANNEL"
        and type(identity.candidatesId) == "string"
        and identity.candidatesId ~= ""

    if isDynamic then
        fullName = ResolveDynamicFullName(entity, label, context)
    end

    return {
        label = label,
        fullName = fullName,
        shortOne = shortOne,
        shortTwo = shortTwo,
    }
end
