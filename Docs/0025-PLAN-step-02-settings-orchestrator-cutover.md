---
id: 0025
priority: P1
created: 2026-03-05
updated: 2026-03-05
relates: [#0023, #0022]
status: COMPLETED
---

# STEP 02：settings-orchestrator-core 切换（不做向后兼容）

## 目标

1. 固化 `CommitSettings -> Orchestrator` 为唯一入口。
2. 所有 settings 应用动作通过 subscriber 编排执行。
3. 移除中心化直调链路（不保留旧名或兼容壳）。

## 约束

1. 不向后兼容：删除旧入口与旧调用。
2. 逐步完成：仅处理 settings 编排，不改 stream 规则。

## 独立分支策略

1. 分支名：`codex/step-02-settings-orchestrator-cutover`。
2. 必须基于已合入的 STEP 01 主干创建。
3. 不与后续步骤混合提交。

## Libs 落位可行性

1. 结论：可行，建议放入 `Libs/TinyCore/SettingsOrchestrator/*`。
2. 理由：phase/priority 编排器是跨模块机制层。
3. 约束：
- 页面触发与 WoW `Settings.*` API 保留在 `Domain/Settings/*` adapter。
- `TinyChaton.toc` 加载顺序需保证 core 先于 subscriber 注册代码。

## 范围

1. In Scope
- `Domain/Settings/SettingsOrchestrator.lua`
- `Domain/Settings/SettingsSubscriberRegistry.lua`
- 所有 `RegisterSettingsSubscriber` 调用模块

2. Out of Scope
- Settings UI 样式/布局。
- Profile 数据模型重构。

## 目标结构

1. `Libs/TinyCore/SettingsOrchestrator/Orchestrator.lua`
2. `Libs/TinyCore/SettingsOrchestrator/SubscriberRegistry.lua`
3. `Libs/TinyCore/SettingsOrchestrator/CommitContext.lua`
4. `Domain/Settings/SettingsCommitBridge.lua`

## 执行步骤

1. 抽离 phase/priority/sort/validate 逻辑到 core。
2. 将现有 subscriber 全量迁移到统一契约。
3. 所有 settings 变更触发统一改到 `CommitSettings`。
4. 删除旧串行 apply 调用路径。

## 交付件

1. orchestrator core 模块。
2. subscriber 清单（key/phase/priority）。
3. 迁移后触发点矩阵（页面、reset、profile、runtime 触发）。

## 验收标准

1. `CommitSettings` 是唯一设置提交入口。
2. 顺序仅由 phase+priority 决定。
3. 缺失/重复 subscriber key 启动即报错。

## 回滚策略

1. 整步回滚，不保留运行时 fallback。
