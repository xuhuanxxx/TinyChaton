local addonName, addon = ...

if not addon.TinyCoreSettingsOrchestrator or type(addon.TinyCoreSettingsOrchestrator.New) ~= "function" then
    error("TinyCore SettingsOrchestrator is not initialized")
end

local VALID_OPERATIONS = {
    commit = true,
    reset = true,
    profile_switch = true,
    bootstrap_sync = true,
}

local function BuildTraceId()
    local now = time and time() or 0
    local seed = math.random(100000, 999999)
    return string.format("settings-%d-%d", now, seed)
end

local function InferSource(intent)
    if intent.operation == "profile_switch" then
        return "profile_dropdown"
    end
    if intent.operation == "bootstrap_sync" then
        return "bootstrap"
    end
    if intent.operation == "reset" then
        return intent.pageKey and "page_button" or "global_reset"
    end
    return "manual"
end

local function BuildIntent(reasonOrIntent, scope, source)
    if type(reasonOrIntent) == "table" then
        return addon.Utils and addon.Utils.DeepCopy and addon.Utils.DeepCopy(reasonOrIntent) or reasonOrIntent
    end

    return {
        operation = "commit",
        reason = reasonOrIntent,
        scope = scope,
        source = source,
    }
end

local function MergeRefreshControls(target, controls)
    if type(controls) ~= "table" then
        return
    end
    for _, control in ipairs(controls) do
        target[#target + 1] = control
    end
end

local function ResolvePageRegistry()
    local registry = addon.SettingsIntentRegistry
    if type(registry) ~= "table" or type(registry.GetPageSpec) ~= "function" then
        error("SettingsIntentRegistry is not initialized")
    end
    return registry
end

local function ApplyRuntimeDisabledState()
    if addon.db and addon.db.enabled == false then
        if addon.Shelf and addon.Shelf.frame then
            addon.Shelf.frame:Hide()
        end
        if addon.Shutdown then
            addon:Shutdown()
        end
    end
end

local function BuildUiState(intent)
    return {
        refreshControls = {},
        refreshSettingsPanel = intent.refreshUI ~= false,
        refreshShelf = false,
        refreshShelfList = false,
        refreshShelfPreview = false,
    }
end

addon.SettingsOrchestrator = addon.SettingsOrchestrator or addon.TinyCoreSettingsOrchestrator:New({
    getEventBus = function()
        return addon:ResolveRequiredService("EventBus")
    end,
    getRegistry = function()
        return addon:ResolveRequiredService("SettingsSubscriberRegistry")
    end,
})

function addon.SettingsOrchestrator:NormalizeIntent(intentLike)
    local intent = BuildIntent(intentLike)

    if type(intent.operation) ~= "string" or not VALID_OPERATIONS[intent.operation] then
        intent.operation = "commit"
    end
    if type(intent.reason) ~= "string" or intent.reason == "" then
        intent.reason = "manual"
    end
    if type(intent.scope) ~= "string" or intent.scope == "" then
        intent.scope = "all"
    end
    if type(intent.pageKey) ~= "string" or intent.pageKey == "" then
        intent.pageKey = nil
    end
    if type(intent.source) ~= "string" or intent.source == "" then
        intent.source = InferSource(intent)
    end
    if type(intent.timestamp) ~= "number" then
        intent.timestamp = time and time() or 0
    end
    if type(intent.traceId) ~= "string" or intent.traceId == "" then
        intent.traceId = BuildTraceId()
    end
    if type(intent.profileName) ~= "string" or intent.profileName == "" then
        intent.profileName = (addon.GetCurrentProfile and addon:GetCurrentProfile()) or "unknown"
    end
    if intent.refreshUI == nil then
        intent.refreshUI = intent.operation ~= "bootstrap_sync"
    end
    if intent.clearRuleCaches == nil then
        intent.clearRuleCaches = (intent.operation == "profile_switch") or (intent.operation == "bootstrap_sync")
    end

    return intent
end

function addon.SettingsOrchestrator:_applyIntentMutations(intent)
    local pageRegistry = ResolvePageRegistry()
    local uiState = BuildUiState(intent)

    if intent.operation == "reset" then
        if intent.pageKey then
            local spec = pageRegistry:GetPageSpec(intent.pageKey)
            if not spec then
                error("Unknown settings reset page: " .. tostring(intent.pageKey))
            end

            if type(spec.scope) == "string" and spec.scope ~= "" then
                intent.scope = spec.scope
            end

            for _, path in ipairs(spec.writeRootDefaults or {}) do
                pageRegistry:WriteDefault(path, true)
            end
            for _, path in ipairs(spec.writeDefaults or {}) do
                pageRegistry:WriteDefault(path, false)
            end

            MergeRefreshControls(uiState.refreshControls, spec.refreshControls)
            uiState.refreshSettingsPanel = spec.refreshSettingsPanel ~= false and intent.refreshUI ~= false
            uiState.refreshShelf = spec.refreshShelf == true
            uiState.refreshShelfList = spec.refreshShelfList == true
            uiState.refreshShelfPreview = spec.refreshShelfPreview == true

            if spec.clearRuleCaches then
                intent.clearRuleCaches = true
            end
        else
            addon.db.profile = {}
            addon.db.enabled = (addon.DEFAULTS and addon.DEFAULTS.enabled ~= nil) and addon.DEFAULTS.enabled or true
            if addon.SynchronizeConfig then
                addon:SynchronizeConfig(true)
            end
            if addon.EnsureDisplayConfig then
                addon:EnsureDisplayConfig()
            end

            for _, spec in ipairs(pageRegistry:GetOrderedPageSpecs()) do
                MergeRefreshControls(uiState.refreshControls, spec.refreshControls)
                uiState.refreshShelf = uiState.refreshShelf or spec.refreshShelf == true
                uiState.refreshShelfList = uiState.refreshShelfList or spec.refreshShelfList == true
                uiState.refreshShelfPreview = uiState.refreshShelfPreview or spec.refreshShelfPreview == true
            end

            intent.clearRuleCaches = true
        end
    elseif intent.operation == "profile_switch" then
        if not TinyChatonDB.profiles or not TinyChatonDB.profiles[intent.profileName] then
            error("Unknown profile: " .. tostring(intent.profileName))
        end
        local charKey = addon:GetCharacterKey()
        TinyChatonDB.profileKeys[charKey] = intent.profileName
        if addon.UpdateCurrentProfileCache then
            addon:UpdateCurrentProfileCache()
        end
        if addon.SynchronizeConfig then
            addon:SynchronizeConfig(false)
        end
        if addon.EnsureDisplayConfig then
            addon:EnsureDisplayConfig()
        end
        addon:FireEvent("PROFILE_CHANGED", intent.profileName)
        intent.clearRuleCaches = true
    elseif intent.operation == "bootstrap_sync" then
        if addon.SynchronizeConfig then
            addon:SynchronizeConfig(false)
        end
        if addon.EnsureDisplayConfig then
            addon:EnsureDisplayConfig()
        end
    end

    if intent.clearRuleCaches and addon.StreamRuleEngine and addon.StreamRuleEngine.ClearAllCaches then
        addon.StreamRuleEngine:ClearAllCaches(intent.reason or intent.operation or "settings_intent")
    end

    ApplyRuntimeDisabledState()

    self._uiState = uiState
end

function addon.SettingsOrchestrator:_refreshIntentUi(intent)
    local pageRegistry = ResolvePageRegistry()
    local uiState = self._uiState or BuildUiState(intent)

    for _, control in ipairs(uiState.refreshControls or {}) do
        pageRegistry:RefreshControl(control)
    end

    if uiState.refreshSettingsPanel and addon.RefreshAllSettings then
        addon:RefreshAllSettings()
    end
    if uiState.refreshShelf and addon.RefreshShelf then
        addon:RefreshShelf()
    end
    if uiState.refreshShelfList and addon.RefreshShelfList then
        addon.RefreshShelfList()
    end
    if uiState.refreshShelfPreview and addon.RefreshShelfPreview then
        addon.RefreshShelfPreview()
    end

    self._uiState = nil
end

function addon.SettingsOrchestrator:Execute(intentLike)
    local intent = self:NormalizeIntent(intentLike)

    return addon.TinyCoreSettingsOrchestrator.Execute(self, intent, {
        skipSubscribers = function()
            return addon.db and addon.db.enabled == false
        end,
        applyMutations = function()
            self:_applyIntentMutations(intent)
        end,
        refreshUI = function()
            self:_refreshIntentUi(intent)
        end,
    })
end

function addon:ExecuteSettingsIntent(reasonOrIntent, scope, source)
    local intent = BuildIntent(reasonOrIntent, scope, source)
    if type(intent) ~= "table" then
        intent = {}
    end
    if intent.scope == nil and type(scope) == "string" then
        intent.scope = scope
    end
    if intent.source == nil and type(source) == "string" then
        intent.source = source
    end

    local orchestrator = addon:ResolveRequiredService("SettingsOrchestrator")
    return orchestrator:Execute(intent)
end
