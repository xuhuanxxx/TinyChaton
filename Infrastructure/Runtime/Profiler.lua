local addonName, addon = ...
addon.Profiler = {
    data = {},
    enabled = false,
    lastBudgetWarnAt = {}
}

--- Start profiling a labelled section
function addon.Profiler:Start(label)
    if not self.enabled then return end
    self.data[label] = self.data[label] or { count = 0, total = 0, max = 0 }
    self.data[label].currentStart = debugprofilestop()
end

--- Stop profiling a labelled section
function addon.Profiler:Stop(label)
    if not self.enabled or not self.data[label] or not self.data[label].currentStart then return end
    local now = debugprofilestop()
    local elapsed = now - self.data[label].currentStart

    local d = self.data[label]
    d.count = d.count + 1
    d.total = d.total + elapsed
    d.max = math.max(d.max, elapsed)
    d.currentStart = nil

    local budget = addon.PERFORMANCE_BUDGET and addon.PERFORMANCE_BUDGET[label]
    if type(budget) == "number" and elapsed > budget then
        local warnAt = GetTime()
        local lastWarn = self.lastBudgetWarnAt[label] or 0
        if (warnAt - lastWarn) >= 10 then
            self.lastBudgetWarnAt[label] = warnAt
            if addon.Warn then
                addon:Warn("%s exceeded budget: %.3fms > %.3fms", tostring(label), elapsed, budget)
            else
                print(string.format("|cffff8800[TinyChaton]|r %s exceeded budget: %.3fms > %.3fms", tostring(label), elapsed, budget))
            end
        end
    end
end

--- Print profiling report
function addon.Profiler:Report()
    print("|cff00ffff[TinyChaton]|r Profiler Report:")
    for label, d in pairs(self.data) do
        local avg = (d.count > 0) and (d.total / d.count) or 0
        print(string.format("  %s: %d calls, total %.2fms, avg %.3fms, max %.3fms", 
            label, d.count, d.total, avg, d.max))
    end
end

--- Reset profiler data
function addon.Profiler:Reset()
    self.data = {}
    self.lastBudgetWarnAt = {}
    print("|cff00ffff[TinyChaton]|r Profiler data reset.")
end

--- Toggle profiler state
function addon.Profiler:Toggle()
    self.enabled = not self.enabled
    print("|cff00ffff[TinyChaton]|r Profiler " .. (self.enabled and "|cff00ff00Enabled|r" or "|cffff0000Disabled|r"))
end

function addon.Profiler:SetEnabled(enabled)
    self.enabled = enabled == true
end

-- Slash Command
SLASH_TINYCHATON_PROFILER1 = "/tcprofiler"
SlashCmdList["TINYCHATON_PROFILER"] = function(msg)
    if msg == "report" then
        addon.Profiler:Report()
    elseif msg == "reset" then
        addon.Profiler:Reset()
    else
        addon.Profiler:Toggle()
    end
end
