---
id: 0007
priority: P1
created: 2026-03-02
updated: 2026-03-02
relates: [#0002, #0003]
status: ACTIVE
---

# Shelf 服务规格

## 问题/目标

定义 Shelf 服务的按钮生成与布局行为，确保频道按钮的动态显示与交互的一致性。

## 功能规格

### 架构原则

**数据驱动 UI**：Shelf 按钮完全由以下数据源驱动：
1. **Stream Registry**：频道/流定义
2. **Kit Registry**：工具包定义
3. **Action Registry**：动作绑定
4. **User Configuration**：用户配置（Pin/Order/Bindings）

**无状态渲染**：每次刷新完全重建 UI，不维护增量状态。

### 按钮生成逻辑

#### 频道按钮生成

**数据源**：
- `STREAM_REGISTRY.CHANNEL.*`：所有频道流
- `addon.db.profile.buttons.channelPins`：Pin 状态
- `addon.db.profile.buttons.mutedDynamicChannels`：静音状态

**生成规则**：
1. 遍历所有 `CHANNEL` 类别的 Stream
2. 检查 Pin 状态：
   - `channelPins[stream.key] == true`：生成按钮
   - `channelPins[stream.key] == false`：跳过
   - `channelPins[stream.key] == nil`：使用 `defaultPinned`
3. 检查动态频道可用性：
   - 静态频道（如 `SAY`, `GUILD`）：始终生成
   - 动态频道（如 `CHANNEL`）：检查 `GetChannelList()` 是否存在
4. 检查静音状态：
   - `mutedDynamicChannels[stream.key] == true`：跳过（不显示）
   - 否则：生成按钮

**按钮数据**：
```lua
{
  type = "channel",
  key = stream.key,
  label = ResolveDisplayIdentity(stream).label,
  color = ResolveColor(stream),
  actions = GetApplicableActions(stream),
  dynamicInfo = ResolveDynamicInfo(stream), -- 可选
}
```

#### Kit 按钮生成

**数据源**：
- `KIT_REGISTRY`：工具包定义
- `addon.db.profile.buttons.kitPins`：Pin 状态

**生成规则**：
1. 遍历 `KIT_REGISTRY`
2. 检查 Pin 状态：
   - `kitPins[kit.key] == true`：生成按钮
   - `kitPins[kit.key] == false`：跳过
   - `kitPins[kit.key] == nil`：使用 `defaultPinned`
3. 所有 Kit 按钮始终可用（不受能力约束）

**按钮数据**：
```lua
{
  type = "kit",
  key = kit.key,
  label = kit.label,
  icon = kit.icon, -- 可选
  actions = GetApplicableActions(kit),
}
```

#### 按钮排序

**排序依据**：
1. `addon.db.profile.buttons.buttonOrder`（用户自定义顺序）
2. Stream/Kit 的 `priority` 字段
3. `key` 字母序（同优先级）

**排序逻辑**：
```lua
if buttonOrder[a.key] and buttonOrder[b.key] then
  return buttonOrder[a.key] < buttonOrder[b.key]
elseif buttonOrder[a.key] then
  return true  -- 有序的排在前面
elseif buttonOrder[b.key] then
  return false
else
  return (a.priority or 0) < (b.priority or 0) 
    or (a.key < b.key)
end
```

### 动态频道处理

#### 频道列表缓存

```lua
GetCachedChannelList() -> { id, name, ... }
```

**缓存策略**：
- TTL: 1 秒
- 缓存失效后重新调用 `GetChannelList()`
- 减少 WoW API 调用频率

**失效触发**：
- 手动调用 `addon.Shelf:InvalidateChannelListCache()`
- 监听事件：`CHANNEL_UI_UPDATE`, `CHAT_MSG_CHANNEL_NOTICE`

#### 动态频道匹配

**匹配规则**：
- Stream 定义 `dynamicNamePattern`（Lua 模式）
- 遍历 `GetChannelList()` 结果
- `channelName:match(dynamicNamePattern)` 返回 `true` 则匹配

**示例**：
```lua
{
  key = "trade",
  dynamicNamePattern = "^%d+%.%s*交易",
  ...
}
```

匹配频道名：`"2. 交易 - 暴风城"`

#### 动态频道状态

**可见性判定**：
1. 频道必须在 `GetChannelList()` 中存在
2. 频道不在 `mutedDynamicChannels` 中
3. 频道 Pin 状态为 `true`

**活跃频道解析**：
```lua
ResolveDynamicActiveName(stream) -> { activeName, activeId }
```
- 返回当前匹配的频道名和 ID
- 用于显示标签和发送目标

### 正常行为

#### Shelf 刷新

```lua
addon:RefreshShelf()
```

**执行流程**：
1. 检查 `addon.db.profile.buttons.enabled` 是否为 `true`
2. 生成频道按钮列表
3. 生成 Kit 按钮列表
4. 合并并排序按钮
5. 调用渲染层 `ShelfRender:UpdateButtons(buttons)`

**触发时机**：
- 用户修改 Pin 配置
- 频道列表变化（`CHANNEL_UI_UPDATE`）
- 主题/配置变更
- 手动调用

#### 动作绑定查询

```lua
GetApplicableActions(target) -> { actionKey, ... }
```

**查询逻辑**：
1. 遍历 `ACTION_REGISTRY`
2. 检查 `action.appliesTo.streamPaths` 或 `action.appliesTo.kitKeys`
3. 匹配目标的路径或键
4. 返回适用的 actionKey 列表

**绑定优先级**：
1. 用户自定义绑定（`addon.db.profile.buttons.bindings[key]`）
2. Stream/Kit 的 `defaultBindings`
3. Action 的默认绑定

### 边界条件

#### 无频道可用

- 所有频道被静音或未 Pin：生成空按钮列表
- Shelf 显示空白或隐藏（由渲染层决定）

#### 动态频道全部离线

- 动态频道未在 `GetChannelList()` 中：不生成按钮
- 用户加入频道后自动出现（通过事件触发刷新）

#### buttonOrder 不完整

- `buttonOrder` 只包含部分按钮：有序按钮排在前，其余按优先级
- `buttonOrder` 包含不存在按钮：忽略（不生成）

#### 缓存失效

- 频道列表缓存过期：重新调用 `GetChannelList()`
- 手动失效后立即刷新

### 异常处理

#### Stream/Kit 定义缺失

- `STREAM_REGISTRY` 不存在：生成空按钮列表
- `KIT_REGISTRY` 不存在：跳过 Kit 按钮生成

#### 配置缺失

- `channelPins` 不存在：使用 `defaultPinned`
- `buttonOrder` 不存在：使用优先级排序

#### 动作查询失败

- `ACTION_REGISTRY` 不存在：按钮无可用动作
- 渲染层处理无动作按钮（禁用或隐藏）

#### 渲染层失败

- `ShelfRender:UpdateButtons()` 抛出错误：不影响数据层
- 错误向上传播，由调用方处理

### 依赖与约束

#### 依赖模块

- 必需：`addon.STREAM_REGISTRY` (Stream Registry)
- 必需：`addon.KIT_REGISTRY` (Kit Registry)
- 必需：`addon.ACTION_REGISTRY` (Action Registry)
- 必需：`addon.db.profile.buttons` (Configuration)
- 可选：`addon.ShelfRender` (Rendering Layer)

#### 策略层约束

- Shelf 刷新频率应限制在 1 秒内最多 1 次（防止频繁刷新）
- 动态频道查询应使用缓存，不直接调用 WoW API
- 按钮生成纯计算逻辑，不修改数据库

#### 性能要求

- 完整 Shelf 刷新（50 个按钮）：< 10ms（数据层）
- 动态频道匹配（10 个动态频道）：< 2ms
- 频道列表缓存命中：< 0.1ms

### 主题属性查询

#### 获取主题属性

```lua
addon:GetShelfThemeProperties(themeKey) -> properties
```

**属性来源**：
1. 主题预设（`ThemeRegistry:GetPreset(themeKey)`）
2. 用户自定义覆盖（`addon.db.profile.shelf.themes[themeKey]`）

**合并策略**：
- 用户自定义覆盖预设
- 表类型字段（如 `bgColor`）完全替换，不深度合并

**默认主题**：
- 主题键无效：回退到 `SHELF_DEFAULT_THEME`
- 主题注册表不存在：返回空属性表

## 验证标准

### 按钮生成

- [ ] Pin 的频道生成按钮
- [ ] 未 Pin 的频道不生成按钮
- [ ] 静音的动态频道不生成按钮
- [ ] 离线的动态频道不生成按钮

### 按钮排序

- [ ] `buttonOrder` 定义的顺序优先
- [ ] 未定义顺序的按优先级排序
- [ ] 相同优先级按 key 字母序

### 动态频道

- [ ] 加入频道后按钮出现
- [ ] 离开频道后按钮消失
- [ ] 频道列表缓存正确（1 秒内不重复调用）
- [ ] 手动失效后立即刷新

### 动作绑定

- [ ] 用户自定义绑定优先
- [ ] 回退到默认绑定
- [ ] 无绑定时按钮禁用或隐藏

### 性能测试

- [ ] 刷新 50 个按钮 < 10ms
- [ ] 动态频道匹配 10 个频道 < 2ms
- [ ] 频道列表缓存命中 < 0.1ms

## 结论/下一步

本规格定义了 Shelf 服务的完整按钮生成逻辑。渲染层（ShelfRender）负责 UI 实现，数据层（ShelfService）负责业务逻辑。

待验证事项：
- 大量动态频道场景（50+ 频道）的性能表现
- 频道列表缓存失效策略的准确性
- 按钮排序在复杂 `buttonOrder` 配置下的稳定性
