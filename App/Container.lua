local addonName, addon = ...

addon.Services = addon.Services or {}

function addon:InitServiceContainer()
    self.Services.EventBus = {
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

    self.Services.ChatGateway = self.Gateway
    self.Services.VisibilityPolicy = self.VisibilityPolicy
end
