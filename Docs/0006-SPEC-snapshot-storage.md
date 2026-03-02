---
id: 0006
priority: P1
created: 2026-03-02
updated: 2026-03-02
relates: [#0001, #0005]
status: ACTIVE
---

# 快照存储规格

## 问题/目标

定义快照存储（Snapshot Store）的数据结构与容量管理行为，确保聊天历史持久化的可靠性与性能。

## 功能规格

### 数据结构

#### 环形缓冲区（Ring Buffer）

```lua
{
  head = number,     -- 队首索引（最旧消息）
  tail = number,     -- 队尾索引（最新消息）
  size = number,     -- 当前元素数量
  items = {          -- 数据数组
    [index] = record
  }
}
```

**特性**：
- 先进先出（FIFO）队列
- 固定容量，超出时自动删除最旧记录
- 索引从 1 开始递增（Lua 约定）

#### 快照记录结构

```lua
{
  text = "string",      -- 消息文本
  author = "string",    -- 作者名（可选）
  channelKey = "string",-- 频道键
  time = number,        -- 时间戳
}
```

#### 存储结构

```lua
TinyChatonCharDB = {
  snapshot = {
    ["channelKey1"] = RingBuffer,
    ["channelKey2"] = RingBuffer,
    ...
  },
  settings = {
    maxStorageLines = number,  -- 全局存储上限
    maxReplayLines = number,   -- 回放上限
  },
  lineCount = number,  -- 总行数缓存
}
```

### 正常行为

#### 环形缓冲区操作

**创建**：
```lua
CreateRingBuffer() -> buffer
```
- 返回初始化的空缓冲区
- `head=1, tail=0, size=0, items={}`

**入队**：
```lua
PushRingBuffer(buffer, value)
```
- 在 `tail` 后添加元素
- `tail` 递增，`size` 递增
- 不检查容量上限（由上层控制）

**删除最旧元素**：
```lua
PopOldest(buffer, n) -> removedCount
```
- 删除前 `n` 个最旧元素
- `head` 前移，`size` 减少
- 返回实际删除数量（不超过 `size`）
- 触发紧凑化（Compact）

**紧凑化**：
```lua
CompactRingBuffer(buffer)
```
- 触发条件：`head > 64` 且 `head > tail / 2`
- 将 `[head, tail]` 区间数据移动到 `[1, size]`
- 重置 `head=1, tail=size`
- 释放旧索引内存

#### 容量管理

**全局行数统计**：
```lua
addon:GetSnapshotLineCount() -> number
```
- 返回所有频道缓冲区的总 `size` 之和
- 首次调用计算并缓存到 `TinyChatonCharDB.lineCount`
- 后续调用直接返回缓存值

**容量限制读取**：
```lua
addon:GetSnapshotLimitsSettings() -> table
```
- 返回 `TinyChatonCharDB.settings`
- 包含 `maxStorageLines` 和 `maxReplayLines`

**容量限制修正**：
```lua
ClampLimit(value, minValue, maxValue, fallback) -> number
```
- `value` 在 `[minValue, maxValue]` 范围内：返回 `value`
- `value` 超出范围或 `nil`：返回 `fallback`
- 用于修正用户配置

#### 快照记录

**记录消息**（中间件逻辑）：
1. 检查 `addon:Can(PERSIST_CHAT_DATA)` 是否允许
2. 检查频道是否启用快照
3. 获取或创建频道的环形缓冲区
4. 创建快照记录并 `PushRingBuffer`
5. 更新 `lineCount` 缓存
6. 检查全局容量上限，超出则修剪最旧记录

**容量修剪**：
- 总行数超过 `maxStorageLines`：
  - 遍历所有频道缓冲区
  - 从每个缓冲区删除部分最旧记录
  - 优先修剪较大的缓冲区

### 边界条件

#### 空缓冲区

- `size=0` 时 `PopOldest` 返回 `0`（不操作）
- `size=0` 时不触发紧凑化

#### 单频道存储

- 只有一个频道缓冲区时，修剪直接删除该频道最旧记录
- 不影响其他频道（每频道独立缓冲区）

#### lineCount 缓存失效

- `TinyChatonCharDB.lineCount` 为 `nil`：重新计算
- `TinyChatonCharDB.lineCount` 类型错误：重置为 `nil` 后重新计算

#### 容量上限为 0

- `maxStorageLines=0`：不记录任何快照
- 已有数据不自动清空（需手动清理）

### 异常处理

#### 数据库未初始化

- `TinyChatonCharDB` 不存在：自动创建空表
- `TinyChatonCharDB.snapshot` 不存在：自动创建空表
- `EnsureCharSnapshotDB()` 保证数据库结构完整

#### 无效缓冲区

- `IsRingBuffer(buffer)` 返回 `false`：操作静默跳过
- 不抛出错误，不修改数据

#### 记录失败

- 能力不允许（`Can` 返回 `false`）：跳过记录
- 频道未启用快照：跳过记录
- 消息文本为 `nil` 或非字符串：跳过记录

#### 紧凑化异常

- `buffer.items` 为空：重置为空表
- 索引越界：Lua 返回 `nil`（不抛出错误）

### 依赖与约束

#### 依赖模块

- 必需：`TinyChatonCharDB` (SavedVariables)
- 必需：`addon:Can()` (Capability Policy Engine)
- 可选：`addon:GetConfig()` (Configuration)

#### 策略层约束

- 快照记录必须在 LOG 阶段中间件执行
- 快照记录不得阻塞消息显示（异步或低优先级）
- 容量修剪在后台执行，不影响消息流

#### 性能要求

- `PushRingBuffer`: O(1)，< 0.1ms
- `PopOldest`: O(n)（紧凑化），< 5ms（n < 1000）
- `GetSnapshotLineCount`: O(1)（缓存），< 0.1ms
- 完整容量修剪：< 50ms（全局容量 5000 行）

### 数据完整性

#### 行数一致性

- `lineCount` 缓存必须与实际行数一致
- 每次 `Push` 或 `Pop` 后更新 `lineCount`
- 重载后自动重新计算（缓存失效）

#### 频道隔离

- 每个频道独立缓冲区
- 一个频道的修剪不影响其他频道
- 频道删除时缓冲区不自动清理（需手动）

#### 时间戳单调性

- 快照记录的 `time` 字段应单调递增（不强制）
- 时间戳由调用方提供（通常为 `GetTime()`）

### 容量策略

#### 默认容量

- `maxStorageLines`: 5000 行（全局）
- `maxReplayLines`: 1000 行（单次回放）
- 可调范围：
  - `maxStorageLines`: 1000 - 20000
  - `maxReplayLines`: 100 - 20000

#### 修剪策略

- 触发时机：每次 `Push` 后检查全局容量
- 修剪目标：删除 10% 最旧记录（约 500 行）
- 分配策略：按频道缓冲区大小比例分配删除量

#### 回放限制

- 回放时读取不超过 `maxReplayLines` 行
- 从最新记录倒序读取
- 不影响存储容量

## 验证标准

### 环形缓冲区

- [ ] 创建空缓冲区：`size=0, head=1, tail=0`
- [ ] 入队 1 条：`size=1, head=1, tail=1`
- [ ] 入队 100 条：`size=100, head=1, tail=100`
- [ ] 删除 50 条：`size=50, head=51, tail=100`
- [ ] 紧凑化后：`head=1, tail=50`

### 容量管理

- [ ] 总行数 0 时 `GetSnapshotLineCount()` 返回 0
- [ ] 记录 100 条后返回 100
- [ ] 修剪 50 条后返回 50
- [ ] 重载后重新计算正确

### 快照记录

- [ ] 能力允许时记录成功
- [ ] 能力不允许时跳过记录
- [ ] 频道未启用快照时跳过记录
- [ ] 记录后 `lineCount` 正确更新

### 容量修剪

- [ ] 总行数超过 `maxStorageLines` 触发修剪
- [ ] 修剪后总行数低于上限
- [ ] 修剪优先删除最旧记录
- [ ] 修剪不影响未超限频道

### 性能测试

- [ ] 记录 1000 条消息 < 100ms
- [ ] 修剪 500 条记录 < 50ms
- [ ] 紧凑化 1000 条记录 < 10ms

## 结论/下一步

本规格定义了快照存储的完整数据结构与容量管理契约。快照记录作为 LOG 阶段中间件执行。

待验证事项：
- 大容量场景（20000 行）下的修剪性能
- 频道数量增多（50+ 频道）时的容量分配公平性
- 紧凑化触发频率与内存占用的平衡
