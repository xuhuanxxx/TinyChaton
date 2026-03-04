---
id: 0006
priority: P1
created: 2026-03-02
updated: 2026-03-05
relates: [#0001, #0005, #0011]
status: ACTIVE
---

# 快照存储规格

## 问题/目标

定义快照存储与重放在 Stream V2 下的统一决策：按 streamKey + capability 判定。

## 存储决策

入库前必须先解析 streamKey：

- `streamKey = ResolveStreamKey(event, ...)`
- `enabled = ResolveStreamToggle(streamKey, snapshotStreams, "snapshotDefault", true)`
- `enabled=false` 则直接跳过，不入库

## 点击复制决策

渲染时：

- `enabled = ResolveStreamToggle(streamKey, copyStreams, "copyDefault", true)`
- 仅 `enabled=true` 时写入点击复制缓存

## NOTICE 默认策略

- `notice.alert`：默认不存储、默认不复制。
- 用户在设置页勾选后才生效。

## 回放上限

- 运行时 `GetEffectiveSnapshotReplayLimit()` 必须硬钳制 `<= 200`。
- 即便配置写入更大值，也以 200 为上限。

## 数据结构

- 按 streamKey 分桶：`TinyChatonCharDB.snapshot[streamKey] = RingBuffer`
- 环形缓冲区仍为 FIFO，支持批量淘汰最旧记录。
- 实现位置：`Domain/Stream/Storage/SnapshotStore.lua` 与 `Domain/Stream/Storage/SnapshotReplayer.lua`。

## BREAKING CHANGES

- 快照与复制不再按路径分组判定。
- 未映射事件不会静默入库。

## 验收标准

- 默认状态下 NPC/Boss（NOTICE.ALERT）不入库不复制。
- 勾选 notice 快照后可入库并参与重放。
- 勾选 notice 复制后可点击复制。
- 重放数量任何情况下不超过 200。
