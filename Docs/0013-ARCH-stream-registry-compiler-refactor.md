---
id: 0013
priority: P0
created: 2026-03-04
updated: 2026-03-05
relates: [#0002, #0003, #0006, #0008, #0011, #0012]
status: ACTIVE
---

# Stream Registry Compiler 重构蓝图

## 问题/目标

在 `c45af29`（V2 收口）基础上，单开一轮“注册表编译器”重构，把当前“注册表定义 + Config 索引构建 + 校验分散”的模式，收敛为一个显式、可测试、可扩展的编译管线。

目标：

1. 建立唯一编译入口，产出稳定的 runtime 索引。
2. 让 schema 校验、冲突检测、事件映射完整性在编译阶段一次性完成。
3. 让消费端只依赖 compiler 输出，不直接推断 `STREAM_REGISTRY` 原始层级。

## 当前基线

- 代码基线提交：
  - `9a8b10b`（Stream V2 主改）
  - `c45af29`（schema 强校验 + action 去重）
- 当前关键事实：
  - `kind/group/capabilities` 已显式化。
  - `ResolveStreamKey` 已统一入口。
  - 非 `CHAT_MSG_CHANNEL` 未映射事件已在启动校验强失败。

## 非目标

1. 不改聊天业务策略（快照、复制、重放规则本身不改）。
2. 不改 WoW 交互行为（发送命令、事件监听模型不改）。
3. 不做 SavedVariables 迁移脚本。
4. 不引入新的 `kind/group` 枚举。

## 编译器目标模型

建议新增模块：`Infrastructure/Runtime/StreamRegistryCompiler.lua`

建议公开接口：

```lua
-- 输入：原始 STREAM_REGISTRY 定义
-- 输出：compiled（不可变语义对象）
addon.StreamRegistryCompiler:Compile(registry) -> compiled

-- 失败：直接 error（启动期中断）
```

`compiled` 最小字段：

```lua
{
  byKey = { [streamKey] = normalizedStream },
  rawByKey = { [streamKey] = rawStreamRef },

  kindByKey = { [streamKey] = "channel"|"notice" },
  groupByKey = { [streamKey] = "system"|"dynamic"|"private"|"alert"|"log" },
  capabilitiesByKey = { [streamKey] = { ... } },

  eventToChatType = { [event] = chatType },
  eventToStreamKey = { [event] = streamKey }, -- exclude CHAT_MSG_CHANNEL
  chatEvents = { ...sorted... },

  streamKeysByGroup = { [group] = { ... } },
  outboundStreamKeys = { ... },
  dynamicStreamKeys = { ... },
}
```

## 编译阶段（建议）

1. `SchemaPass`
- 校验 stream 必填字段：`key/kind/group/chatType/events/priority/identity/capabilities`。
- 校验 capability 子字段全布尔。
- 校验约束：
  - `kind=notice => outbound=false && supportsAutoJoin=false`
  - `outbound=false => defaultBindings=nil`
  - `defaultAutoJoin ~= nil => supportsAutoJoin=true`

2. `NormalizePass`
- 只对编译产物做 normalize（不要回写 raw 定义）。
- 衍生 legacy mirror（`defaultPinned/defaultSnapshotted/defaultCopyable/isInboundOnly/defaultAutoJoin`）仅进入编译副本。

3. `IndexPass`
- 构建 `byKey/kindByKey/groupByKey/capabilitiesByKey`。
- 构建 `streamKeysByGroup/outboundStreamKeys/dynamicStreamKeys`。

4. `EventPass`
- 构建 `eventToChatType`。
- 构建 `eventToStreamKey`（排除 `CHAT_MSG_CHANNEL`）。
- 校验：
  - 非 `CHAT_MSG_CHANNEL` 的 `CHAT_MSG_*` 事件必须有 stream 映射。
  - event 冲突直接失败。

5. `FreezePass`（可选）
- 给编译结果加只读保护（debug 模式优先）。

## 模块迁移策略

### 阶段 1：引入编译器（不改消费端 API）

文件：
- `Infrastructure/Runtime/StreamRegistryCompiler.lua`（新）
- `Config.lua`

动作：
- `Config.lua` 改为调用 `compiler:Compile(addon.STREAM_REGISTRY)`。
- 现有 accessor 继续保留：
  - `GetStreamByKey/GetStreamKind/GetStreamGroup/GetStreamCapabilities/...`
- 这些 accessor 改为从 `compiled` 读。

### 阶段 2：消费端去耦 raw registry

重点模块：
- `ActionRegistry`
- `SnapshotStore/SnapshotReplayer/MessageFormatter`
- `AvailabilityResolver/StreamVisibilityService/AutoJoinHelper`
- `Buttons/ShelfService/ChannelCandidatesRegistry`

动作：
- 禁止业务逻辑直接遍历 `STREAM_REGISTRY.CHANNEL.*`。
- 统一改为 `IterateCompiledStreams()` 或 `byKey + group index`。
- `MessageFormatter` 保持中性命名，不将 notice 扩展能力绑定在 channel 命名上。

### 阶段 3：收口旧辅助路径

动作：
- `GetStreamPath` 明确标记 `diagnostic-only`。
- 清理剩余 path/subKey 语义注释与测试假设。
- 文档整体切到 compiler 视角。

## 测试矩阵（新增）

1. 编译器单测（建议新建 `Infrastructure/Runtime/StreamRegistryCompilerTests.lua`）
- 缺字段失败：`kind/group/capabilities`。
- notice 约束失败。
- duplicate key 失败。
- duplicate event 映射冲突失败。
- 非 CHANNEL 事件未映射失败。

2. 集成回归（`InternalTests.lua`）
- `ResolveStreamKey` 路由行为不变。
- `ResolveStreamToggle` 默认值逻辑不变。
- `send_<streamKey>` 动作集合稳定。

3. 静态检查
- `luac -p $(rg --files -g '*.lua')` 必须通过。

## 验收标准

1. 编译入口单一：`Config` 不再手写分散构建索引函数。
2. 原始 `STREAM_REGISTRY` 在编译后不被回写。
3. 任何 schema/映射问题都在启动编译阶段失败。
4. 现有功能行为无回归（快照、复制、重放、发送、自动加入）。

## 风险与控制

风险：
- 启动阶段失败路径集中后，短期内报错会更多。
- 编译器切换时可能影响初始化顺序。

控制：
- 先落阶段 1，保持 accessor API 不变。
- 每阶段单独提交，保证可回滚。

## 新会话开场模板（可直接贴）

```text
请基于当前仓库 HEAD，实施 Docs/0013-ARCH-stream-registry-compiler-refactor.md。

约束：
1) 允许破坏性变更，不做数据迁移脚本。
2) 分三阶段提交（编译器引入 -> 消费端切换 -> 收口清理）。
3) 每阶段必须补对应测试并跑 luac 全量语法检查。

基线参考提交：
- 9a8b10b
- c45af29
```
