local addonName, addon = ...

addon.ActionIntentOrchestrator = addon.ActionIntentOrchestrator or {}
local Orchestrator = addon.ActionIntentOrchestrator

local function CloneTable(input)
    local copy = {}
    if type(input) ~= "table" then
        return copy
    end
    for k, v in pairs(input) do
        copy[k] = v
    end
    return copy
end

local function BuildResult(intent, action, ok, reason, debug)
    local normalizedIntent = type(intent) == "table" and intent or {}
    local actionSpec = type(action) == "table" and action or {}
    return {
        ok = ok == true,
        reason = reason,
        actionKey = normalizedIntent.actionKey,
        targetKind = normalizedIntent.targetKind,
        targetKey = normalizedIntent.targetKey,
        source = normalizedIntent.source,
        plane = actionSpec.actionPlane,
        debug = type(debug) == "table" and debug or {},
    }
end

local function ResolveTarget(intent)
    if type(intent) ~= "table" then
        return nil, "invalid_intent"
    end

    if intent.targetKind == "stream" then
        local stream = addon.GetStreamByKey and addon:GetStreamByKey(intent.targetKey) or nil
        if type(stream) ~= "table" then
            return nil, "invalid_target"
        end
        return stream
    end

    if intent.targetKind == "kit" then
        for _, kit in ipairs(addon.KIT_REGISTRY or {}) do
            if type(kit) == "table" and kit.key == intent.targetKey then
                return kit
            end
        end
        return nil, "invalid_target"
    end

    return nil, "invalid_target"
end

local function TargetMatchesAppliesTo(intent, action, resolvedTarget)
    local appliesTo = type(action) == "table" and action.appliesTo or nil
    if type(appliesTo) ~= "table" then
        return true
    end

    if intent.targetKind == "stream" then
        local stream = resolvedTarget
        if type(stream) ~= "table" then
            return false
        end
        if type(appliesTo.streamKind) == "string" and stream.kind ~= appliesTo.streamKind then
            return false
        end
        if type(appliesTo.streamGroup) == "string" and stream.group ~= appliesTo.streamGroup then
            return false
        end
        if type(appliesTo.streamKeys) == "table" then
            local matched = false
            for _, key in ipairs(appliesTo.streamKeys) do
                if key == intent.targetKey then
                    matched = true
                    break
                end
            end
            if not matched then
                return false
            end
        end
        if type(appliesTo.streamCapabilities) == "table" and addon.GetStreamCapabilities then
            local caps = addon:GetStreamCapabilities(intent.targetKey) or {}
            for capKey, expected in pairs(appliesTo.streamCapabilities) do
                if caps[capKey] ~= expected then
                    return false
                end
            end
        end
        return true
    end

    if intent.targetKind == "kit" and type(appliesTo.kits) == "table" then
        for _, kitKey in ipairs(appliesTo.kits) do
            if kitKey == intent.targetKey then
                return true
            end
        end
        return false
    end

    return true
end

function Orchestrator:ResolveAction(actionKey)
    if type(actionKey) ~= "string" or actionKey == "" then
        return nil, "missing_action"
    end
    local action = addon.ACTION_REGISTRY and addon.ACTION_REGISTRY[actionKey] or nil
    if type(action) ~= "table" then
        return nil, "missing_action"
    end
    return action
end

function Orchestrator:NormalizeIntent(intent)
    if type(intent) ~= "table" then
        return nil, "invalid_intent"
    end

    local normalized = {
        actionKey = intent.actionKey,
        targetKind = intent.targetKind,
        targetKey = intent.targetKey,
        payload = intent.payload,
        source = intent.source,
        context = type(intent.context) == "table" and intent.context or nil,
    }

    if type(normalized.actionKey) ~= "string" or normalized.actionKey == "" then
        return nil, "invalid_intent"
    end
    if type(normalized.source) ~= "string" or normalized.source == "" then
        return nil, "invalid_intent"
    end

    local action, reason = self:ResolveAction(normalized.actionKey)
    if not action then
        return nil, reason
    end

    if type(normalized.targetKind) ~= "string" or normalized.targetKind == "" then
        normalized.targetKind = action.targetKind
    end
    if type(normalized.targetKey) ~= "string" or normalized.targetKey == "" then
        normalized.targetKey = action.targetKey
    end

    if (normalized.targetKind ~= "stream" and normalized.targetKind ~= "kit")
        or type(normalized.targetKey) ~= "string" or normalized.targetKey == "" then
        return nil, "invalid_intent"
    end

    return normalized
end

function Orchestrator:_Evaluate(intent, options)
    local opts = type(options) == "table" and options or {}
    local normalizedIntent, normalizeReason = self:NormalizeIntent(intent)
    if not normalizedIntent then
        return BuildResult(intent, nil, false, normalizeReason, {
            stage = "normalize_intent",
        })
    end

    local action = self:ResolveAction(normalizedIntent.actionKey)
    if not action then
        return BuildResult(normalizedIntent, nil, false, "missing_action", {
            stage = "resolve_action",
        })
    end

    if normalizedIntent.targetKind ~= action.targetKind then
        return BuildResult(normalizedIntent, action, false, "invalid_target", {
            stage = "target_kind",
            expectedTargetKind = action.targetKind,
        })
    end

    local resolvedTarget, targetReason = ResolveTarget(normalizedIntent)
    if not resolvedTarget then
        return BuildResult(normalizedIntent, action, false, targetReason or "invalid_target", {
            stage = "resolve_target",
        })
    end

    if not TargetMatchesAppliesTo(normalizedIntent, action, resolvedTarget) then
        return BuildResult(normalizedIntent, action, false, "target_not_applicable", {
            stage = "applies_to",
        })
    end

    local payload = normalizedIntent.payload
    if type(action.normalizePayload) == "function" then
        local nextPayload, payloadReason = action.normalizePayload(normalizedIntent, resolvedTarget)
        if nextPayload == nil and payloadReason ~= nil then
            return BuildResult(normalizedIntent, action, false, payloadReason, {
                stage = "normalize_payload",
            })
        end
        payload = nextPayload
    end

    if addon.IsPlaneAllowed and not addon:IsPlaneAllowed(action.actionPlane, action.enabledWhenBypass) then
        return BuildResult(normalizedIntent, action, false, "plane_denied", {
            stage = "plane",
            runtimeMode = addon.GetChatRuntimeMode and addon:GetChatRuntimeMode() or nil,
        })
    end

    if type(action.requiredCapabilities) == "table" and addon.Can then
        for _, capability in ipairs(action.requiredCapabilities) do
            if type(capability) == "string" and capability ~= "" and not addon:Can(capability) then
                return BuildResult(normalizedIntent, action, false, "capability_denied", {
                    stage = "capability",
                    capability = capability,
                })
            end
        end
    end

    if opts.execute == false then
        return BuildResult(normalizedIntent, action, true, nil, {
            stage = "ready",
            payload = CloneTable(payload),
        })
    end

    if type(action.execute) ~= "function" then
        return BuildResult(normalizedIntent, action, false, "execution_failed", {
            stage = "execute",
            detail = "missing_execute",
        })
    end

    local ok, execOk, execReason = pcall(action.execute, normalizedIntent, resolvedTarget, payload)
    if not ok then
        return BuildResult(normalizedIntent, action, false, "execution_failed", {
            stage = "execute",
            error = tostring(execOk),
        })
    end
    if execOk == false then
        return BuildResult(normalizedIntent, action, false, execReason or "execution_failed", {
            stage = "execute",
            payload = CloneTable(payload),
        })
    end

    return BuildResult(normalizedIntent, action, true, nil, {
        stage = "executed",
        payload = CloneTable(payload),
    })
end

function Orchestrator:Preview(intent)
    return self:_Evaluate(intent, { execute = false })
end

function Orchestrator:Execute(intent)
    return self:_Evaluate(intent, { execute = true })
end
