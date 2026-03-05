local addonName, addon = ...

if not addon.TinyCoreDIContainer or type(addon.TinyCoreDIContainer.New) ~= "function" then
    error("TinyCore DI Container is not initialized")
end

addon.DIContainer = addon.DIContainer or {}
addon.DIContainer.Container = addon.TinyCoreDIContainer
