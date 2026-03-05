---
id: 0026
priority: P1
created: 2026-03-05
updated: 2026-03-05
relates: [#0023, #0022]
status: RESOLVED
---

# STEP 03：di-core 单轨切换（不做向后兼容）

## 目标

1. 形成唯一 DI 入口：容器解析。
2. 删除 `addon.XXX` 作为服务注入通道的模式。
3. 启动期完成依赖图 fail-fast 校验。

## 约束

1. 不向后兼容：不保留双轨模式。
2. 逐步完成：只收敛依赖获取方式，不改业务语义。

## 独立分支策略

1. 分支名：`codex/step-03-di-core-cutover`。
2. 必须基于已合入的 STEP 02 主干创建。
3. 本步只提交 DI 改造与必要适配。

## Libs 落位可行性

1. 结论：可行，建议放入 `Libs/TinyCore/DI/*`。
2. 理由：容器属于基础设施级能力，独立于业务域。
3. 约束：
- `App/Bootstrap/ContainerSetup.lua` 作为装配入口保留在 App 层。
- `TinyChaton.toc` 确保 DI core 先加载。

## 范围

1. In Scope
- `App/DI/Container.lua`
- `App/Container.lua`
- 各业务模块的依赖获取语句

2. Out of Scope
- 新增高级 DI 特性（注解、AOP、自动扫描）。

## 目标结构

1. `Libs/TinyCore/DI/Container.lua`
2. `Libs/TinyCore/DI/Validation.lua`
3. `App/Bootstrap/ContainerSetup.lua`（仅装配）

## 执行步骤

1. 完成容器 API 冻结：register/resolve/has/tryResolve/freeze。
2. 迁移业务依赖读取到 `ResolveRequiredService/ResolveOptionalService`。
3. 新增启动校验：未注册、循环依赖、工厂异常。
4. 删除双轨注入残留。

## 交付件

1. 单轨 DI 实现与装配代码。
2. 依赖图校验日志输出。
3. 迁移清单（模块 -> 服务名）。

## 验收标准

1. 业务层不再新增 `addon.XXX` 注入读取。
2. 缺服务在启动期明确失败。
3. 容器冻结后禁止新增注册。

## 回滚策略

1. 整步回滚，不做双轨重开。
