---
id: 0002
priority: P0
created: 2026-03-02
updated: 2026-03-02
relates: [#0001]
status: ACTIVE
---

# 消息流注册表规格

## 问题/目标

定义消息流注册表（Stream Registry）的数据结构与查询行为，确保频道定义的单一真相源。

## 功能规格

### 数据结构

#### 层级结构

```lua
STREAM_REGISTRY = {
  CHANNEL = {
    SYSTEM = { ... },   -- 系统内置频道
    DYNAMIC = { ... },  -- 运行时频道
  },
  NOTICE = {
    SYSTEM = { ... },   -- 系统通知
  }
}
```

#### Stream 定义契约

每个 Stream 必须包含：

```lua
{
  key = "string",           -- 唯一标识符（必需）
  chatType = "string",      -- WoW ChatType（必需）
  identity = {              -- 显示标识（必需）
    labelKey = "string",
    shortOneKey = "string",
    shortTwoKey = "string",
  },
  events = { "string", ... }, -- 关联事件列表（必需）
  priority = number,         -- 排序优先级（必需）
  defaultBindings = table,   -- 默认绑定（可选）
}
```

### 正常行为

#### 路径解析

```lua
addon:GetStreamPath(key) -> string|nil
```

**输入**：
- `key`: Stream 唯一标识符

**输出**：
- 找到：返回路径字符串（如 `"CHANNEL.SYSTEM"`）
- 未找到：返回 `nil`

**查找逻辑**：
- 遍历 `CHANNEL` 和 `NOTICE` 两个顶层分类
- 遍历每个子分类的数组
- 匹配 `stream.key == key`

#### Stream 查询

```lua
addon:GetStreamByKey(key) -> table|nil
```

**输入**：
- `key`: Stream 唯一标识符

**输出**：
- 找到：返回完整 Stream 定义表
- 未找到：返回 `nil`

#### 类型判定

```lua
addon:IsChannelStream(key) -> boolean
addon:IsNoticeStream(key) -> boolean
```

**输入**：
- `key`: Stream 唯一标识符

**输出**：
- `IsChannelStream`: 路径匹配 `^CHANNEL%.` 返回 `true`
- `IsNoticeStream`: 路径匹配 `^NOTICE%.` 返回 `true`
- 未找到或不匹配：返回 `false`

#### 默认属性推导

```lua
addon:GetStreamDefaults(key) -> table
```

**输入**：
- `key`: Stream 唯一标识符

**输出**：
- `CHANNEL.*` 路径：
  ```lua
  {
    defaultPinned = true,
    defaultSnapshotted = true,
  }
  ```
- `NOTICE.*` 路径：
  ```lua
  {
    defaultPinned = false,
    defaultSnapshotted = false,
  }
  ```
- 未找到：返回空表 `{}`

#### 属性访问器

```lua
addon:GetStreamProperty(stream, propertyName, fallbackValue) -> any
```

**查找顺序**：
1. `stream[propertyName]`（显式定义）
2. `GetStreamDefaults(stream.key)[propertyName]`（类型默认）
3. `fallbackValue`（函数参数）

### 边界条件

#### 空值/nil 处理

- `GetStreamPath(nil)` → `nil`
- `GetStreamPath("")` → `nil`
- `GetStreamByKey(nil)` → `nil`
- `GetStreamProperty(nil, ...)` → `fallbackValue`

#### 重复 key

- 注册表初始化时不允许重复 key
- 查询时返回第一个匹配项（未定义行为，应避免）

#### 不完整 Stream 定义

- 缺少必需字段：查询返回不完整对象，调用方负责验证
- `GetStreamProperty` 处理缺失字段时回退到默认值

### 异常处理

#### 注册表未初始化

- `STREAM_REGISTRY` 不存在：查询函数返回 `nil` 或空表
- 不抛出错误，静默降级

#### 事件映射冲突

- 多个 Stream 声明相同 event：触发启动时校验错误
- 在 `Config.lua` 的 `BuildEventToChatTypeFromRegistry()` 中检测

#### 无效路径模式

- `GetStreamPath` 返回不符合 `CATEGORY.SUBCATEGORY` 格式：
  - `IsChannelStream` / `IsNoticeStream` 返回 `false`
  - 不抛出错误

### 依赖与约束

#### 依赖模块

- 无运行时依赖，纯数据注册表
- 被依赖方：所有需要频道定义的模块

#### 策略层约束

- 所有频道定义必须注册到此表
- 禁止运行期修改注册表（只读数据源）
- 启动阶段一次性构建事件映射

#### 性能要求

- 查询频率：中等（每次 UI 刷新调用数十次）
- 查找算法：线性扫描（O(n)），n < 50
- 优化：高频查询应缓存结果

### 数据完整性

#### 事件映射一致性

```lua
addon:ValidateChatEventDerivation() -> boolean
```

**验证规则**：
- 所有 `CHAT_EVENTS` 必须在 `EVENT_TO_CHAT_TYPE` 中有映射
- `CHAT_MSG_CHANNEL` 必须映射到 `"CHANNEL"`
- 任何冲突立即抛出错误

#### Stream 定义验证

- 所有 `events` 数组元素必须是非空字符串
- 所有 `chatType` 必须是非空字符串
- 违反规则触发启动错误（`AddEventMapping` 中检测）

## 验证标准

### 基础查询

- [ ] 查询已注册 Stream 返回正确定义
- [ ] 查询不存在 key 返回 `nil`
- [ ] 查询 `nil` 或空字符串返回 `nil`

### 类型判定

- [ ] `IsChannelStream("say")` 返回 `true`
- [ ] `IsNoticeStream("system")` 返回 `true`（如果已注册）
- [ ] 未知 key 返回 `false`

### 默认属性

- [ ] CHANNEL 类型 `defaultPinned` 为 `true`
- [ ] NOTICE 类型 `defaultPinned` 为 `false`
- [ ] 未知 key 返回空表

### 事件映射

- [ ] 所有 Stream 的 events 正确映射到 `EVENT_TO_CHAT_TYPE`
- [ ] 无事件冲突
- [ ] `ValidateChatEventDerivation()` 通过

## 结论/下一步

本规格定义了消息流注册表的完整查询契约。所有模块必须通过此接口访问频道定义。

待验证事项：
- 大量 Stream 场景下的查询性能
- 动态频道注册/注销的支持（当前不支持）
