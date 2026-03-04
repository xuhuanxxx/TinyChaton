---
id: 0004
priority: P0
created: 2026-03-02
updated: 2026-03-05
relates: [#0001]
status: ACTIVE
---

# 聊天网关规格

## 问题/目标

定义聊天网关（Chat Gateway）的三个关键入口点的行为边界与防御策略，确保聊天数据流的收口与一致性。

## 功能规格

### 架构原则

**入口收口**：所有聊天数据必须经过三个网关之一，不允许旁路：
- **Inbound**：入站消息（从 WoW 事件进入）
- **Display**：显示变换（消息渲染前处理）
- **Outbound**：出站消息（发送到 WoW）

### Inbound Gateway

#### 接口定义

```lua
Gateway.Inbound:Allow(event, frame, ...) -> boolean
```

**功能**：判定是否允许处理入站聊天事件。

**输入**：
- `event`: 聊天事件名（字符串）
- `frame`: 聊天框架对象
- `...`: 事件参数（可变参数）

**输出**：
- `true`: 允许处理
- `false`: 拒绝处理（跳过所有后续逻辑）

**判定逻辑**：
1. 检查 `addon.db.enabled` 是否为 `true`
2. 检查 `addon:Can(READ_CHAT_EVENT)` 是否返回 `true`
3. 所有条件满足返回 `true`，否则返回 `false`

#### 正常行为

- 插件启用且能力允许：返回 `true`
- 插件禁用：返回 `false`
- BYPASS 模式：返回 `false`

#### 边界条件

- `addon.db` 不存在：返回 `false`
- `addon.Can` 不存在：跳过能力检查，仅检查 `enabled`
- `event` 为 `nil`：不影响判定（不验证参数）

#### 异常处理

- 所有判定错误静默降级为 `false`
- 不抛出错误，不写日志

### Display Gateway

#### 接口定义

```lua
Gateway.Display:Transform(frame, msg, r, g, b, extraArgs) 
  -> (msg, r, g, b, extraArgs)
```

**功能**：执行消息显示变换链（Transformer Pipeline）。

**输入**：
- `frame`: 聊天框架对象
- `msg`: 原始消息文本（字符串）
- `r, g, b`: RGB 颜色值（数字 0-1）
- `extraArgs`: 扩展参数表（表或 nil）

**输出**：
- 变换后的 `(msg, r, g, b, extraArgs)`
- 如果能力不允许或输入无效，返回原始输入

#### 变换链执行

**顺序**：按 `addon.TRANSFORMER_ORDER` 数组顺序执行

**单步变换**：
```lua
nextMsg, nextR, nextG, nextB, nextExtra = 
  transformer(frame, currentMsg, currentR, currentG, currentB, currentExtra)
```

**类型验证**：
- `nextMsg` 不是字符串：保留 `currentMsg`
- `nextR/G/B` 不是数字：保留当前颜色
- `nextExtra` 不是表：保留 `currentExtra`，记录警告

**错误处理**：
- 变换器抛出错误：`pcall` 捕获，记录警告，跳过该变换器
- 继续执行后续变换器

#### 正常行为

- 能力允许且输入有效：执行完整变换链
- 能力不允许：返回原始输入
- `msg` 不是字符串：返回原始输入（防御性处理）

#### 边界条件

- `extraArgs` 为 `nil`：转换为空表 `{}`
- `TRANSFORMER_ORDER` 为空：返回原始输入
- `chatFrameTransformers` 不存在：跳过所有变换

#### 异常处理

- 变换器返回 `nil`：保留当前值
- 变换器返回无效类型：保留当前值，记录警告
- 变换器抛出错误：捕获错误，记录警告，继续执行

#### 性能约束

- 变换链执行频率：极高（每条消息显示前调用）
- 目标延迟：< 1ms（用户感知阈值）
- 变换器数量限制：< 10 个

### Outbound Gateway

#### 接口定义

```lua
Gateway.Outbound:SendChat(text, chatType, language, target) -> boolean
```

**功能**：发送聊天消息到 WoW。

**输入**：
- `text`: 消息文本（字符串）
- `chatType`: 频道类型（字符串，如 `"SAY"`, `"GUILD"`）
- `language`: 语言 ID（数字，可选）
- `target`: 目标玩家名（字符串，可选）

**输出**：
- `true`: 发送成功
- `false`: 发送失败（能力不允许或输入无效）

#### 正常行为

- 能力允许且输入有效：调用 `SendChatMessage()` 并返回 `true`
- 能力不允许：返回 `false`，不调用 WoW API
- 输入无效：返回 `false`，不调用 WoW API

#### 边界条件

- `text` 为 `nil` 或空字符串：返回 `false`
- `text` 不是字符串：返回 `false`
- `chatType` 无效：WoW API 处理错误（不在网关捕获）

#### 异常处理

- `SendChatMessage()` 抛出错误：向上传播（不捕获）
- 能力检查失败：静默返回 `false`

### 依赖与约束

#### 依赖模块

- 必需：`addon:Can()` (Capability Policy Engine)
- 必需：`addon.db` (Database)
- 可选：`addon.TRANSFORMER_ORDER`, `addon.chatFrameTransformers`

#### 策略层约束

- 所有入站消息必须先通过 `Inbound:Allow()` 判定
- 所有显示变换必须注册到 `chatFrameTransformers` 并加入 `TRANSFORMER_ORDER`
- 所有出站消息必须通过 `Outbound:SendChat()` 发送，不得直接调用 `SendChatMessage()`

#### 性能要求

- `Inbound:Allow()`: < 0.1ms（高频调用）
- `Display:Transform()`: < 1ms（高频调用，包含所有变换器）
- `Outbound:SendChat()`: < 5ms（低频调用）

### 数据完整性

#### 防御性处理

**Inbound**：
- 不验证事件参数类型（由调用方保证）
- 只验证能力与启用状态

**Display**：
- 验证 `msg` 是字符串（核心数据）
- 验证变换器返回值类型（防止后续错误）
- 保证返回值类型一致性

**Outbound**：
- 验证 `text` 非空且为字符串（核心数据）
- 不验证 `chatType` 合法性（交给 WoW API）

## 验证标准

### Inbound Gateway

- [ ] 插件启用且 ACTIVE 模式：`Allow()` 返回 `true`
- [ ] 插件禁用：`Allow()` 返回 `false`
- [ ] BYPASS 模式：`Allow()` 返回 `false`
- [ ] `addon.db` 不存在：`Allow()` 返回 `false`

### Display Gateway

- [ ] 空变换器列表：返回原始输入
- [ ] 单个变换器修改 `msg`：返回修改后文本
- [ ] 变换器返回无效类型：保留当前值
- [ ] 变换器抛出错误：捕获并继续执行后续变换器
- [ ] 能力不允许：返回原始输入

## 边界补充（2026-03-05）

- `stream` 为总域（`channel + notice`），但 `chat` 语义仅等价 `channel` 交互。
- 网关层保持中性，不按命名限制 notice；具体行为由上层策略决定。
- `MessageFormatter` 保持中性命名，允许后续增加 notice 专属格式化策略。

### Outbound Gateway

- [ ] 能力允许且输入有效：`SendChat()` 返回 `true`
- [ ] 能力不允许：`SendChat()` 返回 `false`
- [ ] `text` 为空字符串：`SendChat()` 返回 `false`
- [ ] `text` 不是字符串：`SendChat()` 返回 `false`

### 性能测试

- [ ] 1000 次 `Inbound:Allow()` 调用 < 100ms
- [ ] 100 次 `Display:Transform()` 调用（5 个变换器）< 100ms
- [ ] 异常变换器不影响后续变换器执行

## 结论/下一步

本规格定义了聊天网关的三个关键入口点的完整行为契约。所有聊天数据流必须遵循此规格实现入口收口。

待验证事项：
- 变换链在高负载场景（大量消息刷屏）下的性能表现
- 变换器错误隔离的完整性（是否有遗漏的错误路径）
- Outbound Gateway 是否需要增加重试机制
