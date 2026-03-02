---
id: 0001
priority: P0
created: 2026-03-02
updated: 2026-03-02
relates: []
status: ACTIVE
---

# 能力策略引擎规格

## 问题/目标

定义能力策略引擎（Capability Policy Engine）的行为边界与异常处理规则，确保功能启停决策的一致性。

## 功能规格

### 核心能力定义

系统定义 5 种核心能力：

```lua
READ_CHAT_EVENT      -- 读取聊天事件
PROCESS_CHAT_DATA    -- 处理聊天数据
PERSIST_CHAT_DATA    -- 持久化聊天数据
MUTATE_CHAT_DISPLAY  -- 变更聊天显示
EMIT_CHAT_ACTION     -- 发送聊天消息
```

### 运行时模式

系统支持 2 种运行时模式：

- **ACTIVE**：所有能力开启
- **BYPASS**：所有能力关闭

### 正常行为

#### 能力判定

```lua
addon:Can(capability) -> boolean
```

**输入**：
- `capability`: 能力标识符（字符串）或 `nil`

**输出**：
- `nil` 输入：返回 `true`（默认允许）
- 有效能力标识：根据当前模式返回能力矩阵结果
- 无效能力标识：返回 `false`

**状态变化**：
- 无副作用，纯查询

#### 模式切换

```lua
addon:SetChatRuntimeMode(mode, reason) -> boolean
```

**输入**：
- `mode`: `"ACTIVE"` 或 `"BYPASS"`
- `reason`: 切换原因（字符串，可选）

**输出**：
- 模式或原因变化：返回 `true`，触发 `CHAT_RUNTIME_MODE_CHANGED` 事件
- 无变化：返回 `false`

**状态变化**：
- 更新全局状态 `ChatRuntimeModeState.mode` 和 `.reason`
- 触发事件通知

### 边界条件

#### 空值处理

- `addon:Can(nil)` → `true`
- `addon:Can("")` → 查表返回 `nil` 或 `false`
- `addon:SetChatRuntimeMode(nil, reason)` → 强制回 `ACTIVE` 模式

#### 未初始化状态

- 首次调用 `GetChatRuntimeMode()` 前未初始化：返回 `"ACTIVE"`（默认模式）
- `ChatRuntimeModeState` 不存在：自动创建并初始化为 `ACTIVE`

#### 并发场景

- 模式切换非原子操作，但依赖单线程 Lua 执行
- 事件触发时，新模式已生效

### 异常处理

#### 无效能力查询

- 输入不在能力矩阵：返回 `false`（拒绝执行）
- 不抛出错误，静默降级

#### 无效模式设置

- 输入非 `ACTIVE`/`BYPASS`：强制转换为 `ACTIVE`
- 不抛出错误，静默修正

#### 事件系统缺失

- `addon.FireEvent` 不存在：跳过事件触发，不影响模式切换
- 不抛出错误，静默降级

### 依赖与约束

#### 依赖模块

- 无强依赖，可独立加载
- 可选依赖：`addon.FireEvent`（事件系统）

#### 策略层约束

- 所有功能模块必须通过 `addon:Can()` 查询能力，不得直接判断环境
- 能力矩阵由策略层维护，业务模块不得修改

#### 性能要求

- `addon:Can()` 调用频率极高（每条消息调用多次）
- 查表时间复杂度：O(1)
- 模式切换频率低（每分钟 < 10 次）

## 验证标准

### 基础能力查询

- [ ] `addon:Can(nil)` 返回 `true`
- [ ] `addon:Can("READ_CHAT_EVENT")` 在 `ACTIVE` 模式返回 `true`
- [ ] `addon:Can("READ_CHAT_EVENT")` 在 `BYPASS` 模式返回 `false`

### 模式切换

- [ ] 初始模式为 `ACTIVE`
- [ ] 切换到 `BYPASS` 后所有能力返回 `false`
- [ ] 重复设置相同模式返回 `false`（无变化）
- [ ] 模式切换触发 `CHAT_RUNTIME_MODE_CHANGED` 事件

### 边界处理

- [ ] 未初始化时查询模式返回 `ACTIVE`
- [ ] 查询不存在能力返回 `false`
- [ ] 设置无效模式强制转换为 `ACTIVE`

## 结论/下一步

本规格定义了能力策略引擎的完整行为边界。所有功能模块必须遵循此规格实现能力判定逻辑。

待验证事项：
- 事件触发时序与模式生效顺序的一致性
- 高频调用场景下的性能表现
