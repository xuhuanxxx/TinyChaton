local addonName, addon = ...

-- =========================================================================
-- Event Dispatcher with Middleware Pipeline
-- Provides a unified entry point for chat message processing
-- Supports 4 stages: PRE_PROCESS, FILTER, ENRICH, LOG
-- =========================================================================

addon.EventDispatcher = addon.EventDispatcher or {}
local Dispatcher = addon.EventDispatcher

-- Middleware registry by stage
Dispatcher.middlewares = {
    PRE_PROCESS = {},  -- Pre-processing (cannot block)
    FILTER = {},       -- Filtering/blocking stage (can return true to block)
    ENRICH = {},       -- Enhancement stage (modify text)
    LOG = {}           -- Logging stage (cannot block)
}

-- Registered event filters
Dispatcher.registeredFilters = {}

--- Initialize event dispatcher
function Dispatcher:Initialize()
    self.registeredFilters = {}
    
    if not addon.STREAM_REGISTRY then return end
end

--- Register a middleware function
--- @param stage string Stage name: "PRE_PROCESS", "FILTER", "ENRICH", "LOG"
--- @param priority number Lower numbers execute first (e.g., 10, 20, 30)
--- @param name string Middleware name for debugging
--- @param fn function Middleware function(chatData) -> boolean|nil
function Dispatcher:RegisterMiddleware(stage, priority, name, fn)
    if not self.middlewares[stage] then
        error("Invalid middleware stage: " .. tostring(stage))
        return
    end
    
    if type(fn) ~= "function" then
        error("Middleware function must be a function")
        return
    end
    
    table.insert(self.middlewares[stage], {
        name = name or "unnamed",
        priority = priority or 100,
        fn = fn
    })
    
    -- Sort by priority after insertion
    table.sort(self.middlewares[stage], function(a, b)
        return a.priority < b.priority
    end)
end

--- Unregister a middleware by name
--- @param stage string Stage name
--- @param name string Middleware name
--- @return boolean Success
function Dispatcher:UnregisterMiddleware(stage, name)
    if not self.middlewares[stage] then
        return false
    end
    
    local stageMiddlewares = self.middlewares[stage]
    for i, middleware in ipairs(stageMiddlewares) do
        if middleware.name == name then
            table.remove(stageMiddlewares, i)
            
            if addon.Debug then
                addon:Debug(string.format("Unregistered middleware: %s from %s", name, stage))
            end
            
            return true
        end
    end
    
    return false
end

--- Check if a middleware is registered
--- @param stage string Stage name
--- @param name string Middleware name
--- @return boolean
function Dispatcher:IsMiddlewareRegistered(stage, name)
    if not self.middlewares[stage] then
        return false
    end
    
    for _, middleware in ipairs(self.middlewares[stage]) do
        if middleware.name == name then
            return true
        end
    end
    
    return false
end

--- Execute middlewares for a specific stage
--- @param stage string Stage name
--- @param chatData table ChatData object
--- @return boolean True if message should be blocked (FILTER stage only)
function Dispatcher:RunMiddlewares(stage, chatData)
    local middlewares = self.middlewares[stage]
    if not middlewares then return false end
    
    for _, middleware in ipairs(middlewares) do
        local ok, result = pcall(middleware.fn, chatData)
        
        if not ok then
            -- Log error but don't break the pipeline
            if addon.Debug then
                addon:Debug(string.format("Middleware error [%s:%s]: %s", 
                    stage, middleware.name, tostring(result)))
            end
        elseif result == true and stage == "FILTER" then
            -- Only FILTER stage can block messages
            chatData.isBlocked = true
            return true
        end
    end
    
    return false
end

--- Core event handler with middleware pipeline
--- @param frame table ChatFrame object
--- @param event string Event name
--- @param ... Event arguments
--- @return boolean|nil, ... Whether to block message, modified arguments
function Dispatcher:OnChatEvent(frame, event, ...)
    -- Skip if addon is disabled or in combat (to prevent taint)
    if InCombatLockdown() then return false, ... end
    if not addon.db or not addon.db.enabled then
        return false, ...
    end
    
    -- Create ChatData object
    local chatData = addon.ChatData:New(frame, event, ...)
    
    -- Skip if chatData is nil (e.g., secret value from Blizzard)
    if not chatData then
        return false, ...
    end
    
    -- Stage 1: PRE_PROCESS
    -- Pre-processing stage (cannot block, but can modify chatData)
    self:RunMiddlewares("PRE_PROCESS", chatData)
    
    -- Stage 2: FILTER
    -- Filtering stage (can block message)
    if self:RunMiddlewares("FILTER", chatData) then
        return true
    end
    
    -- Stage 3: ENRICH
    -- Enrichment stage (can modify content/args)
    self:RunMiddlewares("ENRICH", chatData)
    
    -- Stage 4: LOG
    -- Logging stage (side effects only, e.g., history recording)
    if not chatData.isBlocked then
        self:RunMiddlewares("LOG", chatData)
    end
    
    -- optimization: if text and author are not modified, return false (pass through)
    -- This prevents us from breaking message formatting (like class colors) due to 
    -- potential argument repacking issues if we don't strictly need to modify args.
    if chatData.text == chatData.rawText and chatData.author == chatData.rawAuthor then
        return false
    end

    -- Return modified arguments
    return false, addon.ChatData:GetArgs(chatData)
end

--- Register event filters for all chat events
function Dispatcher:RegisterFilters()
    local events = addon.CHAT_EVENTS or {}
    
    -- Add CHAT_MSG_SYSTEM for Greeting middleware
    table.insert(events, "CHAT_MSG_SYSTEM")
    
    for _, event in ipairs(events) do
        if not self.registeredFilters[event] then
            ChatFrame_AddMessageEventFilter(event, function(frame, eventName, ...)
                return self:OnChatEvent(frame, eventName, ...)
            end)
            
            self.registeredFilters[event] = true
        end
    end
end



-- =========================================================================
-- Initialization
-- =========================================================================
function addon:InitializeEventDispatcher()
    if not self.EventDispatcher then return end
    
    -- Initialize mapping table
    self.EventDispatcher:Initialize()
    
    -- Register global filters (after all middlewares are registered)
    self.EventDispatcher:RegisterFilters()
    
    -- Debug information
    if self.Debug then
        local middlewareCount = 0
        for stage, middlewares in pairs(self.EventDispatcher.middlewares) do
            middlewareCount = middlewareCount + #middlewares
        end
        
        self:Debug(string.format("EventDispatcher initialized: %d middlewares", middlewareCount))
    end
end
