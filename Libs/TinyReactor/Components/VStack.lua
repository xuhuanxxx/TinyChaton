local TR = _G.TinyReactor

-- =========================================================================
-- VStack: Vertical Layout Component
-- =========================================================================

local VStack = TR:Component("VStack")
TR.VStack = VStack

-- Simple shallow clone helper because we shouldn't mutate original VNodes
local function shallowCopy(t)
    local copy = {}
    for k, v in pairs(t) do copy[k] = v end
    return copy
end

function VStack:Render(props)
    local gap = props.gap or 0
    local children = props.children or {}
    local processedChildren = {}

    TR:DebugLog("component", "VStack:Render children=%d gap=%d key=%s", #children, gap, props.key or "nil")

    local currentY = 0
    local maxWidth = 0

    for i, child in ipairs(children) do
        -- We must CLONE the child node because we are injecting new props (point)
        -- mutating the original 'child' VNode (which might be cached or reused) is bad practice.
        local newChild = shallowCopy(child)
        newChild.props = shallowCopy(child.props)

        -- Get height for positioning
        local height = 0
        local sz = newChild.props.size
        if sz then
            if type(sz) == "table" then
                height = sz[2] or 0
                maxWidth = math.max(maxWidth, sz[1] or 0)
            elseif type(sz) == "number" then
                height = sz
                maxWidth = math.max(maxWidth, sz)
            end
        end

        -- Get width if specified
        local width = 0
        if sz then
            if type(sz) == "table" then
                width = sz[1] or 0
            elseif type(sz) == "number" then
                width = sz
            end
            maxWidth = math.max(maxWidth, width)
        end

        -- Inject Point relative to Parent Container
        -- Anchor: TOP -> TOP (negative Y goes downward in WoW)
        newChild.props.point = {"TOP", "$parent", "TOP", 0, -currentY}

        table.insert(processedChildren, newChild)

        currentY = currentY + height + gap
    end

    -- The VStack itself is a Frame that holds these children
    local h = math.max(1, currentY - gap)
    local w = maxWidth
    if props.size and type(props.size) == "table" then
        w = props.size[1] or maxWidth
        if maxWidth == 0 then
            w = props.size[1] or 100  -- Default width if no children have size
        end
    elseif maxWidth == 0 then
        w = 100  -- Default width
    end

    TR:DebugLog("component", "VStack: created layout size=%dx%d children=%d", w, h, #processedChildren)

    return TR:CreateElement("Frame", {
        key = props.key,
        size = props.size or {w, h},
        point = props.point,
    }, processedChildren)
end
