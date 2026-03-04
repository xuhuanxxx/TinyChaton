---
id: 0015
priority: P0
created: 2026-03-05
updated: 2026-03-05
relates: [#0008, #0014, #0017, #0018]
status: ACTIVE
---

# Stream/Chat 边界与命名约束

## 目标

把 `stream`（channel + notice）和 `chat`（仅 channel 交互域）彻底分层：
1. 让通用处理平面可按 kind 扩展。
2. 让 channel 交互语义继续留在 Chat 域。
3. 避免“名字像通用、实现却写死 channel”的漂移。

## 边界定义

1. `Domain/Stream/*` 负责：事件上下文、规则引擎、可见性、格式化路由、高亮路由。
2. `Domain/Chat/Interaction/*` 继续负责：发送输入、Tab、Sticky、Emotes 面板等 channel 交互。
3. 当前产品策略仍是 channel-only（black/white/duplicate/highlight），但由 kind 策略控制，不散落硬编码。

## 命名与对象映射（破坏性）

1. `addon.ChatData` -> `addon.StreamEventContext`
2. `addon.ChatPipeline` -> `addon.StreamEventDispatcher`
3. `addon.VisibilityPolicy` -> `addon.StreamVisibilityService`
4. `addon.RuleMatcher` -> `addon.StreamRuleMatcher`
5. `addon.ChannelHighlight` -> `addon.StreamHighlighter`（channel 仅作为插件）
6. `addon.ChatContracts` / `addon.ChatTypes` -> `addon.StreamContracts` / `addon.StreamTypes`

## 目录映射

1. `Domain/Chat/Ingress/EventContextFactory.lua` -> `Domain/Stream/Context/StreamEventContext.lua`
2. `Domain/Chat/Ingress/ChatPipeline.lua` -> `Domain/Stream/Ingress/StreamEventDispatcher.lua`
3. `Domain/Chat/Policy/VisibilityPolicy.lua` -> `Domain/Stream/Visibility/StreamVisibilityService.lua`
4. `Domain/Chat/Ingress/Filters/*` -> `Domain/Stream/Rules/*`（RuleEngine + kind strategies）
5. `Domain/Chat/Render/MessageFormatter.lua` -> `Domain/Stream/Render/MessageFormatter.lua`
6. `Domain/Chat/Render/Transformers/Highlight.lua` -> `Domain/Stream/Render/Transformers/StreamHighlighter.lua`

## MessageFormatter 命名决策

`MessageFormatter` 保持中性命名，不收窄为 `ChannelMessageFormatter`。

原因：
1. 名称表达“渲染入口”而非“当前策略范围”。
2. 通过 `RegisterKindFormatter(kind, fn)` 做策略路由，保留 notice/未来 kind 的扩展点。
3. channel-only 是当前策略，不应固化为架构命名。

## 运行时键

1. Feature key: `StreamEventFilters`
2. Profiler key: `StreamEventDispatcher.Middleware.*`
3. Highlight feature key: `StreamHighlight`

## 非目标

1. 不提供旧 API 兼容别名。
2. 不提供配置迁移脚本。
3. 不新增 notice 屏蔽设置页入口（仅保留底层能力）。
