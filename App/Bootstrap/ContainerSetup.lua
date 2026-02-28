local addonName, addon = ...

function addon:BootstrapInitContainer()
    if not addon.InitServiceContainer then
        return true
    end

    local ok, err = pcall(addon.InitServiceContainer, addon)
    if not ok then
        if addon.Error then
            addon:Error("Service container init failed: %s", tostring(err))
        end
        return false
    end

    return true
end

function addon:BootstrapFinalizeContainer()
    if addon.FinalizeServiceContainer then
        local ok, err = pcall(addon.FinalizeServiceContainer, addon)
        if not ok and addon.Error then
            addon:Error("Service container finalize failed: %s", tostring(err))
        end
    end
end
