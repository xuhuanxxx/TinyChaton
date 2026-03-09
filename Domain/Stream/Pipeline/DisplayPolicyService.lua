local addonName, addon = ...

addon.DisplayPolicyService = addon.DisplayPolicyService or {}
local Service = addon.DisplayPolicyService

function Service:CanInjectCopy(streamKey)
    local interaction = addon.db and addon.db.profile and addon.db.profile.chat and addon.db.profile.chat.interaction
    if not interaction or interaction.clickToCopy == false then
        return false
    end

    if type(streamKey) ~= "string" or streamKey == "" then
        return true
    end

    local copyStreams = interaction.copyStreams
    if addon.ResolveStreamToggle then
        return addon:ResolveStreamToggle(streamKey, copyStreams, "copyDefault", true)
    end

    return true
end

function Service:CanInjectSend(streamKey)
    if type(streamKey) ~= "string" or streamKey == "" then
        return false
    end
    local caps = addon.GetStreamCapabilities and addon:GetStreamCapabilities(streamKey) or nil
    return type(caps) == "table" and caps.outbound == true
end

function Service:ResolvePrefixInteraction(frame, message)
    if type(message) ~= "table" then
        return nil
    end
    if not addon.ChatLinkAdapter or type(addon.ChatLinkAdapter.BuildRenderSpec) ~= "function" then
        return nil
    end
    return addon.ChatLinkAdapter:BuildRenderSpec(frame, message)
end

function Service:ResolveChannelPrefix(message)
    if type(message) ~= "table" then
        return nil
    end

    local streamKey = message.streamKey
    if type(streamKey) ~= "string" or streamKey == "" then
        return nil
    end

    local stream = addon.GetStreamByKey and addon:GetStreamByKey(streamKey) or nil
    if type(stream) ~= "table" then
        return nil
    end

    return addon:FormatDisplayText(stream, "channel", "chat", {
        streamMeta = {
            channelId = message.channelId,
            channelBaseName = message.channelNameObserved,
        },
        streamKey = streamKey,
    })
end

function Service:ResolveHighlightConfig(streamKey)
    local highlight = addon.db and addon.db.profile and addon.db.profile.filter and addon.db.profile.filter.highlight
    if type(highlight) ~= "table" or highlight.enabled ~= true then
        return nil
    end

    return {
        streamKey = streamKey,
        color = highlight.color,
        names = highlight.names,
        keywords = highlight.keywords,
    }
end

return Service
