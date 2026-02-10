local addonName, addon = ...
addon.Profiler = {
    data = {},
    enabled = false
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
    print("|cff00ffff[TinyChaton]|r Profiler data reset.")
end

--- Toggle profiler state
function addon.Profiler:Toggle()
    self.enabled = not self.enabled
    print("|cff00ffff[TinyChaton]|r Profiler " .. (self.enabled and "|cff00ff00Enabled|r" or "|cffff0000Disabled|r"))
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
