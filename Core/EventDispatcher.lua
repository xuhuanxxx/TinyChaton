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

-- Event to Stream mapping (legacy support)
Dispatcher.eventToStreams = {}

--- Initialize event dispatcher
function Dispatcher:Initialize()
    self.eventToStreams = {}
    self.registeredFilters = {}
    
    if not addon.STREAM_REGISTRY then return end
    
    -- Build event to stream mapping for legacy compatibility
    for categoryKey, category in pairs(addon.STREAM_REGISTRY) do
        for subKey, subCategory in pairs(category) do
            for _, stream in ipairs(subCategory) do
                if stream.events then
                    for _, event in ipairs(stream.events) do
                        if not self.eventToStreams[event] then
                            self.eventToStreams[event] = {}
                        end
                        table.insert(self.eventToStreams[event], stream.key)
                    end
                end
            end
        end
    end
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

--- Execute middlewares for a specific stage
--- @param stage string Stage name
--- @param chatData table ChatData object
--- @return boolean True if message should be blocked (FILTER stage only)
local function ExecuteStage(stage, chatData)
    local middlewares = Dispatcher.middlewares[stage]
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
--- @param event string Event name
--- @param ... Event arguments
--- @return boolean|nil, ... Whether to block message, modified arguments
function Dispatcher:OnChatEvent(event, ...)
    -- Skip if addon is disabled
    if not addon.db or not addon.db.enabled then
        return false, ...
    end
    
    -- Create ChatData object
    local chatData = addon.ChatData:New(event, ...)
    
    -- Stage 1: PRE_PROCESS
    -- Pre-processing stage (cannot block, but can modify chatData)
    ExecuteStage("PRE_PROCESS", chatData)
    
    -- Stage 2: FILTER
    -- Filtering stage (can block messages)
    if ExecuteStage("FILTER", chatData) then
        return true  -- Block message
    end
    
    -- Stage 3: ENRICH
    --Enhancement stage (modify text, add highlighting, etc.)
    ExecuteStage("ENRICH", chatData)
    
    -- Stage 4: LOG
    -- Logging stage (cannot block, for snapshot/copy caching)
    if not chatData.isBlocked then
        ExecuteStage("LOG", chatData)
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
    
    for _, event in ipairs(events) do
        if not self.registeredFilters[event] then
            ChatFrame_AddMessageEventFilter(event, function(_, _, ...)
                return self:OnChatEvent(event, ...)
            end)
            
            self.registeredFilters[event] = true
        end
    end
end

--- Get streams for an event (legacy compatibility)
--- @param event string Event name
--- @return table Stream keys
function Dispatcher:GetStreamsForEvent(event)
    return self.eventToStreams[event] or {}
end

--- Check if stream listens to event (legacy compatibility)
--- @param streamKey string Stream key
--- @param event string Event name
--- @return boolean
function Dispatcher:IsStreamListeningToEvent(streamKey, event)
    local streamKeys = self.eventToStreams[event]
    if not streamKeys then return false end
    
    for _, key in ipairs(streamKeys) do
        if key == streamKey then
            return true
        end
    end
    
    return false
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
        local eventCount = 0
        for _ in pairs(self.EventDispatcher.eventToStreams) do
            eventCount = eventCount + 1
        end
        
        local middlewareCount = 0
        for stage, middlewares in pairs(self.EventDispatcher.middlewares) do
            middlewareCount = middlewareCount + #middlewares
        end
        
        self:Debug(string.format("EventDispatcher initialized: %d events, %d middlewares", 
            eventCount, middlewareCount))
    end
end
