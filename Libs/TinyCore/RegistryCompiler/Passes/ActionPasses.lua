local addonName, addon = ...

addon.TinyCoreRegistryActionPasses = addon.TinyCoreRegistryActionPasses or {}
local Passes = addon.TinyCoreRegistryActionPasses

local function BuildStreamKeySet(streamKeys)
    if type(streamKeys) ~= "table" then
        return nil
    end
    local set = {}
    for _, key in ipairs(streamKeys) do
        if type(key) == "string" and key ~= "" then
            set[key] = true
        end
    end
    return set
end

local function StreamMatchesCapabilities(streamKey, requirement, getStreamCapabilities)
    if type(requirement) ~= "table" then
        return false
    end
    local caps = getStreamCapabilities(streamKey)
    if type(caps) ~= "table" then
        return false
    end
    for capKey, expected in pairs(requirement) do
        if caps[capKey] ~= expected then
            return false
        end
    end
    return true
end

local function StreamMatchesScope(stream, appliesTo)
    if type(stream) ~= "table" or type(appliesTo) ~= "table" then
        return false
    end

    if type(appliesTo.streamKind) == "string" and stream.kind ~= appliesTo.streamKind then
        return false
    end
    if type(appliesTo.streamGroup) == "string" and stream.group ~= appliesTo.streamGroup then
        return false
    end
    return true
end

function Passes.BuildRegistry(actionDefinitions, ctx)
    local context = type(ctx) == "table" and ctx or {}
    local iterateCompiledStreams = context.iterateCompiledStreams
    local getStreamCapabilities = context.getStreamCapabilities
    local actionPrefixSend = context.actionPrefixSend or ""
    local actionPrefixKit = context.actionPrefixKit or ""

    if type(iterateCompiledStreams) ~= "function" then
        error("ActionPasses requires iterateCompiledStreams()")
    end
    if type(getStreamCapabilities) ~= "function" then
        error("ActionPasses requires getStreamCapabilities(streamKey)")
    end

    local registry = {}
    local definitions = type(actionDefinitions) == "table" and actionDefinitions or {}

    local function RegisterActionForStream(actionDef, stream)
        local fullKey = actionDef.key .. "_" .. stream.key
        if registry[fullKey] then
            return
        end

        local label = actionDef.getLabel and actionDef.getLabel(stream.key) or actionDef.label
        if actionDef.category == "channel" and type(actionDef.key) == "string" and actionDef.key:match("send") then
            label = actionPrefixSend .. (label or "")
        end

        registry[fullKey] = {
            key = fullKey,
            label = label,
            tooltip = actionDef.getTooltip and actionDef.getTooltip(stream.key) or nil,
            streamKey = stream.key,
            category = actionDef.category,
            actionPlane = actionDef.actionPlane or "UI_ONLY",
            execute = function(...)
                actionDef.execute(stream.key, ...)
            end,
        }
    end

    for _, actionDef in ipairs(definitions) do
        if type(actionDef) == "table" and type(actionDef.key) == "string" and actionDef.key ~= "" then
            if actionDef.appliesTo and not actionDef.appliesTo.kits then
                local keySet = BuildStreamKeySet(actionDef.appliesTo.streamKeys)
                for _, stream in iterateCompiledStreams() do
                    if (not keySet or keySet[stream.key] == true)
                        and StreamMatchesScope(stream, actionDef.appliesTo)
                        and (not actionDef.appliesTo.streamCapabilities
                            or StreamMatchesCapabilities(stream.key, actionDef.appliesTo.streamCapabilities, getStreamCapabilities)) then
                        RegisterActionForStream(actionDef, stream)
                    end
                end
            end

            if actionDef.appliesTo and actionDef.appliesTo.kits then
                for _, kitKey in ipairs(actionDef.appliesTo.kits) do
                    local fullKey = "kit_" .. kitKey .. "_" .. actionDef.key
                    local label = actionDef.getLabel and actionDef.getLabel(kitKey) or actionDef.label
                    if actionDef.category == "kit" then
                        label = actionPrefixKit .. (label or "")
                    end

                    registry[fullKey] = {
                        key = fullKey,
                        label = label,
                        tooltip = actionDef.getTooltip and actionDef.getTooltip(kitKey) or nil,
                        kitKey = kitKey,
                        category = "kit",
                        actionPlane = actionDef.actionPlane or "UI_ONLY",
                        execute = actionDef.execute,
                    }
                end
            end
        end
    end

    return registry
end

function Passes.CreatePipeline()
    return {
        function(actionDefinitions, ctx)
            return Passes.BuildRegistry(actionDefinitions, ctx)
        end,
    }
end
