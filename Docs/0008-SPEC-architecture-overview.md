---
id: 0008
priority: P0
created: 2026-03-02
updated: 2026-03-05
relates: [#0001, #0002, #0003, #0004, #0005, #0006, #0007, #0011, #0014, #0015, #0017, #0018]
status: ACTIVE
---

# TinyChaton 架构总览规格

## 目标

给出当前稳定架构分层：`stream` 为通用处理平面，`chat` 为 channel 交互平面。

## 分层

1. Infrastructure
- RuntimeMode / CapabilityPolicy / FeatureRegistry / Gateway
- AvailabilityResolver（kind+group 注册）

2. Stream Domain（通用）
- Context: `StreamEventContext`
- Ingress: `StreamEventDispatcher`
- Rules: `StreamRuleEngine + kind strategies`
- Visibility: `StreamVisibilityService`
- Render: `MessageFormatter + kind formatters`
- Highlight: `StreamHighlighter + kind plugins`
- Contracts/Types: `StreamContracts/StreamTypes`

3. Chat Domain（channel 交互）
- StreamRegistry / ActionSend
- Interaction: Sticky/Tab/LinkHover/Emotes
- Storage: SnapshotStore/Replayer（消费 stream 结构）

4. Application
- Bootstrap / Lifecycle / Container

## 关键原则

1. `stream` 覆盖 `channel + notice`。
2. channel-only 规则是策略，不是架构限制。
3. 任何新增 kind 能力应通过注册点接入，而不是修改主流程分支。
4. 命名中性优先（如 `MessageFormatter`），行为范围由策略路由控制。

## 关键验收

1. notice 默认不过滤/不高亮，但可通过 `streamBlocked` 屏蔽。
2. black/white/duplicate/highlight 仅作用 channel（默认策略）。
3. 可新增 notice strategy/formatter/highlighter 且无需修改 dispatcher/visibility 主流程。
