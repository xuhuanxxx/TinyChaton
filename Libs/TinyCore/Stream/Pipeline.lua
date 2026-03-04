local addonName, addon = ...

addon.TinyCoreStreamPipeline = addon.TinyCoreStreamPipeline or {}
local Pipeline = addon.TinyCoreStreamPipeline
Pipeline.__index = Pipeline

local function NormalizeStage(stage)
    if addon.Utils and addon.Utils.EnsureString then
        return addon.Utils.EnsureString(stage, "")
    end
    return type(stage) == "string" and stage or ""
end

function Pipeline:New(stageNames)
    local middlewares = {}
    for _, stage in ipairs(stageNames or {}) do
        middlewares[stage] = {}
    end
    return setmetatable({
        middlewares = middlewares,
    }, self)
end

function Pipeline:HasStage(stage)
    local normalized = NormalizeStage(stage)
    return self.middlewares[normalized] ~= nil
end

function Pipeline:Register(stage, priority, name, fn)
    local normalized = NormalizeStage(stage)
    if not self:HasStage(normalized) then
        error("Invalid pipeline stage: " .. tostring(stage))
    end
    if type(fn) ~= "function" then
        error("Pipeline middleware must be a function")
    end

    local list = self.middlewares[normalized]
    list[#list + 1] = {
        name = name or "unnamed",
        priority = priority or 100,
        fn = fn,
    }

    table.sort(list, function(a, b)
        if a.priority ~= b.priority then
            return a.priority < b.priority
        end
        return tostring(a.name) < tostring(b.name)
    end)
end

function Pipeline:Unregister(stage, name)
    local normalized = NormalizeStage(stage)
    local list = self.middlewares[normalized]
    if type(list) ~= "table" then
        return false
    end

    for i, middleware in ipairs(list) do
        if middleware.name == name then
            table.remove(list, i)
            return true
        end
    end

    return false
end

function Pipeline:IsRegistered(stage, name)
    local normalized = NormalizeStage(stage)
    local list = self.middlewares[normalized]
    if type(list) ~= "table" then
        return false
    end

    for _, middleware in ipairs(list) do
        if middleware.name == name then
            return true
        end
    end
    return false
end

function Pipeline:Run(stage, context, hooks)
    local normalized = NormalizeStage(stage)
    local list = self.middlewares[normalized]
    if type(list) ~= "table" then
        return false
    end

    local callbackHooks = type(hooks) == "table" and hooks or {}
    local hasAnySuccess = false

    for _, middleware in ipairs(list) do
        local ok, result = pcall(middleware.fn, context)
        if not ok then
            if type(callbackHooks.onError) == "function" then
                callbackHooks.onError(middleware, result)
            end
        else
            hasAnySuccess = true
            if type(callbackHooks.onResult) == "function" then
                callbackHooks.onResult(middleware, result, context)
            end
        end
    end

    return hasAnySuccess
end
