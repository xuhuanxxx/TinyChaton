local addonName, addon = ...

addon.StreamVisibilityService = addon.StreamVisibilityService or {}
local Service = addon.StreamVisibilityService

local function IsDynamicStreamKey(streamKey)
    if type(streamKey) ~= "string" or streamKey == "" then
        return false
    end
    local kind = addon:GetStreamKind(streamKey)
    local group = addon:GetStreamGroup(streamKey)
    return kind == "channel" and group == "dynamic"
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

local function ResolveStreamKey(streamContext)
    if type(streamContext) ~= "table" then
        return nil
    end
    if type(streamContext.streamKey) == "string" and streamContext.streamKey ~= "" then
        return streamContext.streamKey
    end
    if addon.ResolveStreamKey and addon.Utils and addon.Utils.UnpackArgs and type(streamContext.event) == "string" and type(streamContext.args) == "table" then
        local ok, streamKey = pcall(addon.ResolveStreamKey, addon, streamContext.event, addon.Utils.UnpackArgs(streamContext.args))
        if ok and type(streamKey) == "string" and streamKey ~= "" then
            streamContext.streamKey = streamKey
            return streamKey
        end
    end
    return nil
end

local function BuildAuthorFields(author)
    local pureName = author and string.match(author, "([^%-]+)") or author or ""
    return pureName, string.lower(pureName or "")
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

local function EvaluateByRulesRealtime(streamContext)
    local engine = addon.StreamRuleEngine
    if type(engine) ~= "table" or type(engine.EvaluateRealtime) ~= "function" then
        return true, nil
    end

    local decision = engine:EvaluateRealtime(streamContext)
    if type(decision) == "table" and decision.blocked == true then
        local firstReason = type(decision.reasons) == "table" and decision.reasons[1] or "unknown"
        return false, "rule_blocked:" .. tostring(firstReason)
    end

    return true, nil
end

local function EvaluateByRulesSnapshot(lineContext)
    local engine = addon.StreamRuleEngine
    if type(engine) ~= "table" or type(engine.EvaluateSnapshot) ~= "function" then
        return true, nil
    end

    local decision = engine:EvaluateSnapshot(lineContext)
    if type(decision) == "table" and decision.blocked == true then
        local firstReason = type(decision.reasons) == "table" and decision.reasons[1] or "unknown"
        return false, "rule_blocked:" .. tostring(firstReason)
    end

    return true, nil
end

function Service:IsStreamBlocked(streamKey)
    local blocked = EnsureStreamBlockedConfig()
    if not blocked or type(streamKey) ~= "string" or streamKey == "" then
        return false
    end
    return blocked[streamKey] == true
end

function Service:SetStreamBlocked(streamKey, shouldBlock)
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

function Service:ToggleStreamBlocked(streamKey)
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

function Service:IsDynamicChannelMuted(streamKey)
    if not IsDynamicStreamKey(streamKey) then
        return false
    end
    return self:IsStreamBlocked(streamKey)
end

function Service:ToggleDynamicChannelMute(streamKey)
    if not IsDynamicStreamKey(streamKey) then
        return false
    end
    return self:ToggleStreamBlocked(streamKey)
end

function Service:IsVisibleRealtime(streamContext)
    if type(streamContext) ~= "table" then
        return ReturnDecision(true, "missing_stream_context")
    end

    local streamKey = ResolveStreamKey(streamContext)
    if type(streamKey) == "string" and streamKey ~= "" and addon.GetStreamKind then
        streamContext.streamKind = addon:GetStreamKind(streamKey)
        streamContext.streamGroup = addon:GetStreamGroup(streamKey)
    end

    local visibleByRules, ruleReason = EvaluateByRulesRealtime(streamContext)
    if not visibleByRules then
        return ReturnDecision(false, ruleReason)
    end

    if type(streamKey) == "string" and streamKey ~= "" and self:IsStreamBlocked(streamKey) then
        return ReturnDecision(false, "stream_blocked")
    end

    return ReturnDecision(true, "visible")
end

function Service:IsVisibleSnapshotLine(line, frame)
    if type(line) ~= "table" then
        return ReturnDecision(true, "missing_snapshot_line")
    end

    local text = type(line.text) == "string" and line.text or ""
    local author = type(line.author) == "string" and line.author or ""
    local pureName, authorLower = BuildAuthorFields(author)
    local streamKey = type(line.streamKey) == "string" and line.streamKey or nil

    local lineContext = {
        frame = frame,
        text = text,
        textLower = string.lower(text),
        author = author,
        name = pureName,
        authorLower = authorLower,
        streamKey = streamKey,
        streamKind = streamKey and addon.GetStreamKind and addon:GetStreamKind(streamKey) or nil,
        streamGroup = streamKey and addon.GetStreamGroup and addon:GetStreamGroup(streamKey) or nil,
        metadata = {},
        line = line,
    }

    local visibleByRules, ruleReason = EvaluateByRulesSnapshot(lineContext)
    if not visibleByRules then
        return ReturnDecision(false, ruleReason)
    end

    if type(streamKey) == "string" and streamKey ~= "" and self:IsStreamBlocked(streamKey) then
        return ReturnDecision(false, "stream_blocked")
    end

    return ReturnDecision(true, "visible")
end
