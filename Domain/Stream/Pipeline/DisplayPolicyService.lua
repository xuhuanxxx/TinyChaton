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

function Service:ResolveChannelPrefix(streamKey, channelMeta)
    if type(streamKey) ~= "string" or streamKey == "" then
        return nil
    end

    local stream = addon.GetStreamByKey and addon:GetStreamByKey(streamKey) or nil
    if type(stream) ~= "table" then
        return nil
    end

    local meta = type(channelMeta) == "table" and channelMeta or {}
    return addon:FormatDisplayText(stream, "channel", "chat", {
        streamMeta = {
            channelId = meta.channelId,
            channelBaseName = meta.channelBaseName,
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

function Service:ResolveTimestampColor(msgColor, preferConfig)
    if addon.MessageFormatter and addon.MessageFormatter.ResolveTimestampColor then
        return addon.MessageFormatter.ResolveTimestampColor(msgColor, preferConfig)
    end
    return "FF888888"
end

return Service
