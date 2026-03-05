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

function Orchestrator:Run(context)
    local eventBus = self:_requireEventBus()
    local registry = self:_requireRegistry()

    eventBus:Emit("SETTINGS_COMMITTING", context)
    registry:Validate()

    for _, phase in ipairs(registry:GetPhaseOrder()) do
        local subscribers = registry:GetByPhase(phase)
        if #subscribers > 0 then
            eventBus:Emit("SETTINGS_PHASE_COMMITTING", phase, context)
            for _, spec in ipairs(subscribers) do
                local ok, err = pcall(spec.apply, context)
                if not ok then
                    error(string.format(
                        "Settings commit failed (trace=%s, phase=%s, key=%s): %s",
                        tostring(context.traceId),
                        tostring(phase),
                        tostring(spec.key),
                        tostring(err)
                    ))
                end
            end
            eventBus:Emit("SETTINGS_PHASE_COMMITTED", phase, context)
        end
    end

    eventBus:Emit("SETTINGS_COMMITTED", context)
    return context
end
