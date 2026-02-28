local addonName, addon = ...

function addon:BootstrapInitModules()
    for _, mod in ipairs(self.moduleRegistry or {}) do
        local ok, err = pcall(mod.init, addon)
        if not ok and addon.Error then
            addon:Error("Failed to init module %s: %s", tostring(mod.name), tostring(err))
        end
    end
end
