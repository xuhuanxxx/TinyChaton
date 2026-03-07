local addonName, addon = ...

addon.TinyCoreSettingsOrchestrator = addon.TinyCoreSettingsOrchestrator or {}
local Orchestrator = addon.TinyCoreSettingsOrchestrator
Orchestrator.__index = Orchestrator

function Orchestrator:New(opts)
    local options = type(opts) == "table" and opts or {}
    return setmetatable({
        getEventBus = options.getEventBus,
        getRegistry = options.getRegistry,
    }, self)
end

function Orchestrator:_requireEventBus()
    if type(self.getEventBus) ~= "function" then
        error("SettingsOrchestrator missing event bus provider")
    end
    local bus = self.getEventBus()
    if type(bus) ~= "table" or type(bus.Emit) ~= "function" then
        error("SettingsOrchestrator event bus is invalid")
    end
    return bus
end

function Orchestrator:_requireRegistry()
    if type(self.getRegistry) ~= "function" then
        error("SettingsOrchestrator missing subscriber registry provider")
    end
    local registry = self.getRegistry()
    if type(registry) ~= "table" or type(registry.Validate) ~= "function" then
        error("SettingsOrchestrator subscriber registry is invalid")
    end
    return registry
end

local function BuildFailurePrefix(intent, phase, key)
    return string.format(
        "Settings intent failed (trace=%s, operation=%s, reason=%s, source=%s, phase=%s, key=%s)",
        tostring(intent and intent.traceId),
        tostring(intent and intent.operation),
        tostring(intent and intent.reason),
        tostring(intent and intent.source),
        tostring(phase),
        tostring(key)
    )
end

function Orchestrator:Execute(intent, hooks)
    local eventBus = self:_requireEventBus()
    local registry = self:_requireRegistry()
    local lifecycle = type(hooks) == "table" and hooks or {}

    eventBus:Emit("SETTINGS_INTENT_STARTED", intent)
    registry:Validate()

    eventBus:Emit("SETTINGS_MUTATION_APPLYING", intent)
    if type(lifecycle.applyMutations) == "function" then
        local ok, err = pcall(lifecycle.applyMutations, lifecycle, intent)
        if not ok then
            error(BuildFailurePrefix(intent, "mutation", "mutation") .. ": " .. tostring(err))
        end
    end
    eventBus:Emit("SETTINGS_MUTATION_APPLIED", intent)

    local skipSubscribers = lifecycle.skipSubscribers == true
    if type(lifecycle.skipSubscribers) == "function" then
        local ok, result = pcall(lifecycle.skipSubscribers, lifecycle, intent)
        if not ok then
            error(BuildFailurePrefix(intent, "mutation", "skip_subscribers") .. ": " .. tostring(result))
        end
        skipSubscribers = result == true
    end

    for _, phase in ipairs(registry:GetPhaseOrder()) do
        local subscribers = registry:GetByPhase(phase)
        if #subscribers > 0 and not skipSubscribers then
            eventBus:Emit("SETTINGS_PHASE_APPLYING", phase, intent)
            for _, spec in ipairs(subscribers) do
                local ok, err = pcall(spec.apply, intent)
                if not ok then
                    error(BuildFailurePrefix(intent, phase, spec.key) .. ": " .. tostring(err))
                end
            end
            eventBus:Emit("SETTINGS_PHASE_APPLIED", phase, intent)
        end
    end

    eventBus:Emit("SETTINGS_UI_REFRESHING", intent)
    if type(lifecycle.refreshUI) == "function" then
        local ok, err = pcall(lifecycle.refreshUI, lifecycle, intent)
        if not ok then
            error(BuildFailurePrefix(intent, "ui", "refresh") .. ": " .. tostring(err))
        end
    end
    eventBus:Emit("SETTINGS_INTENT_COMPLETED", intent)
    return intent
end
