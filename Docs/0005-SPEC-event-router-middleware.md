---
id: 0005
priority: P1
created: 2026-03-02
updated: 2026-03-02
relates: [#0001, #0004]
status: ACTIVE
---

# 事件路由与中间件规格

## 问题/目标

定义事件路由器（Event Router）与中间件管道的执行行为，确保消息处理的可扩展性与阶段隔离。

## 功能规格

### 架构原则

**中间件管道**：消息处理分为 4 个阶段，每阶段支持注册多个中间件：
1. **PRE_PROCESS**：预处理（不可阻塞）
2. **FILTER**：过滤/阻塞（可返回 `true` 阻塞消息）
3. **ENRICH**：增强处理（修改消息文本）
4. **LOG**：日志记录（不可阻塞）

### 中间件定义契约

```lua
{
  name = "string",        -- 唯一标识符
  priority = number,      -- 执行优先级（小值先执行）
  fn = function(chatData) -- 中间件函数
    -> boolean|nil        -- FILTER 阶段：true=阻塞，nil=放行
                          -- 其他阶段：返回值忽略
}
```

#### chatData 结构

```lua
{
  event = "string",           -- 事件名
  frame = table,              -- 聊天框架
  text = "string",            -- 消息文本
  author = "string",          -- 作者名
  metadata = {                -- 元数据
    chatType = "string",
    channelKey = "string",
    -- ... 其他字段
  }
}
```

### 正常行为

#### 注册中间件

```lua
Dispatcher:RegisterMiddleware(stage, priority, name, fn)
```

**输入**：
- `stage`: 阶段名（`"PRE_PROCESS"`, `"FILTER"`, `"ENRICH"`, `"LOG"`）
- `priority`: 优先级数字（建议 10, 20, 30...）
- `name`: 中间件名称（字符串）
- `fn`: 中间件函数

**行为**：
1. 验证 `stage` 是否有效，无效抛出错误
2. 验证 `fn` 是函数，否则抛出错误
3. 插入中间件到对应阶段数组
4. 按 `priority` 升序排序（相同优先级按 `name` 字母序）

**排序规则**：
- 优先级小的先执行（`priority=10` 先于 `priority=20`）
- 相同优先级按名称字母序

#### 注销中间件

```lua
Dispatcher:UnregisterMiddleware(stage, name) -> boolean
```

**输入**：
- `stage`: 阶段名
- `name`: 中间件名称

**输出**：
- `true`: 找到并删除
- `false`: 未找到

**行为**：
- 线性查找匹配 `name` 的中间件
- 找到后从数组删除，返回 `true`
- 未找到返回 `false`

#### 检查中间件是否注册

```lua
Dispatcher:IsMiddlewareRegistered(stage, name) -> boolean
```

**输入**：
- `stage`: 阶段名
- `name`: 中间件名称

**输出**：
- `true`: 已注册
- `false`: 未注册或阶段无效

#### 管道执行

**PRE_PROCESS 阶段**：
- 执行所有注册的中间件
- 忽略返回值
- 错误捕获：`pcall` 包裹，失败记录警告

**FILTER 阶段**：
- 按顺序执行中间件
- 任意中间件返回 `true`：立即停止，整体返回 `true`（阻塞消息）
- 所有中间件返回 `nil` 或 `false`：返回 `false`（放行消息）
- 错误捕获：`pcall` 包裹，失败视为 `false`（放行）

**ENRICH 阶段**：
- 执行所有注册的中间件
- 中间件可修改 `chatData` 字段（如 `text`, `metadata`）
- 忽略返回值
- 错误捕获：`pcall` 包裹，失败记录警告

**LOG 阶段**：
- 执行所有注册的中间件
- 忽略返回值
- 错误捕获：`pcall` 包裹，失败记录警告

### 边界条件

#### 空阶段

- 某阶段无注册中间件：跳过该阶段，不影响其他阶段

#### 优先级相同

- 多个中间件优先级相同：按 `name` 字母序执行
- 名称也相同：执行顺序未定义（应避免）

#### chatData 缺失字段

- 中间件访问不存在字段：Lua 返回 `nil`（不抛出错误）
- 中间件负责验证必需字段存在性

#### 中间件修改 chatData

- FILTER 阶段修改 `chatData`：修改生效，后续阶段可见
- 修改非法字段（如 `chatData = nil`）：下一个中间件接收非法值

### 异常处理

#### 注册时错误

- 无效 `stage`：抛出错误 `"Invalid middleware stage: ..."`
- `fn` 不是函数：抛出错误 `"Middleware function must be a function"`
- 错误向上传播，中断注册流程

#### 执行时错误

- 中间件函数抛出错误：`pcall` 捕获，记录警告，继续执行
- FILTER 阶段错误：视为返回 `false`（放行消息）
- 其他阶段错误：跳过该中间件，继续执行后续中间件

#### 排序异常

- `priority` 为 `nil`：使用默认值 `100`
- `priority` 不是数字：Lua 比较规则（可能导致排序异常）

### 依赖与约束

#### 依赖模块

- 可选：`addon.Debug` (日志系统)
- 可选：`addon.Warn` (警告系统)

#### 策略层约束

- 中间件注册必须在启动阶段完成，运行期不得注销核心中间件
- FILTER 阶段中间件不得执行耗时操作（目标 < 0.5ms）
- 中间件不得修改全局状态（除 `chatData` 外）

#### 性能要求

- 单阶段中间件数量：< 10 个
- 单中间件执行时间：
  - FILTER: < 0.5ms（高频）
  - ENRICH: < 1ms（高频）
  - PRE_PROCESS, LOG: < 2ms（可容忍）
- 完整管道执行时间：< 5ms（所有阶段总和）

### 典型中间件示例

#### Blacklist Filter (FILTER 阶段)

```lua
function(chatData)
  if IsBlacklisted(chatData.author) then
    return true  -- 阻塞消息
  end
  return false   -- 放行
end
```

#### Duplicate Filter (FILTER 阶段)

```lua
function(chatData)
  if IsDuplicate(chatData.text) then
    return true  -- 阻塞消息
  end
  return false   -- 放行
end
```

#### Snapshot Logger (LOG 阶段)

```lua
function(chatData)
  if ShouldSnapshot(chatData.metadata.channelKey) then
    SaveSnapshot(chatData)
  end
  -- 无返回值
end
```

## 验证标准

### 中间件注册

- [ ] 注册有效中间件成功
- [ ] 注册无效 `stage` 抛出错误
- [ ] 注册非函数 `fn` 抛出错误
- [ ] 多次注册相同 `name`（不同 `stage`）不冲突

### 执行顺序

- [ ] `priority=10` 先于 `priority=20` 执行
- [ ] 相同优先级按 `name` 字母序执行
- [ ] 注册顺序不影响执行顺序（完全由 `priority` 和 `name` 决定）

### FILTER 阶段

- [ ] 任意中间件返回 `true` 立即阻塞消息
- [ ] 所有中间件返回 `false/nil` 放行消息
- [ ] 中间件抛出错误视为放行

### ENRICH 阶段

- [ ] 中间件可修改 `chatData.text`
- [ ] 修改对后续中间件可见
- [ ] 中间件抛出错误不影响后续中间件

### 异常处理

- [ ] 中间件抛出错误被捕获，不影响其他中间件
- [ ] 错误记录到警告日志
- [ ] 管道执行继续，不中断

### 性能测试

- [ ] 100 次完整管道执行（每阶段 3 个中间件）< 500ms
- [ ] 单个 FILTER 中间件执行 1000 次 < 500ms

## 结论/下一步

本规格定义了事件路由器与中间件管道的完整执行契约。所有消息处理逻辑应通过中间件实现，不得绕过管道。

待验证事项：
- 中间件执行顺序在复杂优先级场景下的稳定性
- 运行期动态注册/注销中间件的安全性（当前不推荐）
- ENRICH 阶段中间件修改 `chatData` 的并发安全性（Lua 单线程，理论安全）
