local addonName, addon = ...

addon.eventHandlers = addon.eventHandlers or {}

function addon:RegisterEvent(event, fn)
    if not self.eventFrame then return end
    if not self.eventHandlers[event] then
        self.eventHandlers[event] = {}
        self.eventFrame:RegisterEvent(event)
    end
    table.insert(self.eventHandlers[event], fn)
end

function addon:InitEvents()
    self.eventFrame = CreateFrame("Frame")
    self.eventHandlers = {}
    self.eventFrame:SetScript("OnEvent", function(_, event, ...)
        for _, fn in ipairs(self.eventHandlers[event] or {}) do
            fn(event, ...)
        end
    end)
end
