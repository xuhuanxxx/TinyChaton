---
id: 0030
priority: P1
created: 2026-03-05
updated: 2026-03-05
relates: [#0024, #0025, #0026, #0027, #0028, #0029]
status: COMPLETED
---

# 分支与 Libs 落位基线（适用于 STEP 01-06）

## 分支基线

1. 每一步独立分支实现，禁止在同一分支跨步开发。
2. 分支顺序与命名固定：
- `codex/step-01-stream-core-cutover`
- `codex/step-02-settings-orchestrator-cutover`
- `codex/step-03-di-core-cutover`
- `codex/step-04-runtime-governor-core`
- `codex/step-05-registry-compiler-core`
- `codex/step-06-settings-schema-core`
3. 下一步分支必须从“上一步已合入主干”的最新提交创建。

## Libs 落位基线

1. 新增统一机制层目录：`Libs/TinyCore/`。
2. 子目录规划：
- `Libs/TinyCore/Stream/`
- `Libs/TinyCore/SettingsOrchestrator/`
- `Libs/TinyCore/DI/`
- `Libs/TinyCore/RuntimeGovernor/`
- `Libs/TinyCore/RegistryCompiler/`
- `Libs/TinyCore/SettingsSchema/`
3. 强 WoW 依赖代码不得进入 `Libs/TinyCore/*`，应保留在 `Domain/*` 或 `Infrastructure/WowApi/*` adapter。

## TOC 加载顺序规则

1. `TinyChaton.toc` 中 `Libs/TinyCore/*` 必须早于 `Infrastructure/*`、`App/*`、`Domain/*` 消费方。
2. 每个 STEP 合入时同步更新 TOC，禁止“代码已迁移但 TOC 未接线”。
3. 未接入 TOC 的 core 文件视为未完成交付。

## 非目标

1. 不引入外部依赖管理器。
2. 不把现有 `Libs` 目录改造成第三方 vendor 语义。
3. 不在本基线文档内定义业务行为变化。
