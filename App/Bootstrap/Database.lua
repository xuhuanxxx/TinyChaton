local addonName, addon = ...

function addon:BootstrapInitDatabase()
    if addon.InitConfig then
        addon:InitConfig()
    end

    if not addon.db then
        print("|cFFFF0000TinyChaton:|r Failed to initialize database")
        return false
    end

    return true
end
