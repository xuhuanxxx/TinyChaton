local addonName, addon = ...

addon.StreamRuleEngine = addon.StreamRuleEngine or {}
local Engine = addon.StreamRuleEngine

Engine.kindStrategies = Engine.kindStrategies or {}

local function NormalizeDecision(raw)
    local decision = {
        blocked = false,
        reasons = {},
        metadataPatch = {},
    }
    if type(raw) ~= "table" then
        return decision
    end
    decision.blocked = raw.blocked == true
    if type(raw.reasons) == "table" then
        decision.reasons = raw.reasons
    end
    if type(raw.metadataPatch) == "table" then
        decision.metadataPatch = raw.metadataPatch
    end
    return decision
end

local function ApplyMetadataPatch(streamContext, patch)
    if type(streamContext) ~= "table" or type(patch) ~= "table" then
        return
    end
    streamContext.metadata = streamContext.metadata or {}
    for key, value in pairs(patch) do
        streamContext.metadata[key] = value
    end
end

local function ResolveKind(streamContext)
    if type(streamContext) ~= "table" then
        return nil
    end
    if type(streamContext.streamKind) == "string" and streamContext.streamKind ~= "" then
        return streamContext.streamKind
    end
    local streamKey = streamContext.streamKey
    if type(streamKey) ~= "string" or streamKey == "" then
        return nil
    end
    if addon.GetStreamKind then
        local kind = addon:GetStreamKind(streamKey)
        if type(kind) == "string" and kind ~= "" then
            streamContext.streamKind = kind
            return kind
        end
    end
    return nil
end

function Engine:RegisterKindStrategy(kind, strategy)
    if type(kind) ~= "string" or kind == "" or type(strategy) ~= "table" then
        return false
    end
    self.kindStrategies[kind] = strategy
    return true
end

function Engine:EvaluateRealtime(streamContext)
    local kind = ResolveKind(streamContext)
    local strategy = kind and self.kindStrategies[kind] or nil
    local decision
    if strategy and type(strategy.EvaluateRealtime) == "function" then
        local ok, result = pcall(strategy.EvaluateRealtime, strategy, streamContext)
        decision = ok and result or nil
    end
    local normalized = NormalizeDecision(decision)
    ApplyMetadataPatch(streamContext, normalized.metadataPatch)
    return normalized
end

function Engine:EvaluateSnapshot(lineContext)
    local kind = ResolveKind(lineContext)
    local strategy = kind and self.kindStrategies[kind] or nil
    local decision
    if strategy and type(strategy.EvaluateSnapshot) == "function" then
        local ok, result = pcall(strategy.EvaluateSnapshot, strategy, lineContext)
        decision = ok and result or nil
    end
    local normalized = NormalizeDecision(decision)
    ApplyMetadataPatch(lineContext, normalized.metadataPatch)
    return normalized
end

function Engine:ClearAllCaches(reason)
    local cleared = 0
    if addon.StreamRuleMatcher and addon.StreamRuleMatcher.ClearAllCaches then
        cleared = cleared + (addon.StreamRuleMatcher.ClearAllCaches(reason) or 0)
    end

    for _, strategy in pairs(self.kindStrategies) do
        if type(strategy) == "table" and type(strategy.ClearCaches) == "function" then
            local ok = pcall(strategy.ClearCaches, strategy, reason)
            if ok then
                cleared = cleared + 1
            end
        end
    end

    return cleared
end
