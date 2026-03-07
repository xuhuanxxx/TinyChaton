local addonName, addon = ...

addon.AvailabilityResolver = addon.AvailabilityResolver or {}
local Resolver = addon.AvailabilityResolver

Resolver.registry = Resolver.registry or {}

local function RegisterResolver(kind, group, fn)
    if type(kind) ~= "string" or kind == "" or type(group) ~= "string" or group == "" or type(fn) ~= "function" then
        return false
    end
    Resolver.registry[kind] = Resolver.registry[kind] or {}
    Resolver.registry[kind][group] = fn
    return true
end

local function ResolveChannelDynamicAvailability(streamKey, context)
    local streamMeta = (type(context) == "table" and type(context.streamMeta) == "table") and context.streamMeta or {}
    local semantic = addon.ChannelSemanticResolver
    if not semantic or type(semantic.ResolveDynamic) ~= "function" then
        return {
            available = false,
            state = "blocked",
            reason = "semantic_resolver_missing",
        }
    end

    local dynamic = semantic.ResolveDynamic({
        streamKey = streamKey,
        channelId = streamMeta.channelId,
        channelName = streamMeta.channelBaseName,
    })
    local id = dynamic and tonumber(dynamic.channelId) or nil
    if not id or id <= 0 then
        return {
            available = false,
            state = "unjoined",
            reason = dynamic and dynamic.reason or "unresolved",
            channelId = nil,
        }
    end

    local muted = addon.StreamVisibilityService and addon.StreamVisibilityService.IsStreamBlocked
        and addon.StreamVisibilityService:IsStreamBlocked(streamKey) or false

    return {
        available = true,
        state = muted and "muted" or "joined",
        reason = dynamic and dynamic.reason or "resolved",
        channelId = id,
    }
end

local function ResolveDefaultReady()
    return {
        available = true,
        state = "ready",
        reason = "ready",
    }
end

local function ResolveKitAvailability(entityKey, context)
    if context and context.forAction and context.actionKey and addon.ActionIntentOrchestrator then
        local result = addon.ActionIntentOrchestrator:Preview({
            actionKey = context.actionKey,
            targetKind = "kit",
            targetKey = context.targetKey or entityKey,
            source = "direct_user_action",
        })
        if type(result) == "table" and result.ok == false then
            return {
                available = false,
                state = "blocked",
                reason = result.reason or "blocked",
            }
        end
    end

    return {
        available = true,
        state = "ready",
        reason = "kit_ready",
    }
end

function Resolver.RegisterResolver(kind, group, fn)
    return RegisterResolver(kind, group, fn)
end

function Resolver.Resolve(entityKey, kind, context)
    if kind == "kit" then
        return ResolveKitAvailability(entityKey, context)
    end

    local stream = addon:GetStreamByKey(entityKey)
    if type(stream) ~= "table" then
        return {
            available = false,
            state = "blocked",
            reason = "missing_stream",
        }
    end

    local streamKind = addon:GetStreamKind(entityKey)
    local streamGroup = addon:GetStreamGroup(entityKey)
    local kindResolvers = Resolver.registry[streamKind] or nil
    local fn = kindResolvers and kindResolvers[streamGroup] or nil
    if type(fn) ~= "function" then
        return ResolveDefaultReady()
    end

    local ok, result = pcall(fn, entityKey, context)
    if ok and type(result) == "table" then
        return result
    end

    return {
        available = false,
        state = "blocked",
        reason = "resolver_error",
    }
end

RegisterResolver("channel", "dynamic", ResolveChannelDynamicAvailability)
RegisterResolver("notice", "system", ResolveDefaultReady)
RegisterResolver("notice", "alert", ResolveDefaultReady)
RegisterResolver("notice", "log", ResolveDefaultReady)
