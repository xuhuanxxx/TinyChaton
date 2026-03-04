---
id: 0021
priority: P1
created: 2026-03-05
updated: 2026-03-05
assignee:
relates: [#0008, #0009, #0013, #0015]
status: ACTIVE
---

# TinyChaton 自由 Code Review

## 问题/目标

基于 AGENT.md 架构约束，对全库做一次无差别审计。目标：发现逻辑缺陷、违反架构不变量、性能瓶颈、可维护性问题。

## 内容

### 一、架构与设计层面

#### 1.1 CloneValue 防御过度，高频路径性能杀手

`Config.lua` L96-110 定义了 `CloneValue`，所有 `GetStreamByKey`、`GetStreamCapabilities`、`IterateCompiledStreams`、`GetStreamKeysByGroup` 等高频查询每次调用都做深拷贝。

```lua
function addon:GetStreamByKey(key)
    local compiled = GetCompiledRegistry()
    local byKey = compiled.byKey
    if type(byKey) ~= "table" then return nil end
    return CloneValue(byKey[key])  -- 每次调用深拷贝
end
```

编译结果已通过 `StreamRegistryCompiler` 冻结（`__newindex` 报错），深拷贝是多余的——调用方拿到只读表即可。`IterateCompiledStreams` 在每轮迭代都克隆，在 `BuildChannelPins`/`BuildSnapshotStreams`/`BuildCopyStreams`/`BuildAutoJoinDynamicChannels` 等多个启动路径中 N 次遍历 x N 次克隆，启动期累积开销不可忽视。

**风险**: P1 性能。高频路径无意义分配。
**建议**: 只读数据直接返回引用；若调用方确需修改，由调用方负责拷贝。

#### 1.2 SnapshotStore 与 StreamEventDispatcher 双重监听同一事件（By Design）

`SnapshotStore.lua` 创建了独立的 `loggerFrame` 注册所有 chat 事件，`StreamEventDispatcher` 也注册了同一批事件并在 PERSIST 阶段运行中间件。SnapshotLogger 既作为 FeatureRegistry 注册的独立事件监听者，又在 Dispatcher 的 PERSIST 阶段有可能被重复触发（取决于是否有 PERSIST 中间件也做 snapshot）。

当前实际上 SnapshotStore 的 `OnSnapshotEvent` 是通过独立 Frame 直接监听事件，不走 Dispatcher 管线。这意味着：
- Dispatcher 的 BLOCK 阶段判定"应该隐藏"的消息，SnapshotStore 仍然会记录。
- 这是**设计选择**：BLOCK 影响显示，不影响留存；快照通道保留追回/复盘能力。

**结论**: `Won't Fix`（当前版本）。若未来要统一管线，前提是 Dispatcher 显式支持“即使被屏蔽也持久化”语义。

#### 1.3 EmitChatMessage 绕过 Gateway

`CapabilityPolicyEngine.lua` L37-48:

```lua
function addon:EmitChatMessage(text, wowChatType, language, target)
    if self.Gateway and self.Gateway.Outbound and self.Gateway.Outbound.SendChat then
        return self.Gateway.Outbound:SendChat(text, wowChatType, language, target)
    end
    -- 直接 fallback 到 SendChatMessage
    if not self:Can(self.CAPABILITIES.EMIT_CHAT_ACTION) then return false end
    SendChatMessage(text, wowChatType, language, target)
    return true
end
```

Gateway 不存在时直接调用 `SendChatMessage`，形成旁路。但 Gateway 在 TOC 加载顺序中先于 CapabilityPolicyEngine 加载，正常情况下 Gateway 必定存在。这个 fallback 要么是死代码，要么在异常启动时绕过网关——两种情况都不该保留。

**风险**: P2 入口收口违反。
**建议**: 删除 fallback 分支，Gateway 不存在时直接 `return false`。

#### 1.4 DI 容器实际使用率极低

`App/DI/Container.lua` 实现了完整的 DI 容器（value/singleton/factory、循环检测、冻结），但 `App/Container.lua` 仅注册了 5 个服务（Addon、TinyReactor、EventBus、ChatGateway、StreamVisibilityService）。绝大多数模块仍通过 `addon.XXX` 直接访问，DI 容器形同虚设。

这不是"用不用 DI"的问题，而是系统中存在两套服务获取方式。违反 AGENT.md "同一能力只能有一条主执行路径"。

**风险**: P2 架构一致性。
**建议**: 要么扩展 DI 容器覆盖核心服务，要么删除 DI 容器只保留 `addon.XXX` 模式。选一条路。

---

### 二、逻辑缺陷

#### 2.1 StreamEventDispatcher.OnStreamEvent 返回值语义矛盾

`StreamEventDispatcher.lua` L285-288:

```lua
if shouldHide or emitted then
    return true
end
return shouldHide, addon.Utils.UnpackArgs(packedArgs)
```

第 288 行：到达此处时 `shouldHide` 恒为 `false`（因为若为 true 已在 285 行返回）。实际语义是 `return false, addon.Utils.UnpackArgs(packedArgs)`。用变量 `shouldHide` 做返回值在语义上误导读者以为存在"部分隐藏"的可能。

**风险**: P3 可读性。
**建议**: 直接写 `return false, addon.Utils.UnpackArgs(packedArgs)`。

#### 2.2 Config.lua GetDefaultWelcomeTemplates fallback 冗余

`Config.lua` L15:

```lua
return #templates > 0 and templates or {}
```

`templates` 初始为 `{}`，`#templates > 0` 为 false 时返回 `{}`——和 `templates` 本身完全等价。这行三元表达式什么都没做。

**风险**: P3 代码噪声。
**建议**: 直接 `return templates`。

#### 2.3 SetSettingValue 缺少互斥分支

`Config.lua` L450-457:

```lua
function addon:SetSettingValue(key, value)
    local reg = addon:GetSettingInfo(key)
    if not reg then return end
    if reg.accessor and reg.accessor.set then reg.accessor.set(value) end
    if reg.set then reg.set(value) end
    if reg.setValue then reg.setValue(value) end
end
```

三个 `if` 不互斥。SettingsSchema.lua 末尾 L680-681 会将 `reg.accessor.set` 设为 `reg.set or reg.setValue`，所以 `accessor.set` 和 `reg.set` 指向同一函数，导致 set 被调用两次。

`GetSettingValue` 也有同样问题（L442-444），但 get 一般是幂等的所以不致命。set 被调用两次在大多数场景下也是幂等的（赋值），但若 set 内有副作用（onChange、通知）则会双重触发。

**风险**: P2 逻辑缺陷。
**建议**: 改为 `if/elseif` 互斥链，或统一只用 `accessor`。

#### 2.4 Pool.Acquire 每次检查 IsFrameObject

`ObjectPool.lua` L31-33:

```lua
if IsFrameObject(obj) and addon.Warn then
    addon:Warn(...)
end
```

这个检查在每次 Acquire 都执行。对于 `StreamEventContext` 这种高频对象池，每条消息都调 `GetObjectType` 方法是浪费。这个警告应该只在 Pool:Create 的 factory 首次调用时检查一次。

**风险**: P2 高频路径性能。
**建议**: 在 `Create` 时检查 factory 返回值一次，标记 pool 类型。Acquire/Release 不再检查。

#### 2.5 Events.lua 不支持 UnregisterEvent

`App/Events.lua` 只有 `RegisterEvent`，没有 `UnregisterEvent`。一旦注册，handler 永远存在。`Shutdown` 中直接操作各子系统停止，但事件 handler 本身不清理。

若同一函数在 disable/enable 周期中被重新注册，L17-19 的去重逻辑会阻止重复注册——但如果换了一个新闭包（函数引用不同），旧的 handler 仍在列表中。

**风险**: P2 生命周期可逆性不完整。
**建议**: 补充 `UnregisterEvent(event, fn)`。

---

### 三、防御性与健壮性

#### 3.1 Bootstrap.lua 中 addon.db.profile 的 nil 链

`Bootstrap.lua` L332:

```lua
if not addon.db.profile then addon.db.profile = {} end
```

`addon.db` 是 metatable 代理，`addon.db.profile` 触发 `__index`，返回的是 `currentProfileCache.profile` 或 `TinyChatonDB.profiles[name].profile`。`addon.db.profile = {}` 触发 `__newindex`，直接写入 `currentProfileCache["profile"] = {}`。

这意味着如果 profile 表结构不存在，这里会创建一个空表覆盖真实数据来源。但 `InitConfig` 已确保 profiles 表和默认 profile 存在，所以这行是死代码——除非在 `InitConfig` 之前调用 `SynchronizeConfig`（不应该发生）。

**风险**: P3 误导性防御代码。
**建议**: 替换为断言 `assert(addon.db.profile, "profile not initialized")`，或删除。

#### 3.2 Logger.lua 使用 GetTime 但 SlashCmdList 用 date

`Logger.lua` L84: `time = GetTime()`（返回运行秒数，非 Unix 时间戳）
`Logger.lua` L148: `date("%H:%M:%S", err.time)`（`date` 期望 Unix 时间戳）

`GetTime()` 返回的是游戏客户端启动以来的秒数（浮点数），传给 `date` 会被解释为 1970-01-01 之后的秒数，显示出完全错误的时间。

**风险**: P1 逻辑 Bug。
**建议**: 将 L84 改为 `time = time()`（标准 Lua Unix 时间戳），或在格式化时用 `GetTime` 的差值显示相对时间。

#### 3.3 FormatColorHex 返回值顺序与 ParseColorHex 不对称

`Utils.lua`:
- `ParseColorHex` 返回 `r, g, b, a`（L74）
- `FormatColorHex` 参数是 `r, g, b, a`（L92 签名），但内部 format 顺序是 `a, r, g, b`（L93-97）——这是正确的 AARRGGBB 格式

但 `MessageFormatter.lua` L71 调用：

```lua
return addon.Utils.FormatColorHex(msgColor.r, msgColor.g, msgColor.b)
```

缺少 alpha 参数，`a` 默认为 `nil`，`(a or 1) * 255 = 255`，得到 `FF` 前缀。这个 case 恰好正确。但如果调用方传了 alpha 为 0-1 范围的值作为第四参数，排列正确。

这里没有 bug，但 `ParseColorHex` 返回 `r, g, b, a` 而 `FormatColorHex` 内部排列 `a, r, g, b` 的不对称性容易让后续调用方犯错（比如用解构赋值直接传入）。

**风险**: P3 接口易误用。
**建议**: 在 `FormatColorHex` 注释中明确标注 "returns AARRGGBB string from r,g,b,a parameters"。

---

### 四、风格与一致性

#### 4.1 存在性检查风格不统一

全库有三种存在性检查风格混用：
1. `if addon.XXX and addon.XXX.YYY then`（Bootstrap.lua L26, L32-38 等大量）
2. `if type(addon.XXX) == "function" then`（FeatureRegistry.lua L57）
3. `RequireMethod` 断言式（Lifecycle.lua L14-19）

按 AGENT.md "依赖顺序由清单保证，业务模块不为可能未加载做兜底"的原则，大量的 `if addon.XXX then` 检查是对 TOC 加载顺序的不信任。对于 TOC 保证加载顺序的核心模块，应使用 `RequireMethod` 风格断言，而非静默跳过。

**风险**: P2 变更准则违反。
**建议**: 区分"TOC 保证存在"和"运行时可选"两类依赖。前者用断言，后者用可选检查并统一命名约定（如 `addon.XXX?` 或文档标注）。

#### 4.2 Profiler 样板代码泛滥

`ChatGateway.lua` 中 Profiler Start/Stop 占据了大量行数：

```lua
if addon.Profiler and addon.Profiler.Start then
    addon.Profiler:Start("ChatGateway.Inbound.Allow")
end
-- ... 3 行业务逻辑 ...
if addon.Profiler and addon.Profiler.Stop then
    addon.Profiler:Stop("ChatGateway.Inbound.Allow")
end
```

`Gateway.Inbound:Allow` 共 32 行，其中 18 行是 Profiler 守卫。信噪比极低。`RunMiddlewares` 中也有同样问题（L141-148, L169-171, L189-191）。

**风险**: P2 可维护性。
**建议**: 封装 `addon:WithProfiler(label, fn)` 或利用尾调用模式减少样板。

#### 4.3 SettingsSchema.lua onChange 回调高度重复

`SettingsSchema.lua` 中，`dataSnapshotStorageDefaultMax`、`dataSnapshotStorageOverrideEnabled`、`dataSnapshotStorageOverrideValue`、`dataSnapshotReplayDefaultMax`、`dataSnapshotReplayOverrideEnabled`、`dataSnapshotReplayOverrideValue` 六个设置的 `onChange` 回调几乎完全相同：

```lua
onChange = function()
    if addon.NormalizeSnapshotLimits then addon:NormalizeSnapshotLimits() end
    if addon.SyncTrimSnapshotToLimit and addon.GetEffectiveSnapshotStorageLimit then
        addon:SyncTrimSnapshotToLimit(addon:GetEffectiveSnapshotStorageLimit())
    end
    if addon.TriggerEviction then addon:TriggerEviction() end
    if addon.RefreshAllSettings then addon:RefreshAllSettings() end
end,
```

6 份完全相同的闭包。

**风险**: P3 DRY 违反。
**建议**: 提取为 `local SnapshotLimitsOnChange = function() ... end`，6 处引用同一函数。

#### 4.4 Bootstrap.lua ApplyAllSettings 是方法存在性检查的集散地

`Bootstrap.lua` L24-40:

```lua
function addon:ApplyAllSettings()
    if not addon.db.enabled then ... end
    if addon.ApplyChatFontSettings then addon:ApplyChatFontSettings() end
    if addon.ApplyStickyChannelSettings then addon:ApplyStickyChannelSettings() end
    if addon.ApplyFilterSettings then addon:ApplyFilterSettings() end
    if addon.ApplyAutoJoinSettings then addon:ApplyAutoJoinSettings() end
    if addon.ApplyAutoWelcomeSettings then addon:ApplyAutoWelcomeSettings() end
    if addon.ApplyShelfSettings then addon:ApplyShelfSettings() end
    if addon.RefreshShelf then addon:RefreshShelf() end
    if addon.FireEvent then addon:FireEvent("SETTINGS_APPLIED") end
end
```

每个方法都做存在性检查，但这些方法在 TOC 中早于 `ApplyAllSettings` 的调用时机加载。如果其中任何一个缺失，应该是 fatal 而非静默跳过——否则用户会看到"设置已应用"但实际上某个子系统没生效，排查极其困难。

**风险**: P2。
**建议**: 走 FeatureRegistry 或 callback 机制，由各模块自己订阅 `SETTINGS_APPLIED` 事件。

---

### 五、性能

#### 5.1 Emotes.Parse 每条消息遍历 61 个表情

`Emotes.lua` L49-63:

```lua
function addon.EmotesRender.Parse(msg)
    local emotes = EnsureEmotes()
    for _, e in ipairs(emotes) do
        msg = msg:gsub(e.pattern, e.replacement)
    end
    return msg
end
```

8 个 raid marker + 53 个自定义表情 = 61 次 `gsub`。每条聊天消息都执行。绝大多数消息不包含任何表情，但仍然做 61 次模式匹配。

**风险**: P2 高频路径性能。
**建议**: 先做快速预检 `if not msg:find("{", 1, true) then return msg end`，无 `{` 直接短路。

#### 5.2 IterateCompiledStreams 返回迭代器闭包 + 每次克隆

每次调用 `IterateCompiledStreams` 创建一个新闭包，且每轮迭代调用 `CloneValue`。在 `BuildChannelPins`、`BuildSnapshotStreams`、`BuildCopyStreams`、`BuildAutoJoinDynamicChannels` 四个启动函数中各调用一次，共 4 次全量遍历+克隆。

**风险**: P2 启动性能。
**建议**: 配合 1.1 的建议，迭代器直接返回引用。或将 Build* 函数合并为一次遍历。

#### 5.3 SnapshotStore 创建冗余 StreamEventContext

`SnapshotStore.lua` L260:

```lua
local streamContext = addon.StreamEventContext and addon.StreamEventContext:New(nil, event, ...)
```

SnapshotStore 独立监听事件，每条消息创建一个完整的 `StreamEventContext`（含 pool acquire、字符串处理、stream key 解析），仅用于提取 text/author/channelNumber 等字段。如果走 Dispatcher 管线（见 1.2），可以直接复用已有 context，省去这次分配。

**风险**: P2 与 1.2 关联。
**建议**: 纳入 Dispatcher 管线后自动解决。

---

### 六、杂项

#### 6.1 字符串拼接绕过 taint 检测

多处使用字符串拼接构造 API 名：
- `StreamEventDispatcher.lua` L2: `_G["Chat" .. "Frame_AddMessageEventFilter"]`
- `MessageFormatter.lua` L2: `_G["C_" .. "CVar"]`
- `SnapshotStore.lua` L2: `_G["Create" .. "Frame"]`

这是 WoW addon 中常见的 taint 规避手法，但散落各处缺乏统一管理。

**建议**: 集中到一个文件（如 `WowApi/SafeAccess.lua`），统一导出所有需要拼接绕过的 API 引用。

#### 6.2 SettingsSchema.lua 末尾的自动推断逻辑

L657-682 遍历所有 SETTING_REGISTRY 条目，自动补全 `scope`、`valueType`、`accessor`。这段逻辑在模块加载时执行（非函数内），依赖 `default` 的返回值推断类型——如果 `default` 是 function 会立即调用。

问题：此时部分依赖（如 `addon.db`）可能尚未初始化。幸运的是，当前所有 `default` 函数只依赖 `addon.CONSTANTS` 和 `CVarAPI`，在此时已可用。但这是隐式依赖，后续新增 setting 若 default 函数访问 `addon.db` 将静默失败。

**风险**: P3 脆弱的初始化时序。
**建议**: 在注释中标注 "default functions MUST NOT access addon.db at registration time"。

#### 6.3 RecursiveSync isReset 清理逻辑只删字符串键

`Bootstrap.lua` L66-72:

```lua
if isReset then
    for k, _ in pairs(target) do
        if source[k] == nil and type(k) == "string" then
            target[k] = nil
        end
    end
end
```

只清理字符串键，数字键的过时数据会保留。当前 DEFAULTS 结构中没有数字键的 table 条目，所以不是问题，但限制条件隐含在数据结构中而非代码注释中。

**风险**: P3。
**建议**: 添加注释说明为何只清理字符串键。

## 执行状态（2026-03-05）

### 已完成（本轮已落地）

1. **#1.1 CloneValue 高频深拷贝移除（破坏式）**
   - 已在 `Config.lua` 删除 `CloneValue` 热路径使用。
   - `GetStreamByKey/GetStreamCapabilities/GetStreamKeysByGroup/GetOutboundStreamKeys/GetDynamicStreamKeys/GetChatEvents/IterateCompiledStreams` 全部改为直接返回编译产物引用。

2. **#1.3 EmitChatMessage 旁路移除**
   - 已在 `Infrastructure/Runtime/CapabilityPolicyEngine.lua` 删除 `SendChatMessage` fallback。
   - Gateway 不可用时直接 `return false`，保证单入口发送链路。

3. **#2.3 SetSettingValue/GetSettingValue 双轨调用清理**
   - 已在 `Config.lua` 统一只走 `reg.accessor`。
   - setter/getter 缺失改为显式报错，防止静默失败。

4. **#4.1 + #4.4 核心设置应用链硬失败化（部分）**
   - 已在 `App/Bootstrap.lua` 的 `ApplyAllSettings` 引入 `RequireAddonMethod`。
   - 对核心方法（字体、粘性、过滤、自动加入、欢迎词、货架刷新、事件派发）改为硬依赖，不再 `if addon.X then` 静默跳过。

5. **#3.1 SynchronizeConfig 防御性空表写入移除**
   - 已在 `App/Bootstrap.lua` 用 `type(...) ~= "table"` 直接报错替代兜底写入。

6. **#5.1 Emotes 热路径短路**
   - 已在 `Domain/Chat/Render/Transformers/Emotes.lua` 增加 `if not msg:find("{", 1, true) then return msg end`。

7. **#3.2 Logger 时间戳 bug 修复**
   - 已在 `Infrastructure/Runtime/Logger.lua` 将 `GetTime()` 改为 `time()`，与 `date()` 语义对齐。

8. **#1.2 设计意图固化（文档+代码）**
   - 已在 `Domain/Stream/Storage/SnapshotStore.lua` 增加 BY_DESIGN 注释：隐藏不等于不持久化。
   - 本文档 #1.2 标记为 `Won't Fix`（当前版本）。

9. **测试同步（破坏式语义）**
   - 已在 `Infrastructure/Runtime/InternalTests.lua` 将“返回副本”测试改为“共享引用”语义，并补清理步骤。

### 未完成（本轮未动代码）

1. **#2.4 Pool.Acquire 高频检查**
   - `ObjectPool.lua` 仍在 Acquire/Release 路径做 `IsFrameObject` 检查。

2. **#2.5 Events 缺少 UnregisterEvent**
   - `App/Events.lua` 仍无显式反注册接口。

3. **#1.4 DI 双轨收敛**
   - 目前仍是 `ServiceContainer` 与 `addon.XXX` 并存状态，未做单轨化决策与迁移。

4. **#4.2 Profiler 样板收敛**
   - 仍未抽 `WithProfiler`。

5. **#4.3 onChange 回调去重**
   - SettingsSchema 中重复闭包仍在。

6. **#6.1 taint 访问集中化**
   - `_G["..."]` 拼接访问仍分散在多个模块。

### 不需要改（当前结论）

1. **#1.2 Snapshot 独立监听**
   - 明确是产品设计：BLOCK 控制显示，Snapshot 保留追溯。当前不改。

2. **#3.3 FormatColorHex/ParseColorHex**
   - 结论为“易误用但非 bug”；当前无需改逻辑，仅可补注释。

3. **#6.3 RecursiveSync 仅清理字符串键**
   - 在当前数据模型下无实际缺陷，属于约束说明不足，不属于阻塞问题。

4. **#2.2 GetDefaultWelcomeTemplates fallback 冗余**
   - 已顺手清理为 `return templates`，无需后续动作。

### TODO（下一批建议）

1. **P1/P2 功能与生命周期**
   - 实现 `App/Events.lua` 的 `UnregisterEvent(event, fn)`（对应 #2.5）。
   - 优化 `ObjectPool.lua`：把 frame 对象检查前置到 `Create` 或首次 factory 样本（对应 #2.4）。

2. **P2 架构收敛**
   - 对 #1.4 做明确决策并出 ADR：  
   - 方案 A：全面迁移到 DI。  
   - 方案 B：冻结/移除 DI，仅保留 `addon.XXX`。

3. **P2 可维护性**
   - 抽 `WithProfiler(label, fn)`，替换高噪音 Start/Stop 样板（#4.2）。
   - 抽取 Snapshot limits 共用 `onChange` 闭包（#4.3）。

4. **P3 文档与约束**
   - 在 `SettingsSchema.lua` 自动推断区补注释：`default` 函数不得依赖 `addon.db`（#6.2）。
   - 为 `FormatColorHex` 增加参数/返回约定注释（#3.3）。

5. **验证 TODO**
   - 增加回归：BLOCK 后消息不显示但可从 snapshot replay 找回（对应 #1.2 By Design）。
