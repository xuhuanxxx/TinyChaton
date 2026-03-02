---
id: 0003
priority: P0
created: 2026-03-02
updated: 2026-03-02
relates: [#0001, #0002]
status: ACTIVE
---

# 动作注册表规格

## 问题/目标

定义动作注册表（Action Registry）的反向绑定机制与执行行为，确保动作定义与 Stream/KIT 的解耦。

## 功能规格

### 架构原则

**反向绑定**：Action 声明自己适用于哪些 Stream，而不是 Stream 声明可用 Actions。

### Action 定义契约

```lua
{
  key = "string",              -- 唯一标识符（必需）
  label = "string",            -- 显示名称（必需）
  category = "channel"|"kit",  -- 动作类别（必需）
  actionPlane = "USER_ACTION"|"CHAT_DATA"|"UI_ONLY", -- 运行时平面（必需）
  enabledWhenBypass = boolean, -- 是否在 BYPASS 模式可用（可选，默认 false）
  appliesTo = {                -- 适用范围（必需）
    streamPaths = { "string", ... }, -- Stream 路径模式
    kitKeys = { "string", ... },     -- KIT 键列表
  },
  execute = function(targetKey), -- 执行函数（必需）
  getLabel = function(targetKey), -- 标签生成函数（可选）
  getTooltip = function(targetKey), -- 提示生成函数（可选）
}
```

### 运行时平面定义

- **USER_ACTION**：用户主动操作（发送消息、打开面板），BYPASS 模式下禁用
- **CHAT_DATA**：聊天数据操作（静音频道、过滤规则），BYPASS 模式下禁用
- **UI_ONLY**：纯 UI 操作（打开设置、选择器），BYPASS 模式下始终可用

### 正常行为

#### 动作可执行性判定

```lua
addon:CanExecuteAction(actionKey) -> (boolean, string)
```

**输入**：
- `actionKey`: 动作唯一标识符

**输出**：
- 可执行：`(true, nil)`
- 不可执行：`(false, reason)`
  - `reason` 可能值：`"missing_action"`, `"bypass_blocked"`

**判定逻辑**：
1. 查询 `ACTION_REGISTRY[actionKey]`，不存在返回 `(false, "missing_action")`
2. 获取 Action 的 `actionPlane` 和 `enabledWhenBypass`
3. 调用 `addon:IsPlaneAllowed(actionPlane, enabledWhenBypass)`
4. 通过返回 `(true, nil)`，否则返回 `(false, "bypass_blocked")`

#### 平面权限判定

```lua
addon:IsPlaneAllowed(plane, enabledWhenBypass) -> boolean
```

**规则**：
- 当前模式为 `ACTIVE`：所有平面返回 `true`
- 当前模式为 `BYPASS`：
  - `enabledWhenBypass == true`：返回 `true`
  - `plane == "UI_ONLY"`：返回 `true`
  - `plane == "CHAT_DATA"`：返回 `false`
  - `plane == "USER_ACTION"`：返回 `false`（默认规则）

#### 动作执行

Action 的 `execute` 函数接收目标键（`streamKey` 或 `kitKey`）作为参数：

```lua
-- 示例：发送消息动作
execute = function(streamKey)
  local stream = addon:GetStreamByKey(streamKey)
  if stream and stream.chatType then
    addon:ActionSend(stream.chatType, streamKey, targetName)
  end
end
```

**约定**：
- `execute` 函数负责完整业务逻辑
- 内部需再次验证能力（通过 `addon:Can()` 或网关）
- 不抛出错误，静默失败

#### 标签生成

```lua
action.getLabel(targetKey) -> string
```

**用途**：
- 动态生成按钮/菜单显示文本
- 可访问 Stream 定义获取本地化标签

**示例**：
```lua
getLabel = function(streamKey)
  local stream = addon:GetStreamByKey(streamKey)
  return addon:ResolveDisplayIdentity(stream).label
end
```

### 边界条件

#### 空值/nil 处理

- `CanExecuteAction(nil)` → `(false, "missing_action")`
- `CanExecuteAction("")` → `(false, "missing_action")`
- `execute(nil)` → 函数内部处理，通常静默返回

#### appliesTo 为空

- `streamPaths` 和 `kitKeys` 都为空或 `nil`：Action 不适用于任何目标
- 不影响注册，但不会绑定到任何 UI 元素

#### 执行失败

- `execute` 函数抛出错误：不捕获，向上传播（Lua 默认行为）
- 建议在 `execute` 内部 `pcall` 包裹危险操作

### 异常处理

#### 注册表未初始化

- `ACTION_REGISTRY` 不存在：`CanExecuteAction` 返回 `(false, "missing_action")`
- 不抛出错误

#### Action 定义不完整

- 缺少 `execute` 函数：调用时触发 Lua 错误
- 缺少 `actionPlane`：`IsPlaneAllowed` 默认为 `UI_ONLY`
- 缺少 `appliesTo`：不绑定到任何目标

#### 路径模式匹配失败

- `appliesTo.streamPaths` 包含无效路径（如 `"INVALID.PATH"`）：
  - 不会匹配任何 Stream
  - 不抛出错误，静默忽略

### 依赖与约束

#### 依赖模块

- 必需：`addon:GetStreamByKey()` (Stream Registry)
- 必需：`addon:IsPlaneAllowed()` (Runtime Mode)
- 可选：`addon:ResolveDisplayIdentity()` (Name Policy)

#### 策略层约束

- 所有用户可触发动作必须定义为 Action
- Action 不得直接修改注册表，只能声明适用范围
- Shelf/UI 模块通过 `ACTION_REGISTRY` 查询可用动作

#### 性能要求

- `CanExecuteAction` 调用频率：中等（每次 UI 交互）
- 查表时间复杂度：O(1)
- `execute` 执行时间：< 10ms（用户交互响应）

### 典型 Actions

#### send (发送消息)

- **category**: `"channel"`
- **actionPlane**: `"USER_ACTION"`
- **appliesTo**: `CHANNEL.SYSTEM`, `CHANNEL.DYNAMIC`
- **行为**：打开输入框，设置当前频道

#### mute_toggle (静音切换)

- **category**: `"channel"`
- **actionPlane**: `"CHAT_DATA"`
- **appliesTo**: `CHANNEL.DYNAMIC`
- **行为**：切换动态频道的可见性

#### emote_panel (表情面板)

- **category**: `"kit"`
- **actionPlane**: `"UI_ONLY"`
- **enabledWhenBypass**: `true`
- **行为**：打开表情选择面板

## 验证标准

### 可执行性判定

- [ ] ACTIVE 模式下所有 Action 可执行
- [ ] BYPASS 模式下 `USER_ACTION` 平面 Action 不可执行
- [ ] BYPASS 模式下 `UI_ONLY` 平面 Action 可执行
- [ ] 不存在的 actionKey 返回 `"missing_action"`

### 反向绑定

- [ ] 定义 `appliesTo.streamPaths = {"CHANNEL.SYSTEM"}` 的 Action 应用于所有 SYSTEM 子分类 Stream
- [ ] Stream 不包含 `actions` 字段（已废弃）

### 动作执行

- [ ] `send` Action 正确打开输入框并设置频道
- [ ] `mute_toggle` Action 切换动态频道可见性
- [ ] 执行失败不导致 UI 崩溃

### 标签生成

- [ ] `getLabel` 返回本地化字符串
- [ ] 未定义 `getLabel` 时回退到 `action.label`

## 结论/下一步

本规格定义了动作注册表的反向绑定机制与执行契约。UI 模块通过此接口动态生成按钮和菜单。

待验证事项：
- 路径模式匹配的性能（通配符支持）
- 运行时添加 Action 的支持（当前不支持）
