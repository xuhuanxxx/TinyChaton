---
id: 0014
priority: P0
created: 2026-03-05
updated: 2026-03-05
relates: [#0008, #0015, #0017, #0018]
status: ACTIVE
---

# Stream 可见性与规则范围规格

## 目标

统一 stream 可见性判定链，并把“channel-only 规则”收敛到 kind strategy，而不是散落条件分支。

## 判定链（统一）

实时与回放均按以下顺序：
1. `StreamRuleEngine` 返回 decision（`blocked/reasons/metadataPatch`）。
2. `streamBlocked[streamKey]` 终判是否隐藏。

其中：
- Rule reason 统一命名：`rule_blocked:<ruleId>`。
- stream 屏蔽统一 reason：`stream_blocked`。

## 屏蔽配置真相源

1. 唯一配置：`profile.filter.streamBlocked`。
2. `streamBlocked[streamKey] = true` 表示屏蔽。
3. notice 默认不屏蔽（空配置）。

## kind 策略范围

1. `ChannelRulesStrategy`：blacklist/whitelist/duplicate。
2. `NoticeRulesStrategy`：默认 no-op（可扩展槽位）。
3. 因此当前行为仍是 channel-only，但架构允许 notice/其他 kind 挂策略。

## 右键屏蔽能力

1. `mute_toggle` 动作为 capability 驱动（`supportsMute=true`）。
2. system + dynamic channel stream 均可挂载该动作。
3. `ToggleDynamicChannelMute` 仅为语义包装，底层统一 `ToggleStreamBlocked`。

## 非目标

1. 不新增 notice 屏蔽设置页入口。
2. 不做兼容层和迁移脚本。
