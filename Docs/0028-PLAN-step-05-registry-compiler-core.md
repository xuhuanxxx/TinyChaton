---
id: 0028
priority: P2
created: 2026-03-05
updated: 2026-03-05
relates: [#0023, #0012]
status: RESOLVED
---

# STEP 05：registry-compiler-core 抽离（不做向后兼容）

## 目标

1. 将声明式 registry 编译流程抽离为通用 core。
2. 固化 pass：schema -> normalize -> index -> validate -> freeze。
3. 运行期只读消费编译产物。

## 约束

1. 不向后兼容：旧编译路径删除。
2. 逐步完成：只处理 registry 编译，不改业务定义语义。

## 独立分支策略

1. 分支名：`codex/step-05-registry-compiler-core`。
2. 必须基于已合入的 STEP 04 主干创建。
3. 本步只提交 compiler 及其消费侧迁移。

## Libs 落位可行性

1. 结论：可行，建议放入 `Libs/TinyCore/RegistryCompiler/*`。
2. 理由：多 pass 编译器是机制层能力，与业务定义解耦。
3. 约束：
- stream/action 业务 schema 仍留在 `Domain/*`。
- core 仅处理 schema 契约，不包含 WoW 事件常量语义判断。

## 范围

1. In Scope
- `Infrastructure/Runtime/StreamRegistryCompiler.lua`
- `Domain/Stream/Registry/StreamRegistry.lua`
- `Domain/Stream/Actions/StreamActionRegistry.lua`（声明驱动部分）

2. Out of Scope
- Shelf 视觉/布局逻辑。

## 目标结构

1. `Libs/TinyCore/RegistryCompiler/Compiler.lua`
2. `Libs/TinyCore/RegistryCompiler/Passes/*`
3. `Libs/TinyCore/RegistryCompiler/Artifact.lua`

## 执行步骤

1. 抽离 pass 接口与执行器。
2. 把 stream/action schema 迁移到统一 compiler 输入。
3. 输出冻结 artifact 并替换消费侧读取逻辑。
4. 删除旧编译器实现。

## 交付件

1. 通用 compiler core。
2. pass 列表与输入输出契约。
3. 冻结 artifact 结构文档。

## 验收标准

1. 非法 schema 在编译期失败而非运行期失败。
2. 运行期无动态改写编译产物。
3. stream/action 消费侧全部走新 artifact。

## 回滚策略

1. 整步回滚。
