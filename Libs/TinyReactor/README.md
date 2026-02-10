# TinyReactor

A lightweight, declarative UI framework designed specifically for World of Warcraft addons. Inspired by React, TinyReactor solves common WoW addon development challenges like memory leaks and complex state synchronization.

## Core Features

*   **Declarative UI**: Describe what your UI should look like, not how to modify it.
    *   *Goodbye `CreateFrame`, Hello `CreateElement`.*
*   **Zero Memory Leaks**: Built-in smart object pooling (`PoolManager`).
    *   The framework automatically manages `CreateFrame` and `CreateFramePool`, recycling frames when elements disappear.
*   **Virtual Node Diff (Reconciler)**:
    *   Lightweight diff algorithm updates only changed properties, minimizing CPU usage.
*   **Component-Based Architecture**:
    *   Define reusable UI components.
    *   Built-in layout components: `HStack`, `VStack` for automatic flow layouts.
*   **Lifecycle Hooks**: Support for `DidMount`, `DidUpdate`, `WillUnmount`.
*   **Error Boundaries**: Graceful degradation when components fail to render, preventing application crashes.

---

## Quick Start

### 1. Define a Component

Use `TR:Component` to define a component and implement the `:Render(props)` method.

```lua
local TR = _G.TinyReactor
local MyButton = TR:Component("MyButton")

function MyButton:Render(props)
    return TR:CreateElement("Button", {
        key = props.key,           -- Must provide a unique key
        size = {100, 30},
        text = props.label,
        onClick = function() print("Clicked:", props.label) end,
    })
end
```

### 2. Use Layout Components

#### HStack (Horizontal Layout)

```lua
local MyRow = TR:Component("MyRow")

function MyRow:Render(props)
    return TR:CreateElement(TR.HStack, {
        key = "row",
        gap = 5,
    }, {
        MyButton:Create({ key = "btn1", label = "A" }),
        MyButton:Create({ key = "btn2", label = "B" }),
        MyButton:Create({ key = "btn3", label = "C" }),
    })
end
```

#### VStack (Vertical Layout)

```lua
local MyColumn = TR:Component("MyColumn")

function MyColumn:Render(props)
    return TR:CreateElement(TR.VStack, {
        key = "column",
        gap = 10,
    }, {
        TR:CreateElement("FontString", { key = 1, text = "Header" }),
        TR:CreateElement("FontString", { key = 2, text = "Content" }),
        TR:CreateElement("FontString", { key = 3, text = "Footer" }),
    })
end
```

---

## Advanced Features

### Lifecycle Hooks

Components can define lifecycle hooks to respond to mount, update, and unmount events.

```lua
local MyComponent = TR:Component("MyComponent")

-- Called after component mounts
function MyComponent:DidMount(frame)
    print("Component mounted! Frame name:", frame:GetName())
    -- Initialize event listeners, timers here
end

-- Called after component updates
function MyComponent:DidUpdate(frame, prevProps)
    print("Component updated!")
    if prevProps.count ~= self.props.count then
        print("Count changed from", prevProps.count, "to", self.props.count)
    end
end

-- Called before component unmounts
function MyComponent:WillUnmount(frame)
    print("Component will unmount!")
    -- Clean up event listeners, timers here
end

function MyComponent:Render(props)
    self.props = props  -- Store props for DidUpdate comparison
    return TR:CreateElement("Frame", {
        key = props.key,
        size = {100, 100},
    })
end
```

### Error Boundaries

Use error boundaries to prevent entire application crashes when components fail to render.

```lua
-- Create error boundary wrapper
local SafeComponent = TR.Reconciler:CreateErrorBoundary(
    MyRiskyComponent,
    function(error, props)
        -- Return fallback UI
        return TR:CreateElement("Frame", {
            key = props.key,
            size = {100, 30},
            backdrop = { bgFile = "Interface\\Buttons\\WHITE8x8" },
            backdropColor = {1, 0, 0, 0.5},  -- Red background indicates error
        })
    end
)

-- Use wrapped component
local element = SafeComponent:Create({
    key = "safe",
    data = someData,
})
```

Or manually register error boundaries:

```lua
-- Register in component mount
function MyComponent:DidMount(frame)
    TR.Reconciler:RegisterErrorBoundary(frame:GetParent(), function(element, err)
        print("Error caught:", err)
        -- Return fallback UI or nil to re-throw
        return TR:CreateElement("Frame", {
            key = "error-fallback",
            size = {100, 100},
        })
    end)
end

-- Unregister in component unmount
function MyComponent:WillUnmount(frame)
    TR.Reconciler:UnregisterErrorBoundary(frame:GetParent())
end
```

### Debug Mode

TinyReactor includes a powerful debugging system for troubleshooting rendering issues.

```lua
-- Enable basic debugging
TR:SetDebug(true)

-- Enable verbose debugging
TR:SetDebug(true, "DEBUG")

-- Control logs by category
TR.Debug.categories.reconciler = true   -- Render flow
TR.Debug.categories.component = true    -- Component rendering
TR.Debug.categories.pool = true         -- Pool operations
TR.Debug.categories.props = false       -- Props application (verbose)
TR.Debug.categories.element = false     -- Element creation (verbose)
```

Sample debug output:
```
[00:00:00] [TinyReactor][INFO][reconciler] Render START: container=TinyChatonShelf, elements=1
[00:00:00] [TinyReactor][DEBUG][component] HStack:Render children=5 gap=2 key=MainStack
[00:00:00] [TinyReactor][INFO][reconciler]   Processing key='MainStack', existing=YES
[00:00:00] [TinyReactor][INFO][reconciler]     UPDATE key='MainStack' type='Frame'
[00:00:00] [TinyReactor][DEBUG][reconciler]     Recursively rendering 5 children into key='MainStack'
```

### Ref Callbacks

Each virtual node supports the `ref` property. It's a function called after the Reconciler completes physical updates, receiving the corresponding **real WoW Frame** as parameter.

> Note: Due to WoW API limitations, some properties (like dimensions) may require `C_Timer.After(0, ...)` to get accurate results. However, for most manual SetSize scenarios, `ref` returns the correct value immediately.

### Automated Object Pooling

You don't need to manually manage `Hide()` or physical destruction. When a `key` is no longer in your `Render` list, the corresponding Frame is automatically returned to `PoolManager`.

---

## API Reference

### `TR:CreateElement(type, props, [children])`

Creates a virtual node.
*   `type`: WoW Frame type (e.g., "Button", "Frame") or component class.
*   `props`: Property table. Supports all properties listed below.
*   `children`: (Optional) List of child nodes.

#### Supported Props

**Layout & Position:**
*   `key` (string|number): **Required.** Unique identifier for the element.
*   `size` (table|number): Dimensions `{width, height}` or single number for square.
*   `point` (table): Anchor point `{"POINT", parent, "RELATIVE_POINT", xOffset, yOffset}`. Use `"$parent"` as a magic string to reference the actual parent frame object (resolved at render time).

**Visual (Backdrop):**
*   `backdrop` (table): Backdrop definition (e.g., `{ bgFile = "...", edgeFile = "..." }`).
*   `backdropColor` (table): Background color `{r, g, b, a}`.
*   `backdropBorderColor` (table): Border color `{r, g, b, a}`.

**Button-Specific:**
*   `text` (string): Button label text.
*   `textColor` (table): Text color `{r, g, b, a}`.
*   `template` (string): Frame template (e.g., "UIPanelButtonTemplate", "BackdropTemplate").
*   `normalTexture` (string): Normal state texture path.
*   `highlightTexture` (string): Highlight state texture path.
*   `pushedTexture` (string): Pushed state texture path.

**Event Handlers:**
*   `onClick` (function): Click handler `function(button, mouseButton)`.
*   `onEnter` (function): Mouse enter handler `function(button)`.
*   `onLeave` (function): Mouse leave handler `function(button)`.
*   `onShow` (function): Show handler `function(frame)`.

**Refs:**
*   `ref` (function): Callback receiving the physical WoW Frame after creation/update.

### `TR:Component(name)`

Creates a component class.
*   `name`: Component name for debugging.
*   Returned class must implement `:Render(props)` method.
*   Optionally implement `:DidMount(frame)`, `:DidUpdate(frame, prevProps)`, `:WillUnmount(frame)`.

### `TR.HStack`

Horizontal layout component.
*   `gap`: Spacing between elements (pixels).
*   `children`: Array of child elements.
*   `point`: (Optional) Anchor definition.

### `TR.VStack`

Vertical layout component.
*   `gap`: Spacing between elements (pixels).
*   `children`: Array of child elements.
*   `point`: (Optional) Anchor definition.

### `TR.Reconciler:Render(container, elementList)`

Main render function.
*   `container`: WoW Frame container.
*   `elementList`: List of virtual elements.

### `TR.Reconciler:RegisterErrorBoundary(container, errorHandler)`

Manually registers an error boundary for a container (used internally by error boundary components).
*   `container`: The frame container to watch.
*   `errorHandler`: Function `function(element, error) -> fallbackElement|nil`.

### `TR.Reconciler:UnregisterErrorBoundary(container)`

Unregisters an error boundary.
*   `container`: The container to stop watching.

### `TR.Reconciler:CreateErrorBoundary(Component, fallbackRenderer)`

Creates an error boundary wrapper component (helper that uses Register/Unregister internally).
*   `Component`: Component class to wrap.
*   `fallbackRenderer`: Callback function `function(error, props) -> element` for render failures.

### `TR:SetDebug(enabled, level)`

Enable/disable debug mode.
*   `enabled`: boolean - Whether to enable
*   `level`: (Optional) "ERROR" | "WARN" | "INFO" | "DEBUG" - Log level

### `TR:Log(level, category, message, ...)`

Output debug logs.
*   `level`: Log level
*   `category`: Category name (reconciler/component/pool/props/element)
*   `message`: Format string
*   `...`: Format arguments

### `TR:DumpTable(tbl, name, maxDepth)`

Print table contents for debugging.
*   `tbl`: Table to print
*   `name`: (Optional) Table name
*   `maxDepth`: (Optional) Maximum recursion depth, default 2

### PoolManager API

TinyReactor uses an automated object pooling system to prevent memory leaks. You generally don't need to interact with these APIs directly, but they are available for advanced use cases.

#### `TR.PoolManager:Acquire(parentFrame, frameType, template)`

Acquires a frame from the pool.
*   `parentFrame`: Parent frame for the pool
*   `frameType`: Frame type ("Button", "Frame", etc.)
*   `template`: (Optional) Template name, defaults to `DEFAULT_TEMPLATE`
*   Returns: The acquired frame

#### `TR.PoolManager:Release(frame)`

Releases a frame back to its pool (auto-detected).
*   `frame`: The frame to release
*   Returns: boolean - Whether release was successful

#### `TR.PoolManager:IsTracked(frame)`

Checks if a frame is being tracked by the PoolManager.
*   `frame`: The frame to check
*   Returns: boolean

#### `TR.PoolManager:ReleaseAll(parentFrame)`

Releases all frames in all pools for a specific parent.
*   `parentFrame`: The parent frame whose pools should be cleared

#### `TR.PoolManager.DEFAULT_TEMPLATE`

Constant: "BackdropTemplate" - The default template used when none is specified.

### Shorthand Logging Methods

Convenience methods for quick logging:

*   `TR:DebugLog(category, message, ...)` - DEBUG level
*   `TR:Info(category, message, ...)` - INFO level
*   `TR:Warn(category, message, ...)` - WARN level
*   `TR:Error(category, message, ...)` - ERROR level

### Utility Functions

#### `TR.Assign(target, ...)`

Shallow copy utility (wrapper around WoW's `Mixin`). Copies properties from source tables into the target.
*   `target`: Destination table
*   `...`: Source tables to copy from
*   Returns: Modified target table

---

## Directory Structure

*   `Core.lua`: Framework entry and API definitions, includes debug system.
*   `Component.lua`: Component base class (reserved file).
*   `Reconciler.lua`: Core diff and rendering engine, includes lifecycle and error boundaries.
*   `PoolManager.lua`: Object pool management.
*   `Components/HStack.lua`: HStack horizontal layout component.
*   `Components/VStack.lua`: VStack vertical layout component.

---

## Best Practices

1.  **Key Stability**: `key` should be bound to data, not index. If your data position changes but `key` stays the same, the diff algorithm may incur unnecessary property overhead. Using array indices as keys is an anti-pattern.
2.  **Avoid Deep Nesting**: Keep UI trees flat and component functionality focused. Deep nesting makes debugging harder and can impact performance.
3.  **Embrace Stack**: Unless coordinates are completely fixed, prefer `HStack` or `VStack` for flow layouts. They handle positioning automatically and adapt to content changes.
4.  **Clean Up Resources**: Cancel event listeners, timers, and hooks in `WillUnmount` to prevent memory leaks. The framework handles frame pooling, but your custom resources need manual cleanup.
5.  **Add Error Boundaries**: Wrap risky components with error boundaries to prevent errors from affecting the entire UI. This is especially important for user-generated content or external data.
6.  **Size Propagation**: When using HStack/VStack, ensure child components have explicit `size` props. The layout system needs dimensions to calculate positions correctly.
7.  **Template Switching**: If you need to switch between different templates (e.g., "BackdropTemplate" to "UIPanelButtonTemplate"), the framework will automatically recreate the frame. This may reset some state.
8.  **Props Immutability**: Never mutate props directly. If you need to modify positioning or other properties in layout components, always clone the props first (HStack/VStack do this automatically).

---

## Quick Start Example

Here's a complete example demonstrating multiple TinyReactor features:

```lua
local TR = _G.TinyReactor

-- Define a reusable Button component
local Button = TR:Component("Button")
function Button:Render(props)
    return TR:CreateElement("Button", {
        key = props.key,
        size = props.size or {100, 30},
        text = props.text,
        template = "UIPanelButtonTemplate",
        onClick = props.onClick,
        onEnter = props.onEnter,
        onLeave = props.onLeave,
    })
end

-- Define a Card component with lifecycle
local Card = TR:Component("Card")
function Card:DidMount(frame)
    print("Card mounted with title:", self.props.title)
end

function Card:DidUpdate(frame, prevProps)
    if prevProps.title ~= self.props.title then
        print("Card title changed from", prevProps.title, "to", self.props.title)
    end
end

function Card:WillUnmount(frame)
    print("Card unmounting:", self.props.title)
end

function Card:Render(props)
    self.props = props
    return TR:CreateElement("Frame", {
        key = props.key,
        size = {200, 100},
        backdrop = {
            bgFile = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Buttons\\WHITE8x8",
            tile = false,
            tileSize = 0,
            edgeSize = 1,
            insets = { left = 0, right = 0, top = 0, bottom = 0 },
        },
        backdropColor = {0.1, 0.1, 0.1, 0.9},
        backdropBorderColor = {0.3, 0.3, 0.3, 1},
    }, {
        TR:CreateElement("FontString", {
            key = "title",
            point = {"TOP", "$parent", "TOP", 0, -10},
            text = props.title,
        })
    })
end

-- Main App component
local App = TR:Component("App")
function App:Render(props)
    return TR:CreateElement(TR.VStack, {
        key = "main",
        gap = 10,
    }, {
        Card:Create({ key = "card1", title = "Welcome" }),
        Card:Create({ key = "card2", title = "Settings" }),
        TR:CreateElement(TR.HStack, {
            key = "buttonRow",
            gap = 5,
        }, {
            Button:Create({ 
                key = "btn1", 
                text = "OK",
                onClick = function() print("OK clicked") end,
            }),
            Button:Create({ 
                key = "btn2", 
                text = "Cancel",
                onClick = function() print("Cancel clicked") end,
            }),
        })
    })
end

-- Usage in your addon
local container = CreateFrame("Frame", "MyApp", UIParent)
container:SetPoint("CENTER")
container:SetSize(300, 300)

-- Initial render
TR.Reconciler:Render(container, {
    App:Create({ key = "app" })
})

-- Later: update with new data
TR.Reconciler:Render(container, {
    App:Create({ key = "app", someData = newValue })
})
```

---

## License

MIT
