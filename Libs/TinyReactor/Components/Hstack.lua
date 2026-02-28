local addonName, addon = ...
local TR = addon.TinyReactor
if not TR then
    error("TinyReactor not initialized")
end

-- =========================================================================
-- Standard Layout Components
-- =========================================================================

local HStack = TR:Component("HStack")
TR.HStack = HStack

-- Simple shallow clone helper because we shouldn't mutate original VNodes
local function shallowCopy(t)
    local copy = {}
    for k, v in pairs(t) do copy[k] = v end
    return copy
end

function HStack:Render(props)
    local gap = props.gap or 0
    local children = props.children or {}
    local processedChildren = {}

    TR:DebugLog("component", "HStack:Render children=%d gap=%d key=%s", #children, gap, props.key or "nil")

    local currentX = 0

    for i, child in ipairs(children) do
        -- We must CLONE the child node because we are injecting new props (point)
        -- mutating the original 'child' VNode (which might be cached or reused) is bad practice.
        local newChild = shallowCopy(child)
        newChild.props = shallowCopy(child.props)

        -- Default to some size if not set? No, consumer should set size.
        -- We just position them.
        local width = 0
        local sz = newChild.props.size
        if sz then
            if type(sz) == "table" then
                width = sz[1] or 0
            elseif type(sz) == "number" then
                width = sz
            end
        end

        -- Inject Point relative to Parent Container
        -- Anchor: LEFT -> LEFT
        newChild.props.point = {"LEFT", "$parent", "LEFT", currentX, 0}

        table.insert(processedChildren, newChild)

        currentX = currentX + width + gap
    end

    -- The HStack itself is a Frame that holds these children
    local w = math.max(1, currentX - gap)
    local h = 30
    if props.size and type(props.size) == "table" then
        h = props.size[2] or 30
    end

    TR:DebugLog("component", "HStack: created layout size=%dx%d children=%d", w, h, #processedChildren)

    return TR:CreateElement("Frame", {
        key = props.key,
        size = props.size or {w, h},
        point = props.point,
    }, processedChildren)
end
