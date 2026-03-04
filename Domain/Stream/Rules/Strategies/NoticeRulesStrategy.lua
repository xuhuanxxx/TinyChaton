local addonName, addon = ...

addon.NoticeRulesStrategy = addon.NoticeRulesStrategy or {}
local Strategy = addon.NoticeRulesStrategy

function Strategy:EvaluateRealtime(streamContext)
    return {
        blocked = false,
        reasons = {},
        metadataPatch = {
            noticeRulesSkipped = true,
        },
    }
end

function Strategy:EvaluateSnapshot(lineContext)
    return {
        blocked = false,
        reasons = {},
        metadataPatch = {
            noticeRulesSkipped = true,
        },
    }
end

function Strategy:ClearCaches()
end

if addon.StreamRuleEngine and addon.StreamRuleEngine.RegisterKindStrategy then
    addon.StreamRuleEngine:RegisterKindStrategy("notice", Strategy)
end
