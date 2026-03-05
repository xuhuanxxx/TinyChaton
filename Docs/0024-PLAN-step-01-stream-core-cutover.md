---
id: 0024
priority: P1
created: 2026-03-05
updated: 2026-03-05
relates: [#0023, #0017, #0018]
status: RESOLVED
---

# STEP 01：stream-core 抽离与切换（不做向后兼容）

## 目标

1. 将消息处理主链路抽为 `stream-core`：pipeline + rule + formatter + highlighter 插件协议。
2. 旧入口直接替换，不保留 alias/桥接层。
3. 本步完成后，WoW 相关逻辑仅存在于 adapter 层。

## 约束

1. 不向后兼容：删除旧调用路径，不双写。
2. 逐步完成：仅处理 stream 相关链路，不触及 settings/di 主体。
3. 本文仅定义本步改造。

## 独立分支策略

1. 分支名：`codex/step-01-stream-core-cutover`。
2. 本步所有代码与文档只在该分支实现。
3. 合入后再开启下一步分支，不并行混改。

## Libs 落位可行性

1. 结论：可行，建议放入 `Libs/TinyCore/Stream/*`。
2. 理由：`stream-core` 属于通用机制层，适合与 `Libs/TinyReactor` 同级管理。
3. 约束：
- WoW API 依赖保留在 `Domain/` 或 `Infrastructure/WowApi/` adapter。
- `TinyChaton.toc` 需提前加载 `Libs/TinyCore/Stream/*`。

## 范围

1. In Scope
- `Domain/Stream/Ingress/StreamEventDispatcher.lua`
- `Domain/Stream/Rules/*`
- `Domain/Stream/Render/*`
- `Infrastructure/WowApi/ChatGateway.lua`（仅 adapter 对接）

2. Out of Scope
- Settings 页面和 Orchestrator 行为调整。
- Shelf/Kit 业务动作语义。

## 目标结构

1. `Libs/TinyCore/Stream/Pipeline.lua`
2. `Libs/TinyCore/Stream/RuleEngine.lua`
3. `Libs/TinyCore/Stream/RenderEngine.lua`
4. `Infrastructure/WowApi/StreamTransportAdapter.lua`

## 执行步骤

1. 定义 core 契约：`context`、`stage`、`plugin`、`decision`。
2. 把 Dispatcher 的阶段执行迁移到 `Pipeline`。
3. 把 `RegisterKindStrategy/RegisterKindFormatter/RegisterKindHighlighter` 统一到 core 注册器。
4. Adapter 对接 ChatFrame 过滤器与显示变换。
5. 删除旧主流程调用点。

## 交付件

1. core 模块代码与最小 README。
2. WoW adapter 对接层。
3. 迁移后的调用路径图。

## 验收标准

1. 新增 kind 插件无需修改 pipeline 主流程。
2. 运行时仍能完成：过滤、转换、渲染、高亮、持久化。
3. 旧入口不再被引用（`rg` 验证）。

## 回滚策略

1. 仅允许“整步回滚”（回退整个 STEP 01 提交）。
2. 不提供运行时开关回退。
