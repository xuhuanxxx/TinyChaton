local addonName, addon = ...

if not addon.TinyCoreSettingsOrchestrator or type(addon.TinyCoreSettingsOrchestrator.New) ~= "function" then
    error("TinyCore SettingsOrchestrator is not initialized")
end

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

addon.SettingsOrchestrator = addon.SettingsOrchestrator or addon.TinyCoreSettingsOrchestrator:New({
    getEventBus = function()
        return addon:ResolveRequiredService("EventBus")
    end,
    getRegistry = function()
        return addon:ResolveRequiredService("SettingsSubscriberRegistry")
    end,
})

function addon.SettingsOrchestrator:NormalizeContext(ctx)
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
    return context
end

local CoreRun = addon.SettingsOrchestrator.Run
function addon.SettingsOrchestrator:Run(ctx)
    return CoreRun(self, self:NormalizeContext(ctx))
end

function addon:CommitSettings(reason, scope)
    local context = addon.SettingsOrchestrator:NormalizeContext(BuildContext(reason, scope))
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
