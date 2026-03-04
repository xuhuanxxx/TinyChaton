local addonName, addon = ...

addon.SettingsOrchestrator = addon.SettingsOrchestrator or {}

local function BuildTraceId()
    local now = time and time() or 0
    local seed = math.random(100000, 999999)
    return string.format("settings-%d-%d", now, seed)
end

local function BuildContext(reason, scope)
    return {
        reason = reason or "manual",
        scope = scope or "all",
        timestamp = time and time() or 0,
        profileName = (addon.GetCurrentProfile and addon:GetCurrentProfile()) or "unknown",
        traceId = BuildTraceId(),
    }
end

function addon.SettingsOrchestrator:Run(ctx)
    local context = ctx or BuildContext("manual", "all")
    if type(context.reason) ~= "string" or context.reason == "" then
        context.reason = "manual"
    end
    if type(context.scope) ~= "string" or context.scope == "" then
        context.scope = "all"
    end
    if type(context.timestamp) ~= "number" then
        context.timestamp = time and time() or 0
    end
    if type(context.profileName) ~= "string" or context.profileName == "" then
        context.profileName = (addon.GetCurrentProfile and addon:GetCurrentProfile()) or "unknown"
    end
    if type(context.traceId) ~= "string" or context.traceId == "" then
        context.traceId = BuildTraceId()
    end

    local eventBus = addon:ResolveRequiredService("EventBus")
    local registry = addon:ResolveRequiredService("SettingsSubscriberRegistry")

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

function addon:CommitSettings(reason, scope)
    local context = BuildContext(reason, scope)
    local eventBus = addon:ResolveRequiredService("EventBus")

    if addon.db and addon.db.enabled == false then
        if addon.Shelf and addon.Shelf.frame then
            addon.Shelf.frame:Hide()
        end
        addon:Shutdown()
        eventBus:Emit("SETTINGS_COMMITTING", context)
        eventBus:Emit("SETTINGS_COMMITTED", context)
        return context
    end

    local orchestrator = addon:ResolveRequiredService("SettingsOrchestrator")
    return orchestrator:Run(context)
end
