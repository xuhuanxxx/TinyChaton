local addonName, addon = ...

if not addon.TinyCoreSettingsSubscriberRegistry or type(addon.TinyCoreSettingsSubscriberRegistry.New) ~= "function" then
    error("TinyCore SettingsSubscriberRegistry is not initialized")
end

addon.SettingsSubscriberRegistry = addon.SettingsSubscriberRegistry or addon.TinyCoreSettingsSubscriberRegistry:New()
