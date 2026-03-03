---
id: 0011
priority: P0
created: 2026-03-04
updated: 2026-03-04
relates: [#0002, #0003, #0006, #0008]
status: ACTIVE
---

# Stream Registry V2 语义规格

## 问题/目标

将 stream 语义从 `catKey/subKey/path` 隐式推断升级为显式 schema：`kind + group + capabilities`，统一消费端策略判定。

## 统一 Stream 模型

```lua
{
  key = "string",
  kind = "channel" | "notice",
  group = "system" | "dynamic" | "private" | "alert" | "log",
  chatType = "string",
  events = { "CHAT_MSG_..." },
  priority = number,
  identity = {
    labelKey = "...",
    shortOneKey = "...",
    shortTwoKey = "...",
    candidatesId = "...", -- optional
  },

  capabilities = {
    inbound = boolean,
    outbound = boolean,
    snapshotDefault = boolean,
    copyDefault = boolean,
    supportsMute = boolean,
    supportsAutoJoin = boolean,
    pinnable = boolean,
  },

  defaultBindings = table|nil, -- only when outbound=true
}
```

## 字段约束

- `kind` 只允许 `channel|notice`。
- `group` 只允许 `system|dynamic|private|alert|log`。
- `kind=notice` 时：
  - `capabilities.outbound=false`
  - `capabilities.supportsAutoJoin=false`
- `capabilities.outbound=false` 时，`defaultBindings` 不允许出现。
- `events` 中每个 event 必须是非空字符串。
- schema 缺失不得在编译期自动补齐；缺字段必须在启动校验时失败。

## 编译期索引

启动构建并公开：

- `STREAM_BY_KEY`
- `EVENT_TO_STREAM_KEY`（非 `CHAT_MSG_CHANNEL`）
- `EVENT_TO_CHAT_TYPE`
- `STREAM_KEYS_BY_GROUP`
- `OUTBOUND_STREAM_KEYS`
- `DYNAMIC_STREAM_KEYS`

## 统一解析入口

`ResolveStreamKey(event, ...)` 规则：

1. `event == CHAT_MSG_CHANNEL`：走动态频道语义解析。
2. 其他 event：走 `EVENT_TO_STREAM_KEY[event]`。
3. 非 `CHAT_MSG_CHANNEL` 且未映射：直接报错，不静默降级。

## Toggle 判定

统一使用：

`ResolveStreamToggle(streamKey, dbMap, capabilityField, fallback)`

判定顺序：

1. `dbMap[streamKey]` 显式配置（若存在）
2. `stream.capabilities[capabilityField]`
3. `fallback`

用于：

- 快照存储：`snapshotChannels + snapshotDefault`
- 点击复制：`copyChannels + copyDefault`
- 自动加入：`supportsAutoJoin`
- 置顶默认：`pinnable`

## BREAKING CHANGES

1. 消费端禁止依赖 `subKey == "DYNAMIC"`、`GetStreamPath():match(...)` 做策略判断。
2. 非 `CHAT_MSG_CHANNEL` 未映射事件会直接报错。
3. `notice` 与 `system` 分组语义分离，`notice` 不并入 channel system。
4. 旧字段仅作为镜像别名保留，不再是策略主来源。

## 验收要点

- `CHAT_MSG_MONSTER_*`、`CHAT_MSG_RAID_BOSS_*` 必须映射到 `NOTICE` stream。
- 默认 `NOTICE.ALERT`：`snapshotDefault=false`、`copyDefault=false`。
- `system` 分组不包含任何 `kind=notice` stream。
- 发送动作仅生成于 `outbound=true` stream。
