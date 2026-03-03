---
id: 0002
priority: P0
created: 2026-03-02
updated: 2026-03-04
relates: [#0001, #0011, #0012]
status: ACTIVE
---

# 消息流注册表规格

## 问题/目标

定义 Stream Registry 的 V2 结构、校验与查询接口，作为频道/通知流唯一真相源。

## 数据结构（V2）

每个 stream 必须声明：

```lua
{
  key = "string",
  kind = "channel"|"notice",
  group = "system"|"dynamic"|"private"|"alert"|"log",
  chatType = "string",
  events = { "CHAT_MSG_..." },
  priority = number,
  identity = { labelKey, shortOneKey, shortTwoKey, candidatesId? },
  capabilities = {
    inbound = boolean,
    outbound = boolean,
    snapshotDefault = boolean,
    copyDefault = boolean,
    supportsMute = boolean,
    supportsAutoJoin = boolean,
    pinnable = boolean,
  },
  defaultBindings = table|nil,
}
```

## 查询接口

- `GetStreamByKey(key)`：返回 stream。
- `GetStreamKind(key)`：返回 `channel|notice`。
- `GetStreamGroup(key)`：返回 group。
- `GetStreamCapabilities(key)`：返回 capabilities。
- `GetStreamKeysByGroup(group)`：按 group 返回 key 列表。
- `GetOutboundStreamKeys()`：返回 `outbound=true` 的 stream keys。
- `GetDynamicStreamKeys()`：返回 `kind=channel && group=dynamic` keys。

## 事件映射

- `EVENT_TO_CHAT_TYPE`：event -> chatType
- `EVENT_TO_STREAM_KEY`：event -> streamKey（排除 `CHAT_MSG_CHANNEL`）
- `ResolveStreamKey(event, ...)`：统一入口
  - `CHAT_MSG_CHANNEL` 走动态解析
  - 其他事件走 `EVENT_TO_STREAM_KEY`
  - 非 CHANNEL 事件未映射即报错

## 校验规则

- `kind/group/capabilities` 必填且合法。
- `kind=notice` 时必须 `outbound=false`、`supportsAutoJoin=false`。
- `outbound=false` 时 `defaultBindings` 禁止出现。
- event 映射冲突必须报错。

## BREAKING CHANGES

- 禁止基于 `catKey/subKey/path` 做业务判断。
- `GetStreamPath` 仅保留为诊断信息，不是策略来源。

## 验收标准

- NOTICE 事件（`CHAT_MSG_MONSTER_*`、`CHAT_MSG_RAID_BOSS_*`）有唯一 stream 映射。
- `NOTICE.ALERT` 默认 `snapshotDefault=false`、`copyDefault=false`。
- `system` group 不包含 `kind=notice` stream。
