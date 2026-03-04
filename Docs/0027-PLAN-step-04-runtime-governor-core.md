---
id: 0027
priority: P2
created: 2026-03-05
updated: 2026-03-05
relates: [#0023]
status: ACTIVE
---

# STEP 04：runtime-governor-core 抽离（不做向后兼容）

## 目标

1. 抽离 feature/capability/reconcile 为独立治理内核。
2. 将运行模式切换与特性启停关系标准化。
3. 保留 WoW 事件监听在 adapter，不进入 core。

## 约束

1. 不向后兼容：旧 feature 管理路径直接替换。
2. 逐步完成：只处理运行态治理。

## 独立分支策略

1. 分支名：`codex/step-04-runtime-governor-core`。
2. 必须基于已合入的 STEP 03 主干创建。
3. 本步不混入 registry/settings-schema 改造。

## Libs 落位可行性

1. 结论：可行，建议放入 `Libs/TinyCore/RuntimeGovernor/*`。
2. 理由：特性治理属于通用运行时控制平面。
3. 约束：
- 环境感知事件（`PLAYER_ENTERING_WORLD` 等）保留在 adapter。
- 防止 core 直接调用 WoW API。

## 范围

1. In Scope
- `Infrastructure/Runtime/FeatureRegistry.lua`
- `Infrastructure/Runtime/CapabilityPolicyEngine.lua`
- `Infrastructure/Runtime/RuntimeCoordinator.lua`

2. Out of Scope
- 具体业务 feature 的实现逻辑。

## 目标结构

1. `Libs/TinyCore/RuntimeGovernor/CapabilityMatrix.lua`
2. `Libs/TinyCore/RuntimeGovernor/FeatureRegistry.lua`
3. `Libs/TinyCore/RuntimeGovernor/Reconciler.lua`
4. `Infrastructure/WowApi/RuntimeModeWatcher.lua`

## 执行步骤

1. 标准化 capability 判定接口。
2. feature 注册对象统一字段（requires/plane/hooks）。
3. 将模式变化触发统一走 reconcile。
4. 删除旧管理入口。

## 交付件

1. runtime governor core。
2. mode -> capability 矩阵文档。
3. feature 启停时序图。

## 验收标准

1. 模式变化后 feature 状态可预测且可重演。
2. 未满足 capability 的 feature 必定禁用。
3. 旧入口调用为 0。

## 回滚策略

1. 整步回滚。
