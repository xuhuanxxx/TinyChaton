local addonName, addon = ...
local L = addon.L

addon.errors = addon.errors or {}
local MAX_ERRORS = 100

local LEVEL_PRIORITY = {
    ERROR = 1,
    WARN = 2,
    INFO = 3,
    DEBUG = 4,
}

local LOG_COLORS = {
    ERROR = "|cFFFF0000",
    WARN = "|cFFFFAA00",
    INFO = "|cFF00AAFF",
    DEBUG = "|cFF888888",
}

local function GetDebugEnabled()
    return addon.runtime and addon.runtime.debug == true
end

local function GetCurrentLevel()
    local level = addon.logLevel
    if not level then
        level = GetDebugEnabled() and "DEBUG" or "ERROR"
        addon.logLevel = level
    end
    return level
end

local function ShouldPrint(level)
    local current = GetCurrentLevel()
    local pLevel = LEVEL_PRIORITY[level] or LEVEL_PRIORITY.ERROR
    local pCurrent = LEVEL_PRIORITY[current] or LEVEL_PRIORITY.ERROR
    return pLevel <= pCurrent
end

local function FormatMessage(msg, ...)
    if type(msg) ~= "string" then
        return tostring(msg)
    end

    local ok, result = pcall(string.format, msg, ...)
    if ok then
        return result
    end

    local argc = select("#", ...)
    if argc == 0 then
        return msg
    end

    local parts = {}
    for i = 1, argc do
        parts[#parts + 1] = tostring(select(i, ...))
    end
    return msg .. " | args: " .. table.concat(parts, ", ")
end

local function PrintLog(level, message)
    if not ShouldPrint(level) then
        return
    end
    local color = LOG_COLORS[level] or ""
    local reset = "|r"
    local prefix = string.format("[TinyChaton][%s]", level)
    print(color .. prefix .. " " .. message .. reset)
end

function addon:SetLogLevel(level)
    if type(level) ~= "string" then return false end
    level = string.upper(level)
    if not LEVEL_PRIORITY[level] then return false end
    self.logLevel = level
    return true
end

function addon:Error(msg, ...)
    local formatted = FormatMessage(msg, ...)
    local timestamp = GetTime()

    table.insert(self.errors, {
        msg = formatted,
        level = "ERROR",
        time = timestamp,
        stack = debugstack(2),
    })

    if #self.errors > MAX_ERRORS then
        table.remove(self.errors, 1)
    end

    local errorPrefix = (L and L["MSG_ERROR_PREFIX"]) or "[Error]"
    PrintLog("ERROR", errorPrefix .. " " .. formatted)
end

function addon:Warn(msg, ...)
    local formatted = FormatMessage(msg, ...)
    PrintLog("WARN", formatted)
end

function addon:Info(msg, ...)
    local formatted = FormatMessage(msg, ...)
    PrintLog("INFO", formatted)
end

function addon:Debug(msg, ...)
    local formatted = FormatMessage(msg, ...)
    PrintLog("DEBUG", formatted)
end

function addon:GetLastErrors(count)
    count = count or 10
    local result = {}
    for i = #self.errors, math.max(1, #self.errors - count + 1), -1 do
        table.insert(result, self.errors[i])
    end
    return result
end

SLASH_TINYCHATON_ERROR1 = "/tcerror"
SlashCmdList["TINYCHATON_ERROR"] = function()
    local errors = addon:GetLastErrors(5)
    if #errors == 0 then
        print("|cFF00FF00[TinyChaton]|r No recent errors logged.")
        return
    end

    print("|cFFFF0000[TinyChaton] Recent Errors:|r")
    for _, err in ipairs(errors) do
        print(string.format("  [%s] [%s] %s", date("%H:%M:%S", err.time), err.level or "ERROR", err.msg))
    end
end
