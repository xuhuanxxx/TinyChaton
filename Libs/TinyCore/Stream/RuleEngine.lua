local addonName, addon = ...

addon.TinyCoreStreamRuleEngine = addon.TinyCoreStreamRuleEngine or {}
local RuleEngine = addon.TinyCoreStreamRuleEngine
RuleEngine.__index = RuleEngine

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

function RuleEngine:New(opts)
    local options = type(opts) == "table" and opts or {}
    return setmetatable({
        kindStrategies = {},
        resolveKind = options.resolveKind,
    }, self)
end

function RuleEngine:SetKindResolver(fn)
    if type(fn) ~= "function" then
        error("RuleEngine kind resolver must be a function")
    end
    self.resolveKind = fn
end

function RuleEngine:RegisterKindStrategy(kind, strategy)
    if type(kind) ~= "string" or kind == "" or type(strategy) ~= "table" then
        return false
    end
    self.kindStrategies[kind] = strategy
    return true
end

function RuleEngine:ResolveKind(context)
    if type(self.resolveKind) ~= "function" then
        return nil
    end
    local ok, kind = pcall(self.resolveKind, context)
    if ok and type(kind) == "string" and kind ~= "" then
        return kind
    end
    return nil
end

function RuleEngine:Evaluate(context)
    local kind = self:ResolveKind(context)
    local strategy = kind and self.kindStrategies[kind] or nil

    local decision
    if strategy and type(strategy.Evaluate) == "function" then
        local ok, result = pcall(strategy.Evaluate, strategy, context)
        decision = ok and result or nil
    end

    local normalized = NormalizeDecision(decision)
    ApplyMetadataPatch(context, normalized.metadataPatch)
    return normalized
end
