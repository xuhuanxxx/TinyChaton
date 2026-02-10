local addonName, addon = ...

addon.VisibilityPolicy = addon.VisibilityPolicy or {}
local Policy = addon.VisibilityPolicy

local function IsDynamicStreamKey(streamKey)
    if type(streamKey) ~= "string" or streamKey == "" then
        return false
    end
    local path = addon.GetStreamPath and addon:GetStreamPath(streamKey)
    return path and path:match("^CHANNEL%.DYNAMIC$") ~= nil
end

local function EnsureMutedConfig()
    if not addon.db or not addon.db.plugin or not addon.db.plugin.shelf then
        return nil
    end
    if type(addon.db.plugin.shelf.mutedDynamicChannels) ~= "table" then
        addon.db.plugin.shelf.mutedDynamicChannels = {}
    end
    return addon.db.plugin.shelf.mutedDynamicChannels
end

local function ResolveDynamicStreamKeyFromChannel(channelId, channelName)
    if addon.Utils and addon.Utils.FindDynamicStreamByChannelId and channelId then
        local stream = addon.Utils.FindDynamicStreamByChannelId(channelId)
        if stream and stream.key then
            return stream.key
        end
    end

    if type(channelName) ~= "string" or channelName == "" then
        return nil
    end

    if addon.Utils and addon.Utils.FindChannelByKey then
        local stream = addon.Utils.FindChannelByKey(channelName)
        if stream and stream.key and IsDynamicStreamKey(stream.key) then
            return stream.key
        end

        local normalized = addon.Utils.NormalizeChannelBaseName and addon.Utils.NormalizeChannelBaseName(channelName) or channelName
        stream = addon.Utils.FindChannelByKey(normalized)
        if stream and stream.key and IsDynamicStreamKey(stream.key) then
            return stream.key
        end
    end

    return nil
end

local function BuildAuthorFields(author)
    local pureName = author and string.match(author, "([^%-]+)") or author or ""
    return pureName, string.lower(pureName or "")
end

local function EvaluateRuleVisibility(chatData, includeDuplicate)
    if not chatData then
        return true
    end

    local metadata = chatData.metadata or {}

    local blacklistMatched = metadata.blacklistMatched
    if blacklistMatched == nil and addon.Filters and addon.Filters.BlacklistProcess then
        blacklistMatched = addon.Filters.BlacklistProcess(chatData) == true
    end

    local whitelistBlocked = metadata.whitelistBlocked
    if whitelistBlocked == nil and addon.Filters and addon.Filters.WhitelistProcess then
        whitelistBlocked = addon.Filters.WhitelistProcess(chatData) == true
    end

    local duplicateBlocked = false
    if includeDuplicate then
        duplicateBlocked = metadata.duplicateBlocked == true
    end

    if blacklistMatched or whitelistBlocked or duplicateBlocked then
        return false
    end

    return true
end

function Policy:IsDynamicChannelMuted(streamKey)
    local muted = EnsureMutedConfig()
    if not muted or not IsDynamicStreamKey(streamKey) then
        return false
    end
    return muted[streamKey] == true
end

function Policy:ToggleDynamicChannelMute(streamKey)
    if not IsDynamicStreamKey(streamKey) then
        return false
    end

    local muted = EnsureMutedConfig()
    if not muted then
        return false
    end

    if muted[streamKey] then
        muted[streamKey] = nil
    else
        muted[streamKey] = true
    end

    return muted[streamKey] == true
end

function Policy:IsVisibleRealtime(chatData)
    if not chatData then
        return true
    end

    if not EvaluateRuleVisibility(chatData, true) then
        return false
    end

    if chatData.event ~= "CHAT_MSG_CHANNEL" then
        return true
    end

    local streamKey = ResolveDynamicStreamKeyFromChannel(chatData.channelNumber, chatData.channelName)
    if not streamKey then
        return true
    end

    return not self:IsDynamicChannelMuted(streamKey)
end

function Policy:IsVisibleSnapshotLine(line, frame)
    if type(line) ~= "table" then
        return true
    end

    local text = type(line.text) == "string" and line.text or ""
    local author = type(line.author) == "string" and line.author or ""
    local pureName, authorLower = BuildAuthorFields(author)

    local chatData = {
        frame = frame,
        event = (line.chatType == "CHANNEL") and "CHAT_MSG_CHANNEL" or nil,
        text = text,
        textLower = string.lower(text),
        author = author,
        name = pureName,
        authorLower = authorLower,
        channelNumber = line.channelId,
        channelName = line.channelBaseName,
        metadata = {},
    }

    if not EvaluateRuleVisibility(chatData, false) then
        return false
    end

    local streamKey = line.channelKey
    if not IsDynamicStreamKey(streamKey) then
        streamKey = ResolveDynamicStreamKeyFromChannel(line.channelId, line.channelBaseName)
    end

    if not streamKey then
        return true
    end

    return not self:IsDynamicChannelMuted(streamKey)
end
