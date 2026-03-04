---
id: 0009
priority: P1
created: 2026-03-03
updated: 2026-03-05
relates: [#0008]
status: ACTIVE
---

# TinyChaton 架构优化方案

## 问题/目标

基于代码审查发现 3 个可优化点：性能瓶颈（Stream 查询 O(n)）、语义不清（中间件阶段命名）、职责过载（ShelfService 混杂多项职责）。

## 优化方案

### 1. Stream Registry 索引优化

**问题**：`GetStreamByKey()` 遍历 18 个 Stream，O(n) 查询。

**方案**：启动时构建索引，查询优化为 O(1)。

```lua
-- Bootstrap 阶段执行
addon.STREAM_INDEX = {}
for categoryKey, category in pairs(STREAM_REGISTRY) do
  for subKey, subCategory in pairs(category) do
    for _, stream in ipairs(subCategory) do
      addon.STREAM_INDEX[stream.key] = {
        stream = stream,
        path = categoryKey .. "." .. subKey,
        category = categoryKey,
        subtype = subKey
      }
    end
  end
end

-- 查询改为 O(1)
function addon:GetStreamByKey(key)
  local index = self.STREAM_INDEX[key]
  return index and index.stream or nil
end

function addon:GetStreamPath(key)
  local index = self.STREAM_INDEX[key]
  return index and index.path or nil
end

function addon:IsChannelStream(key)
  local index = self.STREAM_INDEX[key]
  return index and index.category == "CHANNEL" or false
end
```

**收益**：查询性能提升，Registry 定义保持不变。

---

### 2. 中间件阶段重命名

**问题**：当前命名语义模糊：`PRE_PROCESS`, `FILTER`, `ENRICH`, `LOG`。

**方案**：重命名为明确语义。

```lua
-- EventRouter.lua
Dispatcher.middlewares = {
  VALIDATE = {},   -- 原 PRE_PROCESS：数据验证
  BLOCK = {},      -- 原 FILTER：阻塞决策
  TRANSFORM = {},  -- 原 ENRICH：消息变换
  PERSIST = {},    -- 原 LOG：快照持久化
}

-- 保留别名兼容（1-2 版本后移除）
local STAGE_ALIASES = {
  PRE_PROCESS = "VALIDATE",
  FILTER = "BLOCK",
  ENRICH = "TRANSFORM",
  LOG = "PERSIST"
}

function Dispatcher:RegisterMiddleware(stage, priority, name, fn)
  local normalizedStage = STAGE_ALIASES[stage] or stage
  if STAGE_ALIASES[stage] then
    addon:Warn("Stage '%s' deprecated, use '%s'", stage, normalizedStage)
  end
  -- ... 继续
end
```

**收益**：阶段名称反映真实职责。

---

### 3. 拆分 ShelfService

**问题**：ShelfService 混杂 4 项职责（按钮生成、频道缓存、主题查询、动作执行），393 行代码。

**方案**：拆分为 3 个模块。

```lua
-- 保留：Domain/Shelf/ShelfService.lua (约 150 行)
ShelfService = {
  GetOrder = function() end,
  GetItemConfig = function(key) end,
  GetVisibleItems = function() end,
}

-- 新建：Domain/Shelf/DynamicChannelResolver.lua (约 30 行)
DynamicChannelResolver = {
  GetCachedChannelList = function() end,
  InvalidateCache = function() end,
  ResolveDynamicActiveName = function(stream) end,
}

-- 新建：Domain/Shelf/ThemeProvider.lua (约 90 行)
ThemeProvider = {
  GetThemeProperties = function(themeKey) end,
  GetProperty = function(prop) end,
  SetProperty = function(prop, val) end,
}
```

**收益**：单一职责，DynamicChannelResolver 可被其他模块复用。

---

### 4. 合并 Color/Theme Registry

**问题**：ColorRegistry 和 ThemeRegistry 职责重叠，主题通过 `colorSet` 引用颜色。

**方案**：颜色方案移入 ThemeRegistry。

```lua
-- ShelfThemeRegistry.lua
SHELF_THEMES = {
  Modern = {
    properties = {
      bgColor = {0.1, 0.1, 0.1, 0.6},
      buttonSize = 30,
      colorScheme = {  -- 内嵌颜色定义
        type = "rainbow",
        colors = {
          CHANNEL = { say = {1,1,1,1}, guild = {0.25,1,0.25,1}, ... },
          KIT = { ... }
        }
      }
    }
  }
}

-- 删除 ShelfColorRegistry.lua
```

**收益**：减少查询次数，语义统一。

---

### 5. StreamEventDispatcher 命名收口

**问题**：Dispatcher 暗示"分发"，实际是顺序执行 4 阶段的管道。

**方案**：重命名模块。

```lua
addon.StreamEventDispatcher:RegisterMiddleware("BLOCK", ...)
```

**收益**：名称反映职责。

---

### 6. Utils 辅助函数增强

**方案**：增加通用类型验证器（Utils.lua 已存在，增加函数）。

```lua
-- Infrastructure/Runtime/Utils.lua
function addon.Utils.EnsureType(value, expectedType, fallback)
  return type(value) == expectedType and value or fallback
end

function addon.Utils.EnsureTable(t)
  return type(t) == "table" and t or {}
end

function addon.Utils.EnsureString(s, fallback)
  return type(s) == "string" and s or (fallback or "")
end
```

**收益**：减少重复类型检查代码。

---

### 7. 性能预算配置

**方案**：集中定义性能预算，Profiler 自动检查。

```lua
-- Config.lua 或新建 Infrastructure/Runtime/PerformanceBudget.lua
addon.PERFORMANCE_BUDGET = {
  ["ChatGateway.Inbound.Allow"] = 0.1,
  ["ChatGateway.Display.Transform"] = 1.0,
  ["StreamEventDispatcher.Middleware.BLOCK"] = 0.5,
  ["StreamEventDispatcher.Middleware.PERSIST"] = 2.0,
  ["ShelfService.RefreshShelf"] = 10,
}

-- Profiler.lua 集成
function addon.Profiler:Stop(label)
  -- ... 原有计时逻辑
  local budget = addon.PERFORMANCE_BUDGET[label]
  if budget and elapsed > budget then
    addon:Warn("%s exceeded budget: %.2fms > %.2fms", label, elapsed, budget)
  end
end
```

**收益**：统一性能标准。

---

## 实施优先级

### P0（工作量 6-8 小时）
1. Stream Registry 索引优化
2. 中间件阶段重命名
3. Utils 辅助函数增强
4. 性能预算配置

### P1（工作量 17-24 小时）
1. 拆分 ShelfService
2. 合并 Color/Theme Registry
3. EventDispatcher → StreamEventDispatcher 重命名

---

## 结论/下一步

### 待执行
1. P0 优化（预计 6-8 小时）
2. P1 优化（预计 17-24 小时）

### 待验证
- [ ] Stream 索引构建性能（< 1ms）
- [ ] 中间件重命名兼容性测试
- [ ] ShelfService 拆分后集成测试
- [ ] Color/Theme 合并后颜色查询性能

### 文档规划
每个优化实施后新建 SPEC 文档：
- `0010-SPEC-stream-registry-index.md`
- `0011-SPEC-chat-pipeline.md`
- `0012-SPEC-dynamic-channel-resolver.md`
- `0013-SPEC-theme-provider.md`
- `0014-SPEC-performance-budget.md`
