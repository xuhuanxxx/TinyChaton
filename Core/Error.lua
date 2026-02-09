local addonName, addon = ...
local L = addon.L

-- =========================================================================
-- Error Handling System
-- =========================================================================

addon.errors = {}
local MAX_ERRORS = 100

--- Report an error
--- @param msg string The error message (can contain format specifiers)
--- @param ... any Arguments for string.format
function addon:Error(msg, ...)
    local formatted = string.format(msg, ...)
    local timestamp = GetTime()

    -- Add to internal log
    table.insert(self.errors, {
        msg = formatted,
        time = timestamp,
        stack = debugstack(2)
    })

    -- Cap the log
    if #self.errors > MAX_ERRORS then
        table.remove(self.errors, 1)
    end

    -- Output to chat if debug enabled
    -- Use safe access in case config isn't loaded yet
    local debugEnabled = false
    if self.GetConfig then
        debugEnabled = self:GetConfig("system.debug")
    elseif self.db and self.db.system then
        debugEnabled = self.db.system.debug
    end

    if debugEnabled then
        print("|cFFFF0000[TinyChaton Error]|r " .. formatted)
    else
        -- Always print critical errors during development/beta if strict mode is on?
        -- For now, just print a subtle warning or nothing to avoid spamming users
        -- print("|cFFFF0000[TinyChaton]|r An error occurred. Check /tc error for details.")
    end
end

--- Get a list of recent errors
--- @param count number Number of errors to retrieve (default 10)
--- @return table List of error objects {msg, time, stack}
function addon:GetLastErrors(count)
    count = count or 10
    local result = {}
    for i = #self.errors, math.max(1, #self.errors - count + 1), -1 do
        table.insert(result, self.errors[i])
    end
    return result
end

-- Slash command to view errors
SLASH_TINYCHATON_ERROR1 = "/tcerror"
SlashCmdList["TINYCHATON_ERROR"] = function(msg)
    local errors = addon:GetLastErrors(5)
    if #errors == 0 then
        print("|cFF00FF00[TinyChaton]|r No recent errors logged.")
        return
    end

    print("|cFFFF0000[TinyChaton] Recent Errors:|r")
    for _, err in ipairs(errors) do
        print(string.format("  [%s] %s", date("%H:%M:%S", err.time), err.msg))
    end
end
