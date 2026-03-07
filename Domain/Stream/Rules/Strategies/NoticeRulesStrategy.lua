local addonName, addon = ...

addon.NoticeRulesStrategy = addon.NoticeRulesStrategy or {}
local Strategy = addon.NoticeRulesStrategy

function Strategy:Evaluate()
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
