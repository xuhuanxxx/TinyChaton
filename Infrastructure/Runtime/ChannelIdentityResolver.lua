local addonName, addon = ...

addon.ChannelIdentityResolver = addon.ChannelIdentityResolver or {}

local function ResolveChannelIdentity(stream, context)
    context = context or {}

    local naming = addon.NamePolicy and addon.NamePolicy.Resolve and addon.NamePolicy.Resolve(stream, "channel", context) or {
        label = stream and stream.key or "",
        fullName = stream and stream.key or "",
        shortOne = stream and stream.key or "",
        shortTwo = stream and stream.key or "",
    }

    local availability = addon.AvailabilityResolver and addon.AvailabilityResolver.Resolve
        and addon.AvailabilityResolver.Resolve(stream and stream.key, "channel", context)
        or { available = true, state = "ready", reason = "fallback" }

    local channelId = tonumber(context.channelId) or tonumber(availability.channelId)
    if not channelId and stream and stream.chatType == "CHANNEL" and addon.ChannelSemanticResolver and addon.ChannelSemanticResolver.ResolveDynamic then
        local dynamic = addon.ChannelSemanticResolver.ResolveDynamic({
            streamKey = stream.key,
            channelId = context.channelId,
            channelName = context.channelName,
        })
        if dynamic then
            channelId = tonumber(dynamic.channelId)
        end
    end

    local candidates = {}
    if stream and stream.chatType == "CHANNEL" and stream.identity and type(stream.identity.candidatesId) == "string" then
        local registry = addon.ChannelCandidatesRegistry
        local locale = (type(GetLocale) == "function" and GetLocale()) or "enUS"
        if registry and type(registry.GetChannelName) == "function" then
            local mapped = registry:GetChannelName(locale, stream.identity.candidatesId)
            if mapped then
                candidates[1] = mapped
            end
        end
    end

    return {
        label = naming.label,
        fullName = naming.fullName,
        shortOne = naming.shortOne,
        shortTwo = naming.shortTwo,
        number = channelId,
        channelId = channelId,
        activeName = naming.fullName,
        candidates = candidates,
        available = availability.available == true,
        state = availability.state,
        reason = availability.reason,
    }
end

local function ResolveKitIdentity(kit, context)
    context = context or {}

    local naming = addon.NamePolicy and addon.NamePolicy.Resolve and addon.NamePolicy.Resolve(kit, "kit", context) or {
        label = kit and kit.key or "",
        fullName = kit and kit.key or "",
        shortOne = kit and kit.key or "",
        shortTwo = kit and kit.key or "",
    }

    local availability = addon.AvailabilityResolver and addon.AvailabilityResolver.Resolve
        and addon.AvailabilityResolver.Resolve(kit and kit.key, "kit", context)
        or { available = true, state = "ready", reason = "fallback" }

    return {
        label = naming.label,
        fullName = naming.fullName,
        shortOne = naming.shortOne,
        shortTwo = naming.shortTwo,
        number = nil,
        available = availability.available == true,
        state = availability.state,
        reason = availability.reason,
    }
end

function addon.ChannelIdentityResolver.ResolveDisplayIdentity(entity, kind, context)
    if kind == "kit" then
        return ResolveKitIdentity(entity, context)
    end
    return ResolveChannelIdentity(entity, context)
end

local function GetDisplayPolicy(surface, kind, override)
    if type(override) == "table" then
        local oShow = (surface ~= "shelf") and (override.showNumber == true)
        local oStyle = override.nameStyle
        if surface == "shelf" then
            if oStyle ~= "SHORT_ONE" and oStyle ~= "SHORT_TWO" then
                oStyle = "SHORT_ONE"
            end
        elseif oStyle ~= "FULL" and oStyle ~= "SHORT_ONE" and oStyle ~= "SHORT_TWO" then
            oStyle = "SHORT_ONE"
        end
        return { showNumber = oShow, nameStyle = oStyle }
    end

    local profile = addon.db and addon.db.profile
    if not profile then
        return { showNumber = (kind == "channel" and surface == "chat"), nameStyle = "SHORT_ONE" }
    end

    if surface == "shelf" then
        local bucket = profile.shelf and profile.shelf.visual and profile.shelf.visual.display
        local nameStyle = bucket and bucket.nameStyle or "SHORT_ONE"
        if nameStyle ~= "SHORT_ONE" and nameStyle ~= "SHORT_TWO" then
            nameStyle = "SHORT_ONE"
        end
        return {
            showNumber = false,
            nameStyle = nameStyle,
        }
    end

    local chatDisplay = profile.chat and profile.chat.visual and profile.chat.visual.display
    local chatChannel = chatDisplay and chatDisplay.channel
    local showNumber = (kind == "channel") and (chatChannel and chatChannel.showNumber == true) or false
    local nameStyle = chatChannel and chatChannel.nameStyle or "SHORT_ONE"
    if nameStyle ~= "FULL" and nameStyle ~= "SHORT_ONE" and nameStyle ~= "SHORT_TWO" then
        nameStyle = "SHORT_ONE"
    end
    return {
        showNumber = showNumber,
        nameStyle = nameStyle,
    }
end

function addon.ChannelIdentityResolver.FormatDisplayText(entity, kind, surface, context)
    context = context or {}
    local identity = addon.ChannelIdentityResolver.ResolveDisplayIdentity(entity, kind, context)
    local policy = GetDisplayPolicy(surface or "chat", kind or "channel", context.override)

    local base = identity.fullName
    if policy.nameStyle == "SHORT_ONE" then
        base = identity.shortOne
    elseif policy.nameStyle == "SHORT_TWO" then
        base = identity.shortTwo
    end

    if kind == "channel" and policy.showNumber then
        local number = tonumber(context.channelId) or identity.number
        if number and number > 0 then
            return tostring(number) .. "." .. base
        end
    end

    return base
end

function addon.ChannelIdentityResolver.ResolveDynamicActiveName(stream, context)
    local id = ResolveChannelIdentity(stream, context)
    return {
        activeName = id.activeName,
        channelId = id.channelId,
        candidates = id.candidates,
        label = id.label,
        available = id.available,
        state = id.state,
        reason = id.reason,
    }
end

function addon.ChannelIdentityResolver.ResolveStreamIdentity(stream, context)
    return ResolveChannelIdentity(stream, context)
end

function addon.ChannelIdentityResolver.FormatChannelLabel(stream, context)
    return addon.ChannelIdentityResolver.FormatDisplayText(stream, "channel", "chat", {
        channelId = context and context.channelId,
        channelName = context and context.channelName,
        registryKey = context and context.registryKey,
    })
end

function addon:ResolveDisplayIdentity(entity, kind, context)
    return addon.ChannelIdentityResolver.ResolveDisplayIdentity(entity, kind, context)
end

function addon:FormatDisplayText(entity, kind, surface, context)
    return addon.ChannelIdentityResolver.FormatDisplayText(entity, kind, surface, context)
end

function addon:ResolveDynamicActiveName(stream, context)
    return addon.ChannelIdentityResolver.ResolveDynamicActiveName(stream, context)
end

function addon:ResolveStreamIdentity(stream, context)
    return addon.ChannelIdentityResolver.ResolveStreamIdentity(stream, context)
end

function addon:FormatChannelLabel(stream, context)
    return addon.ChannelIdentityResolver.FormatChannelLabel(stream, context)
end
