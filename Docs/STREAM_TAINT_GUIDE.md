# Stream 架构下的 Taint 与战斗安全指南

本文档旨在指导 AI（或开发者）如何利用 TinyChaton 的 **Stream 架构** 与 **EventDispatcher** 处理世界之战 (WoW) 12.0+ 中的 Taint（污染）与战斗限制。

## 1. 核心防御理念

在 12.0+ 版本中，对底层聊天系统的直接 Hook 极易引发 `Action Forbidden`。我们的策略是：
- **声明化定义**：在 `Stream.lua` 中通过标志位标记流的安全属性。
- **集中化拦截**：在 `EventDispatcher.lua` 中统一进行状态判断，而非散落在各功能逻辑中。
- **战斗静默**：战斗中禁止执行任何涉及 `ChatFrame` 内部结构修改、颜色标签注入或 SecureTemplate 的操作。

## 2. 标志位扩展 (Stream.lua)

在 `STREAM_REGISTRY` 中为特定流添加以下建议标志位：

```lua
{
    key = "raid_boss_emote",
    -- ...
    isCombatProtected = true,  -- 标记此消息在战斗中产生
    preventTaint = true,       -- 告知处理器：即使在非战斗状态，也要以最高安全级别处理
    deferredVisual = true,     -- 视觉增强（如高亮、改色）需延迟到脱战后
}
```

## 3. 在 EventDispatcher 中注入拦截逻辑

`EventDispatcher:OnChatEvent` 是处理污染的最佳入口。AI 应遵循以下模式：

### A. 战斗检查封装
```lua
function Dispatcher:OnChatEvent(event, ...)
    local inCombat = InCombatLockdown()
    local streamKeys = self:GetStreamsForEvent(event)
    
    for _, key in ipairs(streamKeys) do
        local stream = addon:GetStreamByKey(key)
        
        -- 核心防御规则 1: 战斗中跳过敏感流的逻辑处理
        if inCombat and stream.isCombatProtected then
            return false -- 正常放行，不做任何处理以防 Taint
        end
        
        -- ... 执行正常逻辑
    end
end
```

### B. 视觉污染防护 (Visual.lua 适配)
当 `ShortenChannelString` 或高亮逻辑被调用时：
- **检查调用上下文**：如果处于战斗中，且尝试修改的 `ChatFrame` 是系统核心窗口，则原始返回。
- **使用备份文本**：永远不要直接修改 `_G["CHAT_MSG_..."]` 全局变量，而是通过 `ChatFrame_AddMessageEventFilter` 返回修改后的文本，且在战斗中禁用此 Filter 的副作用。

## 4. 常见任务处理模式

### 场景一：为战斗中的 Boss 喊话添加颜色
**错误做​​法**：在 `onEvent` 里直接拼凑 `|cff...|r` 并尝试更新 UI。
**正确做法**：
1. 在 `Stream.lua` 中为 `monster_yell` 添加 `safeInCombat = true`。
2. 在 `EventDispatcher` 中判断 `if inCombat and not stream.safeInCombat then return false end`。
3. 仅注入颜色标签，禁用任何涉及 Frame 层级的操作（如调用 `PlaySound` 或刷新面板）。

### 场景二：战斗中加入/离开频道
**禁止操作**：在战斗中调用 `JoinChannelByName`。
**模式**：
1. 检查 `InCombatLockdown()`。
2. 如果在战斗中，将请求压入 `addon.queuedActions`。
3. 监听 `PLAYER_REGEN_ENABLED` 事件，并在脱战后清空队列。

## 5. 给 AI 的 CheckList

当被要求“给 X 频道添加高亮/处理”时，AI 必须：
1. [ ] 检查 `Stream.lua` 中 X 的定义。
2. [ ] 是否需要添加 `isCombatProtected`？
3. [ ] `EventDispatcher` 是否已经监听了相关事件？
4. [ ] 处理逻辑是否包含 `if InCombatLockdown() then return end` 的前置守卫？
5. [ ] 如果是 UI 修改，是否提供了脱战后的回填机制？

---

*注意：污染通常源于对 SecureHeader 或 UIDropDownMenu 的非安全访问。永远优先使用渲染器 (TinyReactor) 的 Reconcile 机制，因为它在容器层面做了基本的战斗安全过滤。*
