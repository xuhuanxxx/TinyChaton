local addonName, addon = ...

addon.VisibilityPolicy = addon.VisibilityPolicy or {}
local Policy = addon.VisibilityPolicy

local function IsDynamicStreamKey(streamKey)
    if type(streamKey) ~= "string" or streamKey == "" then
        return false
    end
    local kind = addon:GetStreamKind(streamKey)
    local group = addon:GetStreamGroup(streamKey)
    return kind == "channel" and group == "dynamic"
end

local function IsChannelStreamKey(streamKey)
    if type(streamKey) ~= "string" or streamKey == "" then
        return false
    end
    return addon:GetStreamKind(streamKey) == "channel"
end

local function EnsureStreamBlockedConfig()
    if not addon.db or not addon.db.profile then
        return nil
    end
    local filter = addon.db.profile.filter
    if type(filter) ~= "table" then
        addon.db.profile.filter = {}
        filter = addon.db.profile.filter
    end
    if type(filter.streamBlocked) ~= "table" then
        filter.streamBlocked = {}
    end
    return filter.streamBlocked
end

local function ResolveStreamKeyFromChatData(chatData)
    if type(chatData) ~= "table" then
        return nil
    end
    if type(chatData.streamKey) == "string" and chatData.streamKey ~= "" then
        return chatData.streamKey
    end
    if addon.ResolveStreamKey and addon.Utils and addon.Utils.UnpackArgs and type(chatData.event) == "string" and type(chatData.args) == "table" then
        local ok, streamKey = pcall(addon.ResolveStreamKey, addon, chatData.event, addon.Utils.UnpackArgs(chatData.args))
        if ok and type(streamKey) == "string" and streamKey ~= "" then
            return streamKey
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

    local streamKey = ResolveStreamKeyFromChatData(chatData)
    if not IsChannelStreamKey(streamKey) then
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

local function ReturnDecision(visible, reason)
    local decision = {
        visible = visible == true,
        reason = reason,
    }
    if addon.ValidateContract then
        addon:ValidateContract("VisibilityDecision", decision)
    end
    return decision.visible
end

function Policy:IsStreamBlocked(streamKey)
    local blocked = EnsureStreamBlockedConfig()
    if not blocked or type(streamKey) ~= "string" or streamKey == "" then
        return false
    end
    return blocked[streamKey] == true
end

function Policy:SetStreamBlocked(streamKey, shouldBlock)
    if type(streamKey) ~= "string" or streamKey == "" then
        return false
    end
    local blocked = EnsureStreamBlockedConfig()
    if not blocked then
        return false
    end
    if shouldBlock == true then
        blocked[streamKey] = true
        return true
    end
    blocked[streamKey] = nil
    return false
end

function Policy:ToggleStreamBlocked(streamKey)
    if type(streamKey) ~= "string" or streamKey == "" then
        return false
    end
    local blocked = EnsureStreamBlockedConfig()
    if not blocked then
        return false
    end

    if blocked[streamKey] == true then
        blocked[streamKey] = nil
        return false
    end

    blocked[streamKey] = true
    return true
end

function Policy:IsDynamicChannelMuted(streamKey)
    if not IsDynamicStreamKey(streamKey) then
        return false
    end
    return self:IsStreamBlocked(streamKey)
end

function Policy:ToggleDynamicChannelMute(streamKey)
    if not IsDynamicStreamKey(streamKey) then
        return false
    end
    return self:ToggleStreamBlocked(streamKey)
end

function Policy:IsVisibleRealtime(chatData)
    if not chatData then
        return ReturnDecision(true, "missing_chat_data")
    end

    if not EvaluateRuleVisibility(chatData, true) then
        return ReturnDecision(false, "rule_blocked")
    end

    local streamKey = ResolveStreamKeyFromChatData(chatData)
    if type(streamKey) == "string" and streamKey ~= "" and self:IsStreamBlocked(streamKey) then
        return ReturnDecision(false, "stream_blocked")
    end

    return ReturnDecision(true, "visible")
end

function Policy:IsVisibleSnapshotLine(line, frame)
    if type(line) ~= "table" then
        return ReturnDecision(true, "missing_snapshot_line")
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
        streamKey = line.channelKey,
        metadata = {},
    }

    if not EvaluateRuleVisibility(chatData, false) then
        return ReturnDecision(false, "rule_blocked")
    end

    local streamKey = type(line.channelKey) == "string" and line.channelKey or nil
    if streamKey and self:IsStreamBlocked(streamKey) then
        return ReturnDecision(false, "stream_blocked")
    end

    return ReturnDecision(true, "visible")
end
