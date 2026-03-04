---
id: 0018
priority: P0
created: 2026-03-05
updated: 2026-03-05
relates: [#0015, #0016, #0017]
status: ACTIVE
---

# Stream Render/Highlight 扩展点

## 目标

让渲染与高亮层的“默认 channel-only 策略”可插拔化，确保 notice/未来 kind 可平滑扩展。

## MessageFormatter 扩展点

1. 中性入口：`MessageFormatter.BuildDisplayLine(line, options)`。
2. 注册接口：`MessageFormatter.RegisterKindFormatter(kind, formatterFn)`。
3. 当前默认实现：
- `ChannelFormatter`：保留现有 channel 渲染能力（时间戳、作者、stream tag、可复制）。
- `NoticeFormatter`：透传文本（no-op）。

## StreamHighlighter 扩展点

1. 中性入口：`StreamHighlighter.Apply(context)`。
2. 注册接口：`StreamHighlighter.RegisterKindHighlighter(kind, fn)`。
3. 当前默认实现：
- `ChannelHighlight` 插件：按配置高亮名称/关键词。
- `NoticeHighlight` 插件：no-op。

## 约束与原则

1. “notice 默认不高亮”是默认插件策略，不是框架硬编码。
2. 新 kind 渲染/高亮不得改主流程分支，必须通过注册接口接入。
3. feature key 使用 `StreamHighlight`，不再绑定 channel 命名。

## 回归要点

1. channel 消息渲染与高亮行为保持不回归。
2. notice 消息默认透传且不高亮。
3. 注册 mock kind formatter/highlighter 后可立即生效。
