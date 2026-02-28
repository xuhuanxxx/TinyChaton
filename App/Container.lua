local addonName, addon = ...

addon.Services = addon.Services or {}

local function CreateLegacyFacade(container)
    local facade = {}

    setmetatable(facade, {
        -- Compatibility facade: optional lookup only.
        -- For required dependencies use addon:ResolveRequiredService(name).
        __index = function(_, key)
            if not container or not container.Has or not container:Has(key) then
                return nil
            end
            local value, err = container:TryResolve(key)
            if err and addon.Error then
                addon:Error("Service resolve failed for '%s': %s", tostring(key), tostring(err))
                return nil
            end
            return value
        end,
        __newindex = function()
            if addon and addon.Warn then
                addon:Warn("Ignoring direct write to addon.Services facade")
            end
        end,
    })

    return facade
end

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

    c:RegisterSingleton("VisibilityPolicy", function()
        return self.VisibilityPolicy
    end)

    self.ServiceContainer = c
    self.Services = CreateLegacyFacade(c)
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

-- Backward-compatible alias; this remains optional semantics.
function addon:ResolveService(name)
    return self:ResolveOptionalService(name)
end

function addon:FinalizeServiceContainer()
    if self.ServiceContainer then
        self.ServiceContainer:Freeze()
    end
end
