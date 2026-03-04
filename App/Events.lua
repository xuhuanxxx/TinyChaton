local addonName, addon = ...

addon.eventHandlers = addon.eventHandlers or {}

function addon:RegisterEvent(event, fn)
    if not self.eventFrame then return end
    if type(event) ~= "string" or event == "" then return end
    if type(fn) ~= "function" then return end

    local handlers = self.eventHandlers[event]
    if not handlers then
        handlers = {}
        self.eventHandlers[event] = handlers
        self.eventFrame:RegisterEvent(event)
    end

    for _, handler in ipairs(handlers) do
        if handler == fn then
            return
        end
    end

    table.insert(handlers, fn)
end

function addon:UnregisterEvent(event, fn)
    if not self.eventFrame then return false end
    if type(event) ~= "string" or event == "" then return false end
    if type(fn) ~= "function" then return false end

    local handlers = self.eventHandlers[event]
    if type(handlers) ~= "table" then
        return false
    end

    local removed = false
    for i = #handlers, 1, -1 do
        if handlers[i] == fn then
            table.remove(handlers, i)
            removed = true
        end
    end

    if #handlers == 0 then
        self.eventHandlers[event] = nil
        self.eventFrame:UnregisterEvent(event)
    end

    return removed
end

function addon:InitEvents()
    self.eventFrame = CreateFrame("Frame")
    self.eventHandlers = {}
    self.eventFrame:SetScript("OnEvent", function(_, event, ...)
        for _, fn in ipairs(self.eventHandlers[event] or {}) do
            local ok, err = pcall(fn, event, ...)
            if not ok and addon.Error then
                addon:Error("Event handler failed (%s): %s", tostring(event), tostring(err))
            end
        end
    end)
end
