---
id: 0029
priority: P2
created: 2026-03-05
updated: 2026-03-05
relates: [#0023]
status: COMPLETED
---

# STEP 06：settings-schema-core 抽离（不做向后兼容）

## 目标

1. 抽离 settings schema、验证、控件映射为 core。
2. WoW `Settings.*` 仅作为 renderer adapter。
3. 设置变更统一桥接到 orchestrator commit。

## 约束

1. 不向后兼容：旧控件工厂路径直接替换。
2. 逐步完成：仅处理 settings schema 与 UI factory。

## 独立分支策略

1. 分支名：`codex/step-06-settings-schema-core`。
2. 必须基于已合入的 STEP 05 主干创建。
3. 本步仅提交 schema-core 与 renderer 适配。

## Libs 落位可行性

1. 结论：部分可行。
2. 放入 `Libs/TinyCore/SettingsSchema/*` 的部分：schema registry、validator、model。
3. 保留在 `Domain/Settings/*` 的部分：WoW `Settings.*` renderer 与页面接线。
4. 原因：核心验证逻辑可复用，UI 渲染强依赖 WoW 生命周期。

## 范围

1. In Scope
- `Domain/Settings/SettingsService.lua`
- `Domain/Settings/SettingsControls.lua`
- `Domain/Settings/Pages/*`（schema 声明部分）

2. Out of Scope
- 文案与本地化资源调整。

## 目标结构

1. `Libs/TinyCore/SettingsSchema/SchemaRegistry.lua`
2. `Libs/TinyCore/SettingsSchema/Validator.lua`
3. `Libs/TinyCore/SettingsSchema/ControlModel.lua`
4. `Domain/Settings/SettingsRenderer.lua`

## 执行步骤

1. 定义 schema 元模型（type/default/validator/ui/scope）。
2. 抽离 Validate/Export/Reset 的核心逻辑。
3. 页面层改为声明 schema，renderer 负责落地 UI。
4. 删除旧控件工厂实现。

## 交付件

1. settings schema core。
2. 页面 schema 清单。
3. renderer 对接与 commit 桥接说明。

## 验收标准

1. 设置校验逻辑可脱离 WoW API 单独运行。
2. 控件创建由 schema 驱动，不再散落自定义流程。
3. 变更提交统一触发 orchestrator。

## 回滚策略

1. 整步回滚。
