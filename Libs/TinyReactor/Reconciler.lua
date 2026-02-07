local TR = _G.TinyReactor

-- =========================================================================
-- Reconciler: The core Diff Engine
-- =========================================================================

local Reconciler = {}
TR.Reconciler = Reconciler

-- Error Boundary State
local errorBoundaries = {}
local renderErrors = {}

-- =========================================================================
-- Error Boundary Functions
-- =========================================================================

--- Register an error boundary for a container
function Reconciler:RegisterErrorBoundary(container, errorHandler)
    errorBoundaries[container] = errorHandler
end

--- Unregister an error boundary
function Reconciler:UnregisterErrorBoundary(container)
    errorBoundaries[container] = nil
end

--- Handle render error with optional error boundary
local function HandleRenderError(container, element, err)
    local boundary = errorBoundaries[container]
    if boundary then
        TR:Error("reconciler", "Render error caught by boundary: %s", tostring(err))
        local ok, fallbackElement = pcall(boundary, element, err)
        if ok and fallbackElement then
            return fallbackElement
        end
        TR:Error("reconciler", "Error boundary failed: %s", tostring(fallbackElement))
    end
    -- Re-throw if no boundary or boundary failed
    error(err)
end

-- =========================================================================
-- Lifecycle Functions
-- =========================================================================

--- Call lifecycle hook on component if it exists
local function CallLifecycle(element, hookName, frame, ...)
    if not element or not element.type then return end
    local component = element.type
    if type(component) == "table" and component[hookName] then
        local ok, err = pcall(component[hookName], component, frame, ...)
        if not ok then
            TR:Error("reconciler", "Lifecycle hook %s failed for %s: %s", 
                hookName, component.displayName or "Unknown", tostring(err))
        end
    end
end

--- Call componentDidMount
local function ComponentDidMount(element, frame)
    CallLifecycle(element, "DidMount", frame)
end

--- Call componentDidUpdate
local function ComponentDidUpdate(element, frame, prevProps)
    CallLifecycle(element, "DidUpdate", frame, prevProps)
end

--- Call componentWillUnmount
local function ComponentWillUnmount(element, frame)
    CallLifecycle(element, "WillUnmount", frame)
end

-- =========================================================================
-- Props Application
-- =========================================================================

-- Private helper to apply props
local function ApplyProps(frame, oldProps, newProps)
    if oldProps == newProps then return end
    oldProps = oldProps or {}
    -- Always ensure newProps is a table (could be nil if component returns element with no props, though unlikely in this framework)
    newProps = newProps or {}
    
    TR:DebugLog("props", "ApplyProps: %s (frame: %s)", frame.TR_LeafElement and frame.TR_LeafElement.key or "?", frame:GetName() or "unnamed")

    -- Styles & Layout
    if newProps.size then
        if type(newProps.size) ~= "table" then
            -- Auto-correct or Error?
            -- To prevent crash, let's error with context
            error("TinyReactor: 'size' prop must be a table {width, height}. Got: " .. tostring(newProps.size))
        end
        frame:SetSize(unpack(newProps.size))
    end
    
    if newProps.point then
         frame:ClearAllPoints()
         -- V1.1: Magic $parent ID resolution
         -- If we provide a table like {"LEFT", "$parent", "LEFT", 10, 0}
         local pt = {unpack(newProps.point)}
         if pt[2] == "$parent" then
             pt[2] = frame:GetParent()
         end
         frame:SetPoint(unpack(pt))
    end
    
    -- Visuals (Backdrop & Textures)
    if newProps.backdrop then
        -- Only apply if changed
        if not oldProps or newProps.backdrop ~= oldProps.backdrop then
            -- Safety guard for SetBackdrop (requires BackdropTemplate on Retail)
            if not frame.SetBackdrop and _G.BackdropTemplateMixin then
                _G.Mixin(frame, _G.BackdropTemplateMixin)
                if frame.OnBackdropLoaded then frame:OnBackdropLoaded() end
            end
            
            if frame.SetBackdrop then
                frame:SetBackdrop(newProps.backdrop)
            end
        end
    end

    if newProps.backdropColor then
        if not oldProps or newProps.backdropColor ~= oldProps.backdropColor then
            if not frame.SetBackdropColor and _G.BackdropTemplateMixin then
                 _G.Mixin(frame, _G.BackdropTemplateMixin)
            end
            if frame.SetBackdropColor then
                frame:SetBackdropColor(unpack(newProps.backdropColor))
            end
        end
    end
    
    if newProps.backdropBorderColor then
        if not oldProps or newProps.backdropBorderColor ~= oldProps.backdropBorderColor then
            if not frame.SetBackdropBorderColor and _G.BackdropTemplateMixin then
                 _G.Mixin(frame, _G.BackdropTemplateMixin)
            end
            if frame.SetBackdropBorderColor then
                frame:SetBackdropBorderColor(unpack(newProps.backdropBorderColor))
            end
        end
    end
    
    if frame:GetObjectType() == "Button" then
        if newProps.normalTexture ~= oldProps.normalTexture then
            frame:SetNormalTexture(newProps.normalTexture or "")
        end
        if newProps.highlightTexture ~= oldProps.highlightTexture then
            frame:SetHighlightTexture(newProps.highlightTexture or "")
        end
        if newProps.pushedTexture ~= oldProps.pushedTexture then
            frame:SetPushedTexture(newProps.pushedTexture or "")
        end
    end

    -- Button Specific (Text & Scripts)
    if frame:GetObjectType() == "Button" then
        local fs = frame:GetFontString()

        if not fs or not fs.SetText then
            fs = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            fs:SetPoint("CENTER")
            frame:SetFontString(fs)
        end

        if not oldProps or newProps.text ~= oldProps.text then
            frame:SetText(newProps.text or "")
        end

        if newProps.textColor and fs then
             if not oldProps or newProps.textColor ~= oldProps.textColor then
                 fs:SetTextColor(unpack(newProps.textColor))
             end
        end
        
        -- Events / Scripts
        if newProps.onClick ~= oldProps.onClick then
            frame:SetScript("OnClick", newProps.onClick)
        end
        
        if newProps.onEnter ~= oldProps.onEnter then
            frame:SetScript("OnEnter", newProps.onEnter)
        end
        
        if newProps.onLeave ~= oldProps.onLeave then
            frame:SetScript("OnLeave", newProps.onLeave)
        end
    end
    
    -- Custom Refs
    if newProps.ref and type(newProps.ref) == "function" then
        newProps.ref(frame)
    end
end

-- =========================================================================
-- Component Rendering with Error Handling
-- =========================================================================

--- Render a component with error boundary support
local function RenderComponent(component, props, container)
    local ok, result = pcall(component.Render, component, props)
    if not ok then
        TR:Error("reconciler", "Component '%s' render failed: %s", 
            component.displayName or "Unknown", tostring(result))
        return nil, result
    end
    return result, nil
end

-- =========================================================================
-- Main Render Function
-- =========================================================================

--- The main render function
--- @param container table The WoW Frame to host children
--- @param elementList table List of Virtual Elements
function Reconciler:Render(container, elementList)
    local containerName = container.GetName and container:GetName() or tostring(container)
    TR:DebugLog("reconciler", "Render START: container=%s, elements=%d", containerName, #elementList)
    
    if not container.TR_Children then container.TR_Children = {} end
    
    local oldChildrenMap = container.TR_Children
    local newChildrenMap = {}
    
    -- Pool management
    local poolManager = TR.PoolManager
    
    -- Diff & Mount
    for _, element in ipairs(elementList) do
        local key = element.key or error("TinyReactor: All items must have a unique 'key' prop.")
        local existingFrame = oldChildrenMap[key]
        local isUpdate = existingFrame ~= nil
        
        TR:DebugLog("reconciler", "  Processing key='%s', existing=%s", key, isUpdate and "YES" or "NO")
        
        -- Store original element for lifecycle
        local originalElement = element
        
        -- Resolve Leaf Element (Unwrap Components)
        local leafElement = element
        local componentDepth = 0
        local componentStack = {} -- Track component hierarchy for error recovery
        
        while type(leafElement.type) == "table" and leafElement.type._isComponent do
            componentDepth = componentDepth + 1
            local component = leafElement.type
            table.insert(componentStack, component)
            
            TR:DebugLog("component", "    Rendering component '%s' (depth=%d)", component.displayName, componentDepth)
            
            -- V1.1: Inject 'children' into props so components can access them
            if element.children and #element.children > 0 then
                leafElement.props.children = element.children
            end
            
            -- Render component with error handling
            local renderResult, renderErr = RenderComponent(component, leafElement.props, container)
            
            if not renderResult then
                -- Component render failed - try to use error boundary
                local fallbackElement = HandleRenderError(container, element, renderErr)
                if fallbackElement then
                    leafElement = fallbackElement
                    break
                end
            end
            
            leafElement = renderResult
            
            if not leafElement then
                 error("Component " .. (component.displayName or "Unknown") .. " returned nil from :Render()")
            end
            -- Inherit key if missing in leaf
            if not leafElement.key then leafElement.key = element.key end
        end
        
        local renderType = leafElement.type
        if type(renderType) ~= "string" then
             error("TinyReactor: Page eventually rendered into " .. type(renderType) .. ", expected string (FrameType).")
        end
        
        local frame
        local prevProps = nil
        -- Support custom template from props (e.g., "UIPanelButtonTemplate" for Retro theme)
        local template = leafElement.props and leafElement.props.template or poolManager.DEFAULT_TEMPLATE
        
        if isUpdate then
            -- UPDATE
            frame = existingFrame
            TR:DebugLog("reconciler", "    UPDATE key='%s' type='%s'", key, renderType)
            
            -- Get previous props for DidUpdate
            local oldLeaf = frame.TR_LeafElement
            if oldLeaf then
                prevProps = oldLeaf.props
            end
            
            -- Template Mismatch Check
            -- UIPanelButtonTemplate has built-in FontString, needs recreation when switching
            local oldTemplate = prevProps and prevProps.template or poolManager.DEFAULT_TEMPLATE
            local needsRecreate = oldTemplate ~= template

            -- Also recreate if object type changed (edge case)
            if frame:GetObjectType() ~= renderType then
                needsRecreate = true
            end

            if needsRecreate then
                if frame:GetObjectType() ~= renderType then
                    TR:Warn("reconciler", "    Type mismatch! Expected '%s', got '%s'. Recreating...", renderType, frame:GetObjectType())
                else
                    TR:Warn("reconciler", "    Template mismatch! Expected '%s', got '%s'. Recreating...", template, oldTemplate)
                end
                
                -- Call WillUnmount before releasing
                if frame.TR_Element then
                    ComponentWillUnmount(frame.TR_Element, frame)
                end
                
                -- Release to correct pool (auto-tracked by PoolManager)
                poolManager:Release(frame)
                
                -- Acquire from new pool
                frame = poolManager:Acquire(container, renderType, template)
                frame:Show()
                
                -- Reset state to ensure ApplyProps works correctly
                prevProps = nil
            else
                frame:Show()
            end
            
            ApplyProps(frame, prevProps, leafElement.props)
            
            -- Remove from old map so we know it's re-used
            oldChildrenMap[key] = nil
        else
            -- CREATE (MOUNT)
            TR:Info("reconciler", "    CREATE key='%s' type='%s' template='%s'", key, renderType, template)
            frame = poolManager:Acquire(container, renderType, template)
            frame:Show()
            ApplyProps(frame, nil, leafElement.props)
        end
        
        -- Link Virtual Element to Native Frame
        frame.TR_Element = originalElement
        frame.TR_LeafElement = leafElement
        frame.TR_ComponentStack = componentStack
        -- Note: Template tracking is now handled automatically by PoolManager
        
        -- Add to new map
        newChildrenMap[key] = frame
        
        -- V1.1: Recursively Render Children
        -- If leafElement has children, renders them into 'frame'
        if leafElement.children and #leafElement.children > 0 then
            TR:DebugLog("reconciler", "    Recursively rendering %d children into key='%s'", #leafElement.children, key)
            Reconciler:Render(frame, leafElement.children)
        elseif frame.TR_Children then
            -- If no children in new VDOM, but frame has old children, we must unmount them!
            -- Reconciler:Render(frame, {}) does exactly that (diffs against empty list)
            TR:DebugLog("reconciler", "    Unmounting old children from key='%s'", key)
            Reconciler:Render(frame, {})
        end
        
        -- Call lifecycle hooks AFTER children are rendered
        if isUpdate then
            -- Component was updated
            if originalElement and originalElement.type and type(originalElement.type) == "table" then
                ComponentDidUpdate(originalElement, frame, prevProps)
            end
        else
            -- Component was just created
            if originalElement and originalElement.type and type(originalElement.type) == "table" then
                ComponentDidMount(originalElement, frame)
            end
        end
    end
    
    -- Unmount remaining children
    local unmountCount = 0
    for key, frame in pairs(oldChildrenMap) do
        unmountCount = unmountCount + 1
        TR:Info("reconciler", "  UNMOUNT key='%s' type='%s'", key, frame:GetObjectType())
        
        -- Call WillUnmount before any cleanup
        if frame.TR_Element then
            ComponentWillUnmount(frame.TR_Element, frame)
        end
        
        -- Recursively unmount children of this frame first?
        -- If we just Release(frame), its children (WoW Frames) are hidden/re-parented?
        -- WoW FramePool:Release(frame) hides the frame.
        -- Its children are NOT automatically released if they are pooled frames!
        -- We must recursively unmount the TinyReactor tree attached to this frame.
        if frame.TR_Children then
            Reconciler:Render(frame, {}) -- Unmount all TR children
        end
        
        frame.TR_Element = nil
        frame.TR_LeafElement = nil
        frame.TR_ComponentStack = nil
        frame:Hide()
        frame:ClearAllPoints()
        
        -- Release to correct pool (auto-tracked by PoolManager)
        poolManager:Release(frame)
    end
    
    -- Update Container State
    container.TR_Children = newChildrenMap
    
    TR:DebugLog("reconciler", "Render END: container=%s, created=%d, unmounted=%d", 
        containerName, 
        #elementList - unmountCount, 
        unmountCount)
end

-- =========================================================================
-- ErrorBoundary Component Helper
-- =========================================================================

--- Create an error boundary wrapper for a component
function Reconciler:CreateErrorBoundary(Component, fallbackRenderer)
    local Boundary = TR:Component(Component.displayName .. "ErrorBoundary")
    
    Boundary.WrappedComponent = Component
    Boundary.hasError = false
    Boundary.error = nil
    
    function Boundary:Render(props)
        if self.hasError then
            return fallbackRenderer(self.error, props)
        end
        return Component:Create(props)
    end
    
    function Boundary:DidMount(frame)
        -- Register error boundary for this container
        Reconciler:RegisterErrorBoundary(frame:GetParent(), function(element, err)
            self.hasError = true
            self.error = err
            return fallbackRenderer(err, element.props)
        end)
    end
    
    function Boundary:WillUnmount(frame)
        Reconciler:UnregisterErrorBoundary(frame:GetParent())
    end
    
    return Boundary
end
