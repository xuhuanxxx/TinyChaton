---
id: 0023
priority: P2
created: 2026-03-05
updated: 2026-03-05
relates: [#0008, #0017, #0018, #0022]
status: ACTIVE
---

# TinyChaton 可框架化实现审查（按“对标可行性”重排）

## 审查范围

1. 仅讨论“可抽象为框架”的实现机会。
2. 不做 BUG、回归、性能结论。
3. 本文将实现分为三类：
- A 类：可直接对标著名框架。
- B 类：只能概念对标，不应一一映射。
- C 类：不宜对标，应保持领域特化。

## 总体判断

1. 当前架构确实有明显的 Spring/中间件框架影子。
2. 但并非所有模块都适合“以对标为主线”推进。
3. 推荐策略：`A 类按对标推进 + B 类按抽象原则推进 + C 类保持 WoW 特化`。

---

## A 类：可直接对标（优先）

### A1. Stream Pipeline + 插件体系

1. 现有实现：
- `Domain/Stream/Ingress/StreamEventDispatcher.lua`
- `Domain/Stream/Rules/StreamRuleEngine.lua`
- `Domain/Stream/Render/MessageFormatter.lua`
- `Domain/Stream/Render/Transformers/StreamHighlighter.lua`

2. 对标框架：
- Koa/Express middleware
- ASP.NET Core middleware pipeline
- Spring WebFlux filter chain（思路层）

3. 可抽象内核：
- 阶段流水线、priority 排序、异常隔离
- kind strategy/formatter/highlighter 注册协议

### A2. Settings Orchestrator + Subscriber

1. 现有实现：
- `Domain/Settings/SettingsOrchestrator.lua`
- `Domain/Settings/SettingsSubscriberRegistry.lua`

2. 对标框架：
- Spring `ApplicationEvent + Ordered`
- .NET hosted pipeline（阶段化编排）

3. 可抽象内核：
- phase + priority + key 订阅模型
- commit context（traceId/reason/scope）

### A3. 轻量 DI 容器

1. 现有实现：
- `App/DI/Container.lua`
- `App/Container.lua`

2. 对标框架：
- Spring IoC
- .NET DI container

3. 可抽象内核：
- value/singleton/factory
- 依赖链解析、循环检测、freeze

---

## B 类：只能概念对标（谨慎）

### B1. Feature/Capability Runtime Governance

1. 现有实现：
- `Infrastructure/Runtime/FeatureRegistry.lua`
- `Infrastructure/Runtime/CapabilityPolicyEngine.lua`
- `Infrastructure/Runtime/RuntimeCoordinator.lua`

2. 可参考对象（仅理念）：
- LaunchDarkly/Unleash（能力门控）
- Kubernetes reconcile loop（状态重协调）

3. 不应硬对标点：
- 这里是“运行态能力矩阵 + 游戏环境事件切换”，不是标准 SaaS feature flag 平台。

### B2. Registry Compiler（Stream/Action）

1. 现有实现：
- `Domain/Stream/Registry/StreamRegistry.lua`
- `Infrastructure/Runtime/StreamRegistryCompiler.lua`
- `Domain/Stream/Actions/StreamActionRegistry.lua`

2. 可参考对象（仅理念）：
- Terraform/Babel/AST 多 pass 编译思想

3. 不应硬对标点：
- 这是运行时配置编译，不是通用语言编译器，也不是 IaC plan/apply 体系。

### B3. Schema 驱动设置 UI

1. 现有实现：
- `Domain/Settings/SettingsService.lua`
- `Domain/Settings/SettingsControls.lua`

2. 可参考对象（仅理念）：
- Django Form / JSON Schema Form

3. 不应硬对标点：
- 依赖 WoW `Settings.*` 原生 API，UI 生命周期与 Web 表单库差异很大。

---

## C 类：不宜对标（保持领域特化）

### C1. WoW Transport 与 Chat 协议细节

1. 代表实现：`Infrastructure/WowApi/*`、`CHAT_MSG_*` 映射链路。
2. 原因：
- 强平台绑定（Blizzard API、事件语义、ChatFrame 机制）。
- 抽成“通用框架”收益低，适配成本高。

### C2. Shelf/Kit 的游戏交互模型

1. 代表实现：`Domain/Shelf/*`、`Domain/Stream/Actions/StreamActionRegistry.lua`（readycheck、roll、leave 等）。
2. 原因：
- 操作语义是 WoW 专属动作，不具备跨域复用价值。

### C3. 本地化与素材资源组织

1. 代表实现：`Locales/*`、`Media/*`。
2. 原因：
- 更接近内容资产管理，不是框架能力。

---

## 推荐推进方式（结构化）

1. 主线：对 A 类做“对标式抽象”。
2. 辅线：对 B 类做“原则式抽象”，只复用架构思想，不追求 API 同构。
3. 保留：C 类继续留在 addon 业务层，不纳入框架化 KPI。

## 迁移优先级（按收益/风险）

1. `stream-core`（A1）
2. `settings-orchestrator-core`（A2）
3. `di-core`（A3）
4. `runtime-governor-core`（B1）
5. `registry-compiler-core`（B2）
6. `settings-schema-core`（B3）

## 非目标

1. 不追求“看起来像 Spring”而牺牲 Lua/WoW 适配性。
2. 不引入注解反射式模型。
3. 不在 C 类模块做通用框架化拆分。

## 统一判断标准（后续评审使用）

1. 若模块 70% 以上逻辑与 WoW API 强耦合，则归 C 类。
2. 若模块可在不改语义下脱离 WoW API 运行，则优先归 A 类。
3. 若仅能复用设计思想、无法复用接口形状，则归 B 类。
