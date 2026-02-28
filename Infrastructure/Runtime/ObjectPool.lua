local addonName, addon = ...

addon.Pool = {}
local pools = {}

local function IsFrameObject(obj)
    return type(obj) == "table" and type(obj.GetObjectType) == "function"
end

function addon.Pool:Create(name, factory, reset)
    if pools[name] then return end
    pools[name] = {
        available = {},
        inUse = {},
        totalCreated = 0,
        factory = factory,
        reset = reset,
    }
end

function addon.Pool:Acquire(name)
    local pool = pools[name]
    if not pool then return nil end

    local obj = table.remove(pool.available)
    if not obj then
        obj = pool.factory()
        pool.totalCreated = pool.totalCreated + 1
    end

    if IsFrameObject(obj) and addon.Warn then
        addon:Warn("addon.Pool '%s' is for Lua objects only; use TinyReactor.PoolManager for frames", tostring(name))
    end

    return obj
end

function addon.Pool:Release(name, obj)
    local pool = pools[name]
    if not pool then return end

    if IsFrameObject(obj) and addon.Warn then
        addon:Warn("addon.Pool '%s' release received a frame object; this pool is for Lua objects only", tostring(name))
    end

    if pool.reset then
        pool.reset(obj)
    end

    table.insert(pool.available, obj)
end

function addon.Pool:GetStats(name)
    local pool = pools[name]
    if not pool then return 0, 0 end
    return #pool.available, pool.totalCreated
end
