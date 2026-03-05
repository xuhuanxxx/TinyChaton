local addonName, addon = ...

function addon:InitServiceContainer()
    if not self.DIContainer or not self.DIContainer.Container then
        self:Error("DI container module missing")
        return
    end

    local c = self.DIContainer.Container:New()

    c:RegisterValue("Addon", self)
    c:RegisterSingleton("TinyReactor", function()
        if not self.TinyReactor then
            error("TinyReactor not initialized")
        end
        return self.TinyReactor
    end)

    c:RegisterSingleton("EventBus", function()
        return {
            Register = function(_, event, fn, owner)
                return self:RegisterCallback(event, fn, owner)
            end,
            Unregister = function(_, event, owner)
                return self:UnregisterCallback(event, owner)
            end,
            Emit = function(_, event, ...)
                return self:FireEvent(event, ...)
            end,
        }
    end)

    c:RegisterSingleton("ChatGateway", function()
        return self.Gateway
    end)

    c:RegisterSingleton("StreamVisibilityService", function()
        return self.StreamVisibilityService
    end)

    c:RegisterSingleton("SettingsSubscriberRegistry", function()
        if not self.SettingsSubscriberRegistry then
            error("SettingsSubscriberRegistry not initialized")
        end
        return self.SettingsSubscriberRegistry
    end)

    c:RegisterSingleton("SettingsOrchestrator", function(registry, eventBus)
        if not self.SettingsOrchestrator then
            error("SettingsOrchestrator not initialized")
        end
        if type(registry.Validate) ~= "function" then
            error("SettingsSubscriberRegistry invalid")
        end
        if type(eventBus.Emit) ~= "function" then
            error("EventBus invalid")
        end
        return self.SettingsOrchestrator
    end, { "SettingsSubscriberRegistry", "EventBus" })

    c:RegisterSingleton("FilterSettingsService", function()
        if not self.FilterSettingsService then
            error("FilterSettingsService not initialized")
        end
        return self.FilterSettingsService
    end)

    c:RegisterSingleton("ChatFontService", function()
        if not self.ChatFontService then
            error("ChatFontService not initialized")
        end
        return self.ChatFontService
    end)

    c:RegisterSingleton("StickyChannelService", function()
        if not self.StickyChannelService then
            error("StickyChannelService not initialized")
        end
        return self.StickyChannelService
    end)

    c:RegisterSingleton("AutoJoinService", function()
        if not self.AutoJoinService then
            error("AutoJoinService not initialized")
        end
        return self.AutoJoinService
    end)

    c:RegisterSingleton("AutoWelcomeService", function()
        if not self.AutoWelcomeService then
            error("AutoWelcomeService not initialized")
        end
        return self.AutoWelcomeService
    end)

    c:RegisterSingleton("ShelfService", function()
        if not self.ShelfSettingsService then
            error("ShelfSettingsService not initialized")
        end
        return self.ShelfSettingsService
    end)

    self.ServiceContainer = c
end

function addon:ValidateRequiredServices()
    local required = {
        "Addon",
        "TinyReactor",
        "EventBus",
        "ChatGateway",
        "StreamVisibilityService",
        "SettingsSubscriberRegistry",
        "SettingsOrchestrator",
        "FilterSettingsService",
        "ChatFontService",
        "StickyChannelService",
        "AutoJoinService",
        "AutoWelcomeService",
        "ShelfService",
    }

    if addon.TinyCoreDIValidation and type(addon.TinyCoreDIValidation.ResolveRequired) == "function" then
        addon.TinyCoreDIValidation.ResolveRequired(self.ServiceContainer, required)
        return
    end

    for _, name in ipairs(required) do
        self:ResolveRequiredService(name)
    end
end

function addon:RegisterServiceValue(name, value)
    if not self.ServiceContainer then return end
    self.ServiceContainer:RegisterValue(name, value)
end

function addon:RegisterServiceSingleton(name, factoryFn, deps)
    if not self.ServiceContainer then return end
    self.ServiceContainer:RegisterSingleton(name, factoryFn, deps)
end

function addon:RegisterServiceFactory(name, factoryFn, deps)
    if not self.ServiceContainer then return end
    self.ServiceContainer:RegisterFactory(name, factoryFn, deps)
end

function addon:ResolveRequiredService(name)
    if not self.ServiceContainer then
        error(string.format("ResolveRequiredService failed for '%s': service container not initialized", tostring(name)))
    end
    return self.ServiceContainer:Resolve(name)
end

function addon:ResolveOptionalService(name)
    if not self.ServiceContainer then return nil end
    if not self.ServiceContainer.Has or not self.ServiceContainer:Has(name) then
        return nil
    end
    local value, err = self.ServiceContainer:TryResolve(name)
    if err and self.Error then
        self:Error("ResolveOptionalService failed for '%s': %s", tostring(name), tostring(err))
        return nil
    end
    return value
end

function addon:FinalizeServiceContainer()
    if self.ServiceContainer then
        self.ServiceContainer:Freeze()
    end
end
