local addonName, addon = ...
local AddMessageFilter = _G["Chat" .. "Frame_AddMessageEventFilter"]
local RemoveMessageFilter = _G["Chat" .. "Frame_RemoveMessageEventFilter"]

-- =========================================================================
-- Chat Pipeline with Middleware Stages
-- Provides a unified entry point for chat message processing
-- Supports 4 stages: VALIDATE, BLOCK, TRANSFORM, PERSIST
-- =========================================================================

addon.ChatPipeline = addon.ChatPipeline or {}
local Dispatcher = addon.ChatPipeline

-- Middleware registry by stage
Dispatcher.middlewares = {
    VALIDATE = {},  -- Pre-processing (cannot block)
    BLOCK = {},       -- Filtering/blocking stage (can return true to block)
    TRANSFORM = {},       -- Enhancement stage (modify text)
    PERSIST = {}           -- Logging stage (cannot block)
}

-- Registered event filters
Dispatcher.registeredFilters = {}
Dispatcher.filterCallbacks = Dispatcher.filterCallbacks or {}
Dispatcher.isFiltersRegistered = Dispatcher.isFiltersRegistered or false

local function IsChannelFamilyEvent(eventName)
    return type(eventName) == "string" and eventName:find("^CHAT_MSG_CHANNEL", 1, false) == 1
end

--- Initialize event dispatcher
function Dispatcher:Initialize()
    self.registeredFilters = self.registeredFilters or {}
    self.filterCallbacks = self.filterCallbacks or {}
    self.isFiltersRegistered = self.isFiltersRegistered or false

    if not addon.STREAM_REGISTRY then return end
end

--- Register a middleware function
--- @param stage string Stage name: "VALIDATE", "BLOCK", "TRANSFORM", "PERSIST"
--- @param priority number Lower numbers execute first (e.g., 10, 20, 30)
--- @param name string Middleware name for debugging
--- @param fn function Middleware function(chatData) -> boolean|nil
function Dispatcher:RegisterMiddleware(stage, priority, name, fn)
    if addon.Utils and addon.Utils.EnsureString then
        stage = addon.Utils.EnsureString(stage, "")
    end
    if not self.middlewares[stage] then
        error("Invalid middleware stage: " .. tostring(stage))
    end

    if type(fn) ~= "function" then
        error("Middleware function must be a function")
    end

    table.insert(self.middlewares[stage], {
        name = name or "unnamed",
        priority = priority or 100,
        fn = fn
    })

    -- Sort by priority after insertion
    table.sort(self.middlewares[stage], function(a, b)
        if a.priority ~= b.priority then
            return a.priority < b.priority
        end
        return tostring(a.name) < tostring(b.name)
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
--- @return boolean True if any BLOCK middleware marked a match
function Dispatcher:RunMiddlewares(stage, chatData)
    if addon.Utils and addon.Utils.EnsureString then
        stage = addon.Utils.EnsureString(stage, "")
    end
    local hasProfiler = addon.Profiler and addon.Profiler.Start and addon.Profiler.Stop
    local profileLabel = nil
    if stage == "BLOCK" or stage == "PERSIST" then
        profileLabel = "ChatPipeline.Middleware." .. stage
    end
    if hasProfiler and profileLabel then
        addon.Profiler:Start(profileLabel)
    end

    if addon.Can then
        local caps = addon.CAPABILITIES or {}
        if (stage == "VALIDATE" or stage == "BLOCK" or stage == "TRANSFORM")
            and not addon:Can(caps.PROCESS_CHAT_DATA or "PROCESS_CHAT_DATA") then
            if hasProfiler and profileLabel then
                addon.Profiler:Stop(profileLabel)
            end
            return false
        end
        if stage == "PERSIST" and not addon:Can(caps.PERSIST_CHAT_DATA or "PERSIST_CHAT_DATA") then
            if hasProfiler and profileLabel then
                addon.Profiler:Stop(profileLabel)
            end
            return false
        end
    end

    local middlewares = self.middlewares[stage]
    if not middlewares then
        if hasProfiler and profileLabel then
            addon.Profiler:Stop(profileLabel)
        end
        return false
    end

    for _, middleware in ipairs(middlewares) do
        local ok, result = pcall(middleware.fn, chatData)

        if not ok then
            -- Log error but don't break the pipeline
            if addon.Debug then
                addon:Debug(string.format("Middleware error [%s:%s]: %s",
                    stage, middleware.name, tostring(result)))
            end
        elseif result == true and stage == "BLOCK" then
            chatData.isBlocked = true
        end
    end

    if hasProfiler and profileLabel then
        addon.Profiler:Stop(profileLabel)
    end
    return chatData.isBlocked == true and stage == "BLOCK"
end

--- Core event handler with middleware pipeline
--- @param frame table ChatFrame object
--- @param event string Event name
--- @param ... Event arguments
--- @return boolean Whether to block message
function Dispatcher:OnChatEvent(frame, event, ...)
    if addon.Gateway and addon.Gateway.Inbound and not addon.Gateway.Inbound:Allow(event, frame, ...) then
        return false
    end
    if not addon.Gateway and (not addon.db or not addon.db.enabled) then
        return false
    end

    local packedArgs = addon.Utils.PackArgs(...)

    -- Create ChatData object
    local chatData = addon.ChatData:New(frame, event, ...)

    -- Skip if chatData is nil (e.g., secret value from Blizzard)
    if not chatData then
        return false
    end

    -- Stage 1: VALIDATE
    -- Pre-processing stage (cannot block, but can modify chatData)
    self:RunMiddlewares("VALIDATE", chatData)

    -- Stage 2: BLOCK
    -- Filtering stage now only marks metadata (display decision is centralized).
    self:RunMiddlewares("BLOCK", chatData)

    -- Stage 3: TRANSFORM
    -- Enrichment stage (internal metadata only; no argument repacking)
    self:RunMiddlewares("TRANSFORM", chatData)

    local shouldHide = false
    if addon.VisibilityPolicy and addon.VisibilityPolicy.IsVisibleRealtime then
        local ok, visible = pcall(addon.VisibilityPolicy.IsVisibleRealtime, addon.VisibilityPolicy, chatData)
        if ok and visible == false then
            shouldHide = true
        end
    end

    -- Stage 4: PERSIST
    -- Logging stage always runs to keep snapshot/data ingestion complete.
    self:RunMiddlewares("PERSIST", chatData)

    local emitted = false
    if not shouldHide and addon.MessageFormatter and addon.MessageFormatter.BuildRealtimeLineFromChatData and addon.EmitRenderedChatLine then
        local line, lineErr = addon.MessageFormatter.BuildRealtimeLineFromChatData(chatData)
        if type(line) ~= "table" then
            if addon.WarnOnce then
                addon:WarnOnce(
                    "event_router:line_build:" .. tostring(event),
                    "Realtime line build failed for %s: %s",
                    tostring(event),
                    tostring(lineErr)
                )
            elseif addon.Warn then
                addon:Warn("Realtime line build failed for %s: %s", tostring(event), tostring(lineErr))
            end
        else
            emitted = addon:EmitRenderedChatLine(line, frame, { preferTimestampConfig = false }) == true
        end
    end

    if not shouldHide and not emitted
        and packedArgs
        and type(packedArgs[1]) == "string"
        and addon.Gateway
        and addon.Gateway.Display
        and addon.Gateway.Display.Transform then
        local msg = packedArgs[1]
        local transformedMsg = msg
        local ok, nextMsg = pcall(function()
            local outMsg = addon.Gateway.Display:Transform(frame, msg, nil, nil, nil, addon.Utils.PackArgs())
            return outMsg
        end)
        if ok and type(nextMsg) == "string" then
            transformedMsg = nextMsg
        end
        packedArgs[1] = transformedMsg
    end

    addon.ChatData:Release(chatData)

    if shouldHide or emitted then
        return true
    end
    return shouldHide, addon.Utils.UnpackArgs(packedArgs)
end

--- Register event filters for all chat events
function Dispatcher:RegisterFilters()
    if self.isFiltersRegistered then
        return
    end

    local events = {}
    local seen = {}
    for _, eventName in ipairs(addon.CHAT_EVENTS or {}) do
        if not seen[eventName] then
            events[#events + 1] = eventName
            seen[eventName] = true
        end
    end
    if not seen["CHAT_MSG_SYSTEM"] then
        events[#events + 1] = "CHAT_MSG_SYSTEM"
    end

    local isBypassed = addon.IsChatBypassed and addon:IsChatBypassed()
    for _, event in ipairs(events) do
        if not (isBypassed and IsChannelFamilyEvent(event)) then
            if not self.registeredFilters[event] then
                local callback = self.filterCallbacks[event]
                if not callback then
                    callback = function(frame, eventName, ...)
                        return self:OnChatEvent(frame, eventName, ...)
                    end
                    self.filterCallbacks[event] = callback
                end

                AddMessageFilter(event, callback)
                self.registeredFilters[event] = true
            end
        end
    end

    self.isFiltersRegistered = true
end

function Dispatcher:RebuildFiltersForCurrentMode()
    self:UnregisterFilters()
    self:RegisterFilters()
end

function Dispatcher:UnregisterFilters()
    if not self.isFiltersRegistered then
        return
    end

    for event, callback in pairs(self.filterCallbacks or {}) do
        if self.registeredFilters[event] and callback and RemoveMessageFilter then
            RemoveMessageFilter(event, callback)
            self.registeredFilters[event] = nil
        end
    end

    self.isFiltersRegistered = false
end



-- =========================================================================
-- Initialization
-- =========================================================================
function addon:InitializeChatPipeline()
    if not self.ChatPipeline then return end

    -- Initialize mapping table
    self.ChatPipeline:Initialize()

    local function EnableDispatcherFilters()
        self.ChatPipeline:RebuildFiltersForCurrentMode()
    end

    local function DisableDispatcherFilters()
        self.ChatPipeline:UnregisterFilters()
    end

    self:RegisterFeature("ChatPipelineFilters", {
        requires = { "READ_CHAT_EVENT" },
        plane = self.RUNTIME_PLANES and self.RUNTIME_PLANES.CHAT_DATA or "CHAT_DATA",
        onEnable = EnableDispatcherFilters,
        onDisable = DisableDispatcherFilters,
    })

    if self.Debug then
        local middlewareCount = 0
        for _, middlewares in pairs(self.ChatPipeline.middlewares) do
            middlewareCount = middlewareCount + #middlewares
        end

        self:Debug(string.format("ChatPipeline initialized: %d middlewares", middlewareCount))
    end
end
