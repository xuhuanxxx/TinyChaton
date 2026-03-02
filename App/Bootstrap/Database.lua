local addonName, addon = ...

function addon:BootstrapInitDatabase()
    if type(addon.InitConfig) ~= "function" then
        print("|cFFFF0000TinyChaton:|r Missing required database init method (InitConfig)")
        return false
    end

    addon:InitConfig()

    if not addon.db then
        print("|cFFFF0000TinyChaton:|r Failed to initialize database")
        return false
    end

    return true
end
