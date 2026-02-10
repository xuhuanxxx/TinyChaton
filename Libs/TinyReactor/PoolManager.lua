local TR = _G.TinyReactor

-- =========================================================================
-- PoolManager: Wrapper around CreateFramePool
-- =========================================================================

local PoolManager = {}
TR.PoolManager = PoolManager

-- Default template constant (reduces hardcoding)
PoolManager.DEFAULT_TEMPLATE = "BackdropTemplate"

-- Frame-to-Pool mapping for automatic release
-- Key: frame, Value: { pool = pool, parent = parentFrame }
local frameToPoolMap = {}
setmetatable(frameToPoolMap, { __mode = "k" }) -- Weak keys to allow GC of frames

--- Gets or creates a FramePool for a specific type and template
--- @param parentFrame table The parent frame for the pool
--- @param frameType string "Button", "Frame", etc.
--- @param template string|nil Template name (e.g., "BackdropTemplate")
function PoolManager:GetPool(parentFrame, frameType, template)
    -- Pool key: type + template (Parent is usually constant for a renderer, but we handle it)
    -- For simplicity in this micro-framework, we assume one global pool set per parent is overkill?
    -- Actually, pools are usually attached to a parent or global.
    -- Let's attach pools to the parent frame to ensure correct parenting/layering.

    if not parentFrame.tinyReactorPools then
        parentFrame.tinyReactorPools = {}
    end

    local key = frameType .. "_" .. (template or "nil")
    if not parentFrame.tinyReactorPools[key] then
        TR:DebugLog("pool", "Creating new pool: %s for parent=%s", key, parentFrame.GetName and parentFrame:GetName() or "unnamed")
        parentFrame.tinyReactorPools[key] = CreateFramePool(frameType, parentFrame, template)
    end

    local pool = parentFrame.tinyReactorPools[key]
    -- WoW FramePool may not have GetNumActive/GetNumInactive methods
    local activeCount = pool.GetNumActive and pool:GetNumActive() or "?"
    local inactiveCount = pool.GetNumInactive and pool:GetNumInactive() or "?"
    TR:DebugLog("pool", "GetPool: %s (active=%s, inactive=%s)", key, activeCount, inactiveCount)
    return pool
end

--- Acquires a frame from pool and automatically tracks it for later release
--- @param parentFrame table The parent frame for the pool
--- @param frameType string "Button", "Frame", etc.
--- @param template string|nil Template name (defaults to DEFAULT_TEMPLATE)
--- @return table frame The acquired frame
function PoolManager:Acquire(parentFrame, frameType, template)
    template = template or self.DEFAULT_TEMPLATE
    local pool = self:GetPool(parentFrame, frameType, template)
    local frame = pool:Acquire()

    -- Auto-track: store in weak map for automatic release lookup
    frameToPoolMap[frame] = { pool = pool, parent = parentFrame }

    TR:DebugLog("pool", "Acquired frame from pool: %s_%s", frameType, template)
    return frame
end

--- Releases a frame back to its original pool (auto-detected)
--- @param frame table The frame to release
--- @return boolean success Whether the frame was successfully released
function PoolManager:Release(frame)
    local mapping = frameToPoolMap[frame]
    if mapping then
        mapping.pool:Release(frame)
        frameToPoolMap[frame] = nil
        TR:DebugLog("pool", "Released frame to pool (auto-detected)")
        return true
    end

    -- Fallback: frame not tracked (shouldn't happen with proper usage)
    TR:Warn("pool", "Attempted to release untracked frame: %s", tostring(frame))
    return false
end

--- Checks if a frame is tracked by the PoolManager
--- @param frame table The frame to check
--- @return boolean tracked Whether the frame is tracked
function PoolManager:IsTracked(frame)
    return frameToPoolMap[frame] ~= nil
end

--- Gets the pool info for a tracked frame
--- @param frame table The frame to look up
--- @return table|nil info { pool, parent } or nil if not tracked
function PoolManager:GetFramePoolInfo(frame)
    return frameToPoolMap[frame]
end

--- Releases all frames in a specific pool
function PoolManager:ReleaseAll(parentFrame)
    if parentFrame.tinyReactorPools then
        for _, pool in pairs(parentFrame.tinyReactorPools) do
            pool:ReleaseAll()
        end
        -- Clear tracking for this parent's frames
        for frame, mapping in pairs(frameToPoolMap) do
            if mapping.parent == parentFrame then
                frameToPoolMap[frame] = nil
            end
        end
    end
end
