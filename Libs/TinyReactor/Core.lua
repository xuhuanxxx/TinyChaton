local addonName, addon = ...
addon.TinyReactor = addon.TinyReactor or {}
local TR = addon.TinyReactor

-- =========================================================================
-- TinyReactor Debug System
-- =========================================================================

TR.Debug = {
    enabled = false,
    level = "INFO", -- ERROR < WARN < INFO < DEBUG
    categories = {
        reconciler = true,
        component = true,
        pool = true,
        props = false,
        element = false,
    },
    -- Colors for different log levels
    colors = {
        ERROR = "|cFFFF0000",
        WARN = "|cFFFFAA00",
        INFO = "|cFF00AAFF",
        DEBUG = "|cFF888888",
    },
    reset = "|r",
}

local LEVEL_PRIORITY = { ERROR = 1, WARN = 2, INFO = 3, DEBUG = 4 }

--- Check if logging is allowed for given level and category
function TR:ShouldLog(level, category)
    if not self.Debug.enabled then return false end
    if category and not self.Debug.categories[category] then return false end
    return LEVEL_PRIORITY[level] <= LEVEL_PRIORITY[self.Debug.level]
end

--- Main logging function
function TR:Log(level, category, message, ...)
    if not self:ShouldLog(level, category) then return end

    local color = self.Debug.colors[level] or ""
    local reset = self.Debug.reset
    local prefix = string.format("[TinyReactor][%s]%s", level, category and "[" .. category .. "]" or "")

    if select("#", ...) > 0 then
        message = string.format(message, ...)
    end

    print(color .. prefix .. " " .. message .. reset)
end

--- Shorthand logging methods
function TR:DebugLog(category, message, ...) self:Log("DEBUG", category, message, ...) end
function TR:Info(category, message, ...) self:Log("INFO", category, message, ...) end
function TR:Warn(category, message, ...) self:Log("WARN", category, message, ...) end
function TR:Error(category, message, ...) self:Log("ERROR", category, message, ...) end

--- Enable/disable debugging
function TR:SetDebug(enabled, level)
    self.Debug.enabled = enabled
    if level then self.Debug.level = level end
    self:Info("core", "Debug mode %s (level: %s)", enabled and "ENABLED" or "DISABLED", self.Debug.level)
end

--- Dump a table for debugging
function TR:DumpTable(tbl, name, maxDepth)
    if not self.Debug.enabled then return end
    maxDepth = maxDepth or 2
    name = name or "table"

    local function dump(t, n, d)
        if d > maxDepth then return "..." end
        local result = {}
        for k, v in pairs(t) do
            local key = tostring(k)
            local value
            if type(v) == "table" then
                value = dump(v, key, d + 1)
            elseif type(v) == "function" then
                value = "<function>"
            elseif type(v) == "string" then
                value = '"' .. v .. '"'
            else
                value = tostring(v)
            end
            table.insert(result, key .. "=" .. value)
        end
        return "{" .. table.concat(result, ", ") .. "}"
    end

    self:DebugLog("dump", "%s = %s", name, dump(tbl, name, 1))
end

-- =========================================================================
-- TinyReactor Core: Element & Component API
-- =========================================================================

--- Creates a virtual element description
--- @param type string|table The type of element ("Button", "Frame") or a Component class
--- @param props table The properties for the element (key, text, etc.)
--- @param children table|nil Optional list of child elements
function TR:CreateElement(type, props, children)
    props = props or {}
    return {
        type = type,
        props = props,
        children = children or {},
        key = props.key -- Shortcut access to key
    }
end

--- Registers a new Component class
--- @param name string Component name for debugging
function TR:Component(name)
    local class = {}
    class.__index = class
    class._isComponent = true
    class.displayName = name or "Anonymous"

    function class:Create(props, children)
        return TR:CreateElement(self, props, children)
    end

    function class:Render(props)
        error("Component " .. self.displayName .. " must implement :Render(props)")
    end

    return class
end

-- Re-export common tools
TR.Assign = Mixin -- Use WoW's Mixin for shallow copy if needed
