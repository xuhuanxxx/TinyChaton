local addonName, addon = ...

addon.StreamVisibilityService = addon.StreamVisibilityService or {}
local Service = addon.StreamVisibilityService

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

local function EnsureMetadata(envelope)
    if type(envelope) ~= "table" then
        return {}
    end
    if type(envelope.metadata) ~= "table" then
        envelope.metadata = {}
    end
    return envelope.metadata
end

local function SetVisibilityDebugMetadata(envelope, reason, visible, ruleReasons, blockedBy)
    local metadata = EnsureMetadata(envelope)
    local reasons = type(ruleReasons) == "table" and ruleReasons or {}
    metadata.visibilitySourceMode = envelope and envelope.sourceMode or nil
    metadata.visibilityReason = reason
    metadata.visibilityRuleReasons = reasons
    metadata.visibilityRuleMatched = #reasons > 0
    metadata.visibilityBlockedBy = blockedBy
end

local function ReturnDecision(envelope, visible, reason, ruleReasons, blockedBy)
    local decision = {
        visible = visible == true,
        reason = reason,
    }
    SetVisibilityDebugMetadata(envelope, reason, decision.visible, ruleReasons, blockedBy)
    if addon.ValidateContract then
        addon:ValidateContract("VisibilityDecision", decision)
    end
    return decision.visible
end

local function SyncEnvelopeToRaw(envelope)
    if type(envelope) ~= "table" or type(envelope.raw) ~= "table" then
        return
    end
    local raw = envelope.raw
    raw.metadata = envelope.metadata
    raw.streamKey = envelope.streamKey
    raw.streamKind = envelope.streamKind
    raw.streamGroup = envelope.streamGroup
end

local function ResolveEnvelopeStreamKey(envelope)
    if type(envelope) ~= "table" then
        return nil
    end
    if type(envelope.streamKey) == "string" and envelope.streamKey ~= "" then
        return envelope.streamKey
    end
    local raw = envelope.raw
    if envelope.sourceMode == "realtime" and type(raw) == "table" then
        local streamKey = ResolveStreamKey(raw)
        if type(streamKey) == "string" and streamKey ~= "" then
            envelope.streamKey = streamKey
            return streamKey
        end
    end
    return nil
end

local function ResolveEnvelopeKinds(envelope)
    local streamKey = ResolveEnvelopeStreamKey(envelope)
    if type(streamKey) ~= "string" or streamKey == "" then
        return nil
    end
    if (type(envelope.streamKind) ~= "string" or envelope.streamKind == "") and addon.GetStreamKind then
        envelope.streamKind = addon:GetStreamKind(streamKey)
    end
    if (type(envelope.streamGroup) ~= "string" or envelope.streamGroup == "") and addon.GetStreamGroup then
        envelope.streamGroup = addon:GetStreamGroup(streamKey)
    end

    return streamKey
end

local function EvaluateByRules(envelope)
    local engine = addon.StreamRuleEngine
    if type(engine) ~= "table" or type(engine.Evaluate) ~= "function" then
        return true, nil, nil
    end

    local decision = engine:Evaluate(envelope)
    if type(decision) == "table" and decision.blocked == true then
        local firstReason = type(decision.reasons) == "table" and decision.reasons[1] or "unknown"
        return false, "rule_blocked:" .. tostring(firstReason), decision
    end

    return true, nil, decision
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

function Service:BuildRealtimeEnvelope(streamContext)
    if type(streamContext) ~= "table" then
        return nil
    end
    local pureName, authorLower = BuildAuthorFields(streamContext.author)
    local metadata = type(streamContext.metadata) == "table" and streamContext.metadata or {}
    local envelope = {
        sourceMode = "realtime",
        streamKey = streamContext.streamKey,
        streamKind = streamContext.streamKind,
        streamGroup = streamContext.streamGroup,
        text = type(streamContext.text) == "string" and streamContext.text or "",
        textLower = type(streamContext.textLower) == "string" and streamContext.textLower
            or string.lower(type(streamContext.text) == "string" and streamContext.text or ""),
        author = type(streamContext.author) == "string" and streamContext.author or "",
        name = type(streamContext.name) == "string" and streamContext.name or pureName,
        authorLower = type(streamContext.authorLower) == "string" and streamContext.authorLower or authorLower,
        metadata = metadata,
        frame = streamContext.frame,
        raw = streamContext,
    }
    if addon.ValidateContract then
        addon:ValidateContract("VisibilityEnvelope", envelope)
    end
    return envelope
end

function Service:BuildSnapshotEnvelope(line, frame)
    if type(line) ~= "table" then
        return nil
    end
    local text = type(line.rawText) == "string" and line.rawText
        or (type(line.text) == "string" and line.text or "")
    local author = type(line.author) == "string" and line.author or ""
    local pureName, authorLower = BuildAuthorFields(author)
    local metadata = type(line.metadata) == "table" and line.metadata or {}
    local envelope = {
        sourceMode = "snapshot",
        streamKey = type(line.streamKey) == "string" and line.streamKey or nil,
        streamKind = type(line.streamKind) == "string" and line.streamKind or nil,
        streamGroup = type(line.streamGroup) == "string" and line.streamGroup or nil,
        text = text,
        textLower = string.lower(text),
        author = author,
        name = pureName,
        authorLower = authorLower,
        metadata = metadata,
        frame = frame,
        raw = line,
    }
    if addon.ValidateContract then
        addon:ValidateContract("VisibilityEnvelope", envelope)
    end
    return envelope
end

function Service:Evaluate(envelope)
    if type(envelope) ~= "table" then
        return ReturnDecision(nil, true, "missing_visibility_envelope", {})
    end

    if type(envelope.raw) ~= "table" then
        return ReturnDecision(envelope, true, "missing_visibility_raw", {}, nil)
    end

    local streamKey = ResolveEnvelopeKinds(envelope)
    local visibleByRules, ruleReason, ruleDecision = EvaluateByRules(envelope)
    local ruleReasons = ruleDecision and ruleDecision.reasons or {}
    if not visibleByRules then
        SyncEnvelopeToRaw(envelope)
        return ReturnDecision(envelope, false, ruleReason, ruleReasons, "rules")
    end

    if type(streamKey) == "string" and streamKey ~= "" and self:IsStreamBlocked(streamKey) then
        SyncEnvelopeToRaw(envelope)
        return ReturnDecision(envelope, false, "stream_blocked", ruleReasons, "stream_blocked")
    end

    SyncEnvelopeToRaw(envelope)
    return ReturnDecision(envelope, true, "visible", ruleReasons, nil)
end
