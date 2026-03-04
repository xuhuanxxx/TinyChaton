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

local function RequireMethod(obj, methodName)
    local fn = obj and obj[methodName]
    if type(fn) ~= "function" then
        error(string.format("missing required method: %s", tostring(methodName)))
    end
    return fn
end

local function WarnOptionalMissing(methodName)
    if addon.Warn then
        addon:Warn("Optional bootstrap method is missing: %s", tostring(methodName))
    end
end

function addon:OnInitialize()
    local runtimeReady = RunPhase("Phase1 Runtime", function()
        local initContainer = RequireMethod(addon, "BootstrapInitContainer")
        if initContainer(addon) ~= true then
            error("service container not ready")
        end
    end)
    if not runtimeReady then
        return
    end

    local dbReady = RunPhase("Phase2 Database", function()
        local initDatabase = RequireMethod(addon, "BootstrapInitDatabase")
        if initDatabase(addon) ~= true then
            error("database not ready")
        end
    end)

    if not dbReady then
        return
    end

    local coreReady = RunPhase("Phase3 Core Services", function()
        RequireMethod(addon, "ValidateChatEventDerivation")(addon)
        RequireMethod(addon, "ValidateRegistryDefinitions")(addon)
        RequireMethod(addon, "InitChatRuntimeMode")(addon)
        RequireMethod(addon, "InitEnvironmentGate")(addon)
        RequireMethod(addon, "InitRuntimeCoordinator")(addon)
        RequireMethod(addon, "InitFeatureRegistry")(addon)
        RequireMethod(addon, "InitEvents")(addon)

        if addon.RegisterSettings then
            local ok, err = pcall(addon.RegisterSettings, addon)
            if not ok and addon.Error then
                addon:Error("Settings registration failed: %s", tostring(err))
            end
        else
            WarnOptionalMissing("RegisterSettings")
        end
    end)
    if not coreReady then
        return
    end

    local frameHooksReady = RunPhase("Phase4 Frame Hooks", function()
        RequireMethod(addon, "InitializeStreamEventDispatcher")(addon)
    end)
    if not frameHooksReady then
        return
    end

    local modulesReady = RunPhase("Phase5 Modules", function()
        RequireMethod(addon, "BootstrapInitModules")(addon)
        RequireMethod(addon, "ReconcileFeatures")(addon)
    end)
    if not modulesReady then
        return
    end

    RunPhase("Phase6 Commit Settings", function()
        local L = addon.L
        if addon.db and not addon.db.enabled then
            print("|cFF00FF00" .. L["LABEL_ADDON_NAME"] .. "|r" .. L["MSG_DISABLED"])
        else
            print("|cFF00FF00" .. L["LABEL_ADDON_NAME"] .. "|r" .. L["MSG_LOADED"])
        end
        RequireMethod(addon, "CommitSettings")(addon, "bootstrap_init", "all")

        if addon.MemoryDiagnostics and addon.MemoryDiagnostics.StartSession then
            addon.MemoryDiagnostics:StartSession()
        end

        if addon.ValidateRequiredServices then
            addon:ValidateRequiredServices()
        else
            WarnOptionalMissing("ValidateRequiredServices")
        end

        if addon.BootstrapFinalizeContainer then
            addon:BootstrapFinalizeContainer()
        else
            WarnOptionalMissing("BootstrapFinalizeContainer")
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
