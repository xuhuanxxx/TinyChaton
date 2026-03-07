local addonName, addon = ...

addon.StreamRuleEngine = addon.StreamRuleEngine or {}
local Engine = addon.StreamRuleEngine

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

local function EnsureCore(self)
    if self.coreEngine then
        return self.coreEngine
    end
    if not addon.TinyCoreStreamRuleEngine or type(addon.TinyCoreStreamRuleEngine.New) ~= "function" then
        error("TinyCore Stream RuleEngine is not initialized")
    end
    self.coreEngine = addon.TinyCoreStreamRuleEngine:New({
        resolveKind = ResolveKind,
    })
    self.kindStrategies = self.coreEngine.kindStrategies
    return self.coreEngine
end

function Engine:RegisterKindStrategy(kind, strategy)
    return EnsureCore(self):RegisterKindStrategy(kind, strategy)
end

function Engine:Evaluate(context)
    return EnsureCore(self):Evaluate(context)
end

function Engine:ClearAllCaches(reason)
    local cleared = 0
    if addon.StreamRuleMatcher and addon.StreamRuleMatcher.ClearAllCaches then
        cleared = cleared + (addon.StreamRuleMatcher.ClearAllCaches(reason) or 0)
    end

    local kindStrategies = EnsureCore(self).kindStrategies or {}
    for _, strategy in pairs(kindStrategies) do
        if type(strategy) == "table" and type(strategy.ClearCaches) == "function" then
            local ok = pcall(strategy.ClearCaches, strategy, reason)
            if ok then
                cleared = cleared + 1
            end
        end
    end

    return cleared
end

EnsureCore(Engine)
