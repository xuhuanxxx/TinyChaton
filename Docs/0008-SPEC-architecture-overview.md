---
id: 0008
priority: P0
created: 2026-03-02
updated: 2026-03-05
relates: [#0001, #0002, #0003, #0004, #0005, #0006, #0007, #0011, #0014, #0015, #0017, #0018, #0024, #0025, #0026, #0027, #0028, #0029, #0030]
status: ACTIVE
---

# TinyChaton 架构总览规格

## 目标

给出当前稳定架构分层：`stream` 为通用处理平面，`chat` 为 channel 交互平面。

## 分层

1. Libs（机制内核层）
- `Libs/TinyCore/Stream/*`（pipeline/rule/render plugins）
- `Libs/TinyCore/SettingsOrchestrator/*`（subscriber/orchestrator）
- `Libs/TinyCore/DI/*`（container/validation）
- `Libs/TinyCore/RuntimeGovernor/*`（capability/feature/reconciler）
- `Libs/TinyCore/RegistryCompiler/*`（compiler/artifact/passes）
- `Libs/TinyCore/SettingsSchema/*`（schema registry/validator/control model）

2. Infrastructure（平台适配）
- RuntimeMode / CapabilityPolicy / FeatureRegistry / RegistryCompiler / Gateway
- AvailabilityResolver（kind+group 注册）
- 说明：Infrastructure 已调整为 TinyCore adapter + WoW transport。

3. Stream Domain（通用）
- Registry: `StreamRegistry`
- Actions: `StreamActionRegistry`
- Context: `StreamEventContext`
- Ingress: `StreamEventDispatcher`
- Rules: `StreamRuleEngine`（委托 TinyCore RuleEngine）
- Visibility: `StreamVisibilityService`
- Render: `MessageFormatter`（委托 TinyCore Render/KindPlugins）
- Highlight: `StreamHighlighter`（委托 TinyCore KindPlugins）
- Storage: `SnapshotStore/SnapshotReplayer`
- Contracts/Types: `StreamContracts/StreamTypes`

4. Chat Domain（channel 交互）
- Interaction: Sticky/Tab/LinkHover/Emotes
- Automation: AutoJoin/AutoWelcome

5. Settings Domain（schema + UI 适配）
- SettingsService/SettingsControls（委托 TinyCore SettingsSchema）
- SettingsPages（WoW Settings API 渲染与接线）

6. Application
- Bootstrap / Lifecycle / Container

## 关键原则

1. `stream` 覆盖 `channel + notice`。
2. channel-only 规则是策略，不是架构限制。
3. 任何新增 kind 能力应通过注册点接入，而不是修改主流程分支。
4. 命名中性优先（如 `MessageFormatter`），行为范围由策略路由控制。

## 当前状态（2026-03-05）

1. `STEP 01-06` 已全部完成并合并（见 `#0024-#0029`）。
2. 分支与 Libs 落位基线已执行（见 `#0030`）。
3. 当前结构为 `TinyCore 内核 + Domain/Infrastructure 适配` 的稳定态。

## 关键验收

1. notice 默认不过滤/不高亮，但可通过 `streamBlocked` 屏蔽。
2. black/white/duplicate/highlight 仅作用 channel（默认策略）。
3. 可新增 notice strategy/formatter/highlighter 且无需修改 dispatcher/visibility 主流程。
