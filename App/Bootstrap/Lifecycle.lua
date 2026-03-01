local addonName, addon = ...

local function RunPhase(label, fn)
    local ok, err = pcall(fn)
    if not ok then
        if addon.Error then
            addon:Error("Bootstrap %s failed: %s", tostring(label), tostring(err))
        end
        return false
    end
    return true
end

function addon:OnInitialize()
    RunPhase("Phase1 Runtime", function()
        if addon.BootstrapInitContainer then
            addon:BootstrapInitContainer()
        end
    end)

    local dbReady = RunPhase("Phase2 Database", function()
        if addon.BootstrapInitDatabase and not addon:BootstrapInitDatabase() then
            error("database not ready")
        end
    end)

    if not dbReady then
        return
    end

    RunPhase("Phase3 Core Services", function()
        if addon.InitPolicyEngine then addon:InitPolicyEngine() end
        if addon.InitEnvironmentService then addon:InitEnvironmentService() end
        if addon.InitFeatureRegistry then addon:InitFeatureRegistry() end
        if addon.InitEvents then addon:InitEvents() end
        if addon.RegisterSettings then
            local ok, err = pcall(addon.RegisterSettings, addon)
            if not ok and addon.Error then
                addon:Error("Settings registration failed: %s", tostring(err))
            end
        end
    end)

    RunPhase("Phase4 Frame Hooks", function()
        if addon.SetupChatFrameHooks then
            addon:SetupChatFrameHooks()
        end
        if addon.InitializeEventDispatcher then
            addon:InitializeEventDispatcher()
        end
    end)

    RunPhase("Phase5 Modules", function()
        if addon.BootstrapInitModules then
            addon:BootstrapInitModules()
        end
        if addon.ReconcileFeatures then
            addon:ReconcileFeatures()
        end
    end)

    RunPhase("Phase6 Apply Settings", function()
        local L = addon.L
        if addon.db and not addon.db.enabled then
            print("|cFF00FF00" .. L["LABEL_ADDON_NAME"] .. "|r" .. L["MSG_DISABLED"])
        else
            print("|cFF00FF00" .. L["LABEL_ADDON_NAME"] .. "|r" .. L["MSG_LOADED"])
        end
        if addon.ApplyAllSettings then
            addon:ApplyAllSettings()
        end
        if addon.MemoryDiagnostics and addon.MemoryDiagnostics.StartSession then
            addon.MemoryDiagnostics:StartSession()
        end
        if addon.BootstrapFinalizeContainer then
            addon:BootstrapFinalizeContainer()
        end
    end)
end

local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:SetScript("OnEvent", function(self, event, loadedAddon)
    if event ~= "ADDON_LOADED" then return end
    if loadedAddon ~= addonName then return end
    addon:OnInitialize()
    self:UnregisterEvent("ADDON_LOADED")
end)
