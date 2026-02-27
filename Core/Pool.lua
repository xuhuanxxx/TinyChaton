local addonName, addon = ...

addon.Pool = {}
local pools = {}

--- Create a new object pool
--- @param name string Unique name for the pool
--- @param factory function Function to create a new object when the pool is empty
--- @param reset function Function to reset an object before reuse (or after release)
function addon.Pool:Create(name, factory, reset)
    if pools[name] then return end
    pools[name] = {
        available = {},
        inUse = {}, -- Optional: Track in-use objects for debugging/leak detection
        totalCreated = 0,
        factory = factory,
        reset = reset
    }
end

--- Acquire an object from the pool
--- @param name string Name of the pool
--- @return any The acquired object
function addon.Pool:Acquire(name)
    local pool = pools[name]
    if not pool then return nil end

    local obj = table.remove(pool.available)
    if not obj then
        obj = pool.factory()
        pool.totalCreated = pool.totalCreated + 1
    end
    
    -- In a strict pool, we might track inUse, but for simplicity/perf we skip detailed tracking unless debugging
    -- pool.inUse[obj] = true 
    
    return obj
end

--- Release an object back to the pool
--- @param name string Name of the pool
--- @param obj any The object to release
function addon.Pool:Release(name, obj)
    local pool = pools[name]
    if not pool then return end

    if pool.reset then
        pool.reset(obj)
    end
    
    table.insert(pool.available, obj)
end

--- Get pool statistics
--- @param name string Name of the pool
--- @return number available, number total
function addon.Pool:GetStats(name)
    local pool = pools[name]
    if not pool then return 0, 0 end
    return #pool.available, pool.totalCreated
end
