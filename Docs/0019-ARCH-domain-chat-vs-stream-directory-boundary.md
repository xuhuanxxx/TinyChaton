---
id: 0019
priority: P0
created: 2026-03-05
updated: 2026-03-05
relates: [#0008, #0015, #0016]
status: ACTIVE
---

# Domain/Chat 与 Domain/Stream 目录边界

## 目标

把 `chat=channel`、`stream=channel+notice` 变成目录级硬约束，防止职责漂移。

## 目录归属规则

1. `Domain/Stream/*`
- 通用处理平面：Registry、Actions、Ingress、Rules、Visibility、Render、Storage、Contracts、Types。
- 必须可被 `channel` 与 `notice` 共同消费。

2. `Domain/Chat/*`
- channel 交互平面：输入交互、Tab、Sticky、Emote UI、自动化交互。
- 不承载 stream 通用策略或存储。

## 本次迁移映射

1. `Domain/Chat/StreamRegistry.lua` -> `Domain/Stream/Registry/StreamRegistry.lua`
2. `Domain/Chat/ActionRegistry.lua` -> `Domain/Stream/Actions/StreamActionRegistry.lua`
3. `Domain/Chat/Storage/SnapshotKeys.lua` -> `Domain/Stream/Storage/SnapshotKeys.lua`
4. `Domain/Chat/Storage/SnapshotStore.lua` -> `Domain/Stream/Storage/SnapshotStore.lua`
5. `Domain/Chat/Storage/SnapshotReplayer.lua` -> `Domain/Stream/Storage/SnapshotReplayer.lua`

## 命名白名单/黑名单

1. 白名单（通用层）
- `streamKey`
- `streamKind`
- `streamGroup`
- `streamMeta`
- `wowChatType`

2. 黑名单（通用层禁止）
- `chatData`
- `registryKey`
- `channelKey`（除纯 channel 交互局部场景）
- 裸 `chatType`（除 WoW EditBox attribute 语境）

## 审核要求

1. 新增 Stream 域代码若出现黑名单命名，PR 直接驳回。
2. 新增 Chat 域代码若引入 notice 通用逻辑，PR 直接驳回。
