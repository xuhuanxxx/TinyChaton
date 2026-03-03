local addonName, addon = ...

addon.AvailabilityResolver = addon.AvailabilityResolver or {}

local function ResolveChannelAvailability(streamKey, context)
    local stream = addon:GetStreamByKey(streamKey)
    if type(stream) ~= "table" then
        return {
            available = false,
            state = "blocked",
            reason = "missing_stream",
        }
    end

    local kind = addon:GetStreamKind(streamKey)
    local group = addon:GetStreamGroup(streamKey)
    if kind ~= "channel" then
        return {
            available = true,
            state = "ready",
            reason = "non_channel_stream",
        }
    end

    if group ~= "dynamic" then
        return {
            available = true,
            state = "ready",
            reason = "non_dynamic_channel",
        }
    end

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
        channelId = context and context.channelId,
        channelName = context and context.channelName,
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

    local muted = addon.VisibilityPolicy and addon.VisibilityPolicy.IsDynamicChannelMuted
        and addon.VisibilityPolicy:IsDynamicChannelMuted(streamKey) or false

    return {
        available = true,
        state = muted and "muted" or "joined",
        reason = dynamic and dynamic.reason or "resolved",
        channelId = id,
    }
end

local function ResolveKitAvailability(kitKey, context)
    if context and context.forAction and context.actionKey and addon.CanExecuteAction then
        local allowed, reason = addon:CanExecuteAction(context.actionKey)
        if not allowed then
            return {
                available = false,
                state = "blocked",
                reason = reason or "blocked",
            }
        end
    end

    return {
        available = true,
        state = "ready",
        reason = "kit_ready",
    }
end

function addon.AvailabilityResolver.Resolve(entityKey, kind, context)
    if kind == "kit" then
        return ResolveKitAvailability(entityKey, context)
    end
    return ResolveChannelAvailability(entityKey, context)
end
