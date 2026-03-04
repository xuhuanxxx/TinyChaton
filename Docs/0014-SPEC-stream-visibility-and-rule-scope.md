---
id: 0014
priority: P0
created: 2026-03-05
updated: 2026-03-05
relates: [#0003, #0007, #0008, #0011]
status: ACTIVE
---

# Stream 可见性与规则命中范围规格

## 问题/目标

统一 Stream 屏蔽真相源，并明确黑白名单与高亮的命中范围，避免 notice 与 channel 行为混淆。

## 内容

### 1. 统一屏蔽配置

- 屏蔽配置唯一真相源：`addon.db.profile.filter.streamBlocked`。
- 配置结构：`[streamKey] = true` 表示屏蔽；未设置或 `nil` 表示可见。
- `notice` 默认不屏蔽（配置默认空表）。

### 2. 可见性判定规则

- 实时消息与回放消息统一使用 stream 级判定：
1. 先评估规则过滤（blacklist/whitelist/duplicate 的 metadata）。
2. 再评估 `streamBlocked[streamKey]`。
- 当 `streamBlocked[streamKey] == true` 时，消息不可见。
- 该规则同时适用于 `kind=channel` 与 `kind=notice`。

### 3. 动态/系统右键屏蔽能力

- `mute_toggle` 动作绑定规则保持 capability 驱动：
  - 仅绑定到 `capabilities.supportsMute == true` 的 stream。
- system 与 dynamic 组中的支持项均可生成 `mute_toggle_<streamKey>`。
- `ToggleDynamicChannelMute` 保留为 dynamic 语义包装，底层委托统一 `ToggleStreamBlocked`。

### 4. 黑白名单命中范围

- `blacklist/whitelist` 仅对 `kind=channel` 生效。
- 对 `kind=notice`：
  - 不命中名称规则。
  - 不命中关键词规则。
  - 不参与 whitelist 放行/拦截决策。

### 5. 重复消息过滤命中范围

- `duplicate` 仅对 `kind=channel` 生效。
- 对 `kind=notice`：
  - 不参与重复命中判定。
  - 不写入重复检测状态缓存。

### 6. 高亮命中范围

- `highlight` 仅对 `kind=channel` 生效。
- `kind=notice` 永不高亮。
- 配置结构保持不变（不新增 highlight 专用范围字段）。

### 7. 非目标

- 本规格不新增设置页中的 notice 屏蔽入口。
- 本规格不定义旧字段迁移与向后兼容策略。

## 结论/下一步

- 本规格将 Stream 屏蔽与规则命中范围在语义上收口为：
1. “是否显示”由 `streamBlocked` 决定最终结果。
2. “规则处理（black/white/duplicate/highlight）”仅限 `kind=channel`。
- 待验证事项：
1. 游戏内回归验证 system 与 dynamic 右键屏蔽入口可用。
2. 游戏内验证 notice 在配置屏蔽前后显示行为符合预期。
