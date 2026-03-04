---
id: 0012
priority: P0
created: 2026-03-04
updated: 2026-03-05
relates: [#0011, #0002, #0003, #0006, #0008]
status: ACTIVE
---

# Stream Registry V2 迁移架构说明

## 目标

将核心消费点从路径语义迁移到 `kind/group/capabilities`，并收口为统一 streamKey 决策。

## 迁移清单

### 注册表与索引

- `Domain/Stream/Registry/StreamRegistry.lua`
  - 统一注入 `kind/group/capabilities`。
- `Config.lua`
  - 构建 `EVENT_TO_STREAM_KEY`、`STREAM_KEYS_BY_GROUP`、`OUTBOUND_STREAM_KEYS`、`DYNAMIC_STREAM_KEYS`。

### 解析入口

- `Domain/Stream/Storage/SnapshotKeys.lua`
  - 新增 `ResolveStreamKey` 作为统一入口。
  - 移除 `GetChannelKey` 入口，统一调用 `ResolveStreamKey`。

### 策略消费端

- `Domain/Stream/Render/MessageFormatter.lua`
  - 点击复制改为 `ResolveStreamToggle(..., "copyDefault")`。
  - 名称保持中性，通过 stream kind 路由 channel/notice。
- `Domain/Stream/Storage/SnapshotStore.lua`
  - 快照存储改为 `ResolveStreamToggle(..., "snapshotDefault")`。
- `Domain/Stream/Storage/SnapshotReplayer.lua`
  - 过滤分组改为 `kind/group`。

### 动态频道能力

- `Infrastructure/Runtime/ChannelSemanticResolver.lua`
- `Infrastructure/Runtime/AvailabilityResolver.lua`
- `Domain/Stream/Visibility/StreamVisibilityService.lua`
- `Domain/Chat/Automation/AutoJoinHelper.lua`
- `Domain/Chat/ChannelCandidatesRegistry.lua`

全部改为 capability/group 判定，不再匹配路径字符串。

### Action/UI 消费

- `Domain/Stream/Actions/StreamActionRegistry.lua`
  - `appliesTo.streamCapabilities` 驱动构建（如 `outbound=true`, `supportsMute=true`）。
- `Domain/Shelf/ShelfService.lua`
- `Domain/Settings/Pages/Buttons.lua`

改为按 `kind/group` 聚合频道。

## 旧判断到新语义映射

- `catKey == "CHANNEL" and subKey == "DYNAMIC"`
  -> `kind == "channel" and group == "dynamic"`
- `GetStreamPath(key):match("^CHANNEL%.SYSTEM$")`
  -> `kind == "channel" and group == "system"`
- `stream.defaultCopyable/defaultSnapshotted`
  -> `capabilities.copyDefault/snapshotDefault`
- `stream.isInboundOnly`
  -> `capabilities.outbound == false`

## 失败与回滚策略（代码层）

- 启动阶段校验失败（schema/映射冲突）直接中止初始化。
- 保留旧函数壳（如 `GetChannelKey`）仅用于过渡调用点定位，不作为兼容承诺。
- 回滚方式：回退提交，不提供数据迁移脚本。

## BREAKING CHANGES

1. 路径字符串不再作为策略来源。
2. 未映射非 CHANNEL 事件直接报错。
3. `notice` 独立分组，不归并 `system`。
4. 不提供旧配置字段迁移脚本。
5. Stream 域命名重排（`StreamEventContext/StreamEventDispatcher/StreamVisibilityService`）不保留旧别名。
