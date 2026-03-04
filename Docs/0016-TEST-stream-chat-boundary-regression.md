---
id: 0016
priority: P1
created: 2026-03-05
updated: 2026-03-05
relates: [#0014, #0015, #0017, #0018]
status: ACTIVE
---

# Stream/Chat 边界回归测试

## 目标

验证“策略 channel-only、架构 stream-extensible”是否同时成立。

## 回归矩阵

1. Rule Engine
- `StreamRuleEngine` 对 `kind=channel` 应命中 black/white/duplicate。
- `kind=notice` 默认策略 no-op，不拦截。
- 支持注册新 kind strategy 并即时生效。

2. Visibility
- realtime/snapshot 都通过 RuleEngine 决策。
- `streamBlocked[streamKey]=true` 对 channel/notice 都生效。
- `streamBlocked` 默认为空时，notice 默认可见。

3. Formatter
- `MessageFormatter.RegisterKindFormatter` 可注册 kind formatter。
- channel 走 channel formatter，notice 走 notice formatter（当前透传）。

4. Highlighter
- `StreamHighlighter.RegisterKindHighlighter` 可注册 kind 插件。
- channel 插件生效，notice 插件默认 no-op。

5. Action + Availability
- capability 注册不再强绑 channel；通过 `appliesTo.streamKind/group` 约束。
- `AvailabilityResolver.RegisterResolver(kind, group, fn)` 可扩展。
- system + dynamic stream 都具备右键 `mute_toggle_*`（按 capability）。

6. Snapshot/Copy 配置键
- `chat.content.snapshotStreams` 生效。
- `chat.interaction.copyStreams` 生效。
- 回放结构使用 `line.streamKey`。

## 通过标准

1. `Infrastructure/Runtime/InternalTests.lua` 通过新增扩展点回归项。
2. `luac -p` 全量 Lua 文件通过。
3. 全仓无核心旧对象残留（业务代码）：
- `addon.ChatData`
- `addon.ChatPipeline`
- `addon.VisibilityPolicy`
- `addon.ChannelHighlight`
- `addon.Filters.BlacklistProcess/WhitelistProcess/DuplicateProcess`

## 人工验证建议

1. 在 `notice` 上注入 mock strategy/formatter/highlighter，验证无需改主流程即可接入。
2. 游戏内验证 system + dynamic 的右键屏蔽均可用。
3. 验证 notice 默认可见，设置 `streamBlocked` 后实时/回放均隐藏。
