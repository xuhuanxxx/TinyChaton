---
id: 0022
priority: P2
created: 2026-03-05
updated: 2026-03-05
assignee:
relates: [#0008, #0021]
status: ACTIVE
---

# DI 单轨化与 Settings 编排重构路线

## 问题/目标

将以下两项“大改”从审计修复中拆分，独立管理与执行：
1. DI 双轨并存（`ServiceContainer` + `addon.XXX`）导致依赖路径不唯一。
2. `ApplyAllSettings` 中心化编排与模块耦合度过高，缺少事件驱动边界。

目标是形成单一执行路径、可验证迁移步骤和清晰验收标准。
本方案按“可破坏、无兼容包袱、允许大规模重构、优雅优先”执行。

## 范围

### In Scope

1. DI 依赖解析入口收敛（选型并执行单轨策略）。
2. Settings 应用链路改为事件驱动编排（替代巨型串行调用）。
3. 对应回归测试与迁移文档。

### Out of Scope

1. 业务规则改动（过滤策略、快照语义、频道规则本身）。
2. UI 样式与交互视觉调整。
3. 非关键性能微优化（由其他文档追踪）。

## 决策 A（已拍板）：DI 走单轨容器化

1. 采用原“方案 A”：保留并扩展 DI 容器。
2. 业务模块禁止直接读取 `addon.XXX` 作为依赖注入手段。
3. 删除双轨兼容层，不保留过渡壳。
4. Bootstrap 在启动期执行依赖图校验：缺失、循环、未注册依赖均 fail-fast。

## 决策 B（已拍板）：Settings 走编排器，不走中心串行调用

1. 引入 `SettingsOrchestrator` 作为唯一编排入口。
2. 订阅者必须显式声明阶段与优先级，不依赖注册先后顺序。
3. 禁止在 `ApplyAllSettings` 内直接调业务模块方法（该方法将删除）。

## 命名决策（ApplyAllSettings 是否重命名）

结论：**需要重命名，且是强制项**。

1. 删除旧名 `ApplyAllSettings`，避免继续表达“巨型全量串行应用”的旧语义。
2. 新入口统一为：
   - `addon:CommitSettings(reason, scope)`（应用层 API）
   - `SettingsOrchestrator:Run(ctx)`（编排层 API）
3. 如有历史调用点，直接替换；不保留 alias。

## 目标架构

1. `addon:CommitSettings(reason, scope)` 只负责构建上下文并调用 orchestrator。
2. `SettingsOrchestrator` 负责：
   - 阶段调度（示例：`core -> chat -> shelf -> ui`）
   - 优先级排序（数值越小越先执行）
   - 失败策略（默认 fail-fast，并记录 subscriber key）
3. 各子系统实现 `SettingsSubscriber` 契约：
   - `key`、`phase`、`priority`、`apply(ctx)` 必填
4. 事件仅作为观测与扩展点，不承担顺序控制：
   - `SETTINGS_COMMITTING(ctx)`
   - `SETTINGS_PHASE_COMMITTING(phase, ctx)`
   - `SETTINGS_PHASE_COMMITTED(phase, ctx)`
   - `SETTINGS_COMMITTED(ctx)`

## 执行计划（破坏式 Cutover，无双写）

### M1：编排基础设施（Day 1-2）

1. 新建 `SettingsOrchestrator` 与 `SettingsSubscriberRegistry`。
2. 为 `RegisterCallback/FireEvent` 补充阶段事件与上下文透传。
3. 新增启动期断言：
   - 所有 subscriber 的 `phase` 合法
   - 同 key 不重复注册
   - phase+priority 排序稳定

交付件：
1. 编排器实现 + 单测。
2. 架构图（phase 与关键 subscriber）。

### M2：DI 全量收敛（Day 3-4）

1. 扩展容器注册覆盖核心服务（Settings、Stream、Shelf、Automation 等）。
2. 业务模块改为依赖注入获取服务实例。
3. 删除/禁止新增 `addon.XXX` 依赖读取模式（除 pure utility 常量）。
4. 启动阶段执行容器依赖图校验。

交付件：
1. `ServiceContainer` 成为唯一依赖入口。
2. DI 验证测试。

### M3：Settings 订阅迁移（Day 5-7）

1. 首批迁移：字体、过滤、自动加入、欢迎词、货架。
2. 将 Settings 页面、Reset、Profile 切换、Snapshot 相关触发点统一改为 `addon:CommitSettings(...)`。
3. 删除 `ApplyAllSettings` 定义与全部调用点。

交付件：
1. `rg "ApplyAllSettings\\("` 结果为 0。
2. 关键场景回归通过。

### M4：清理与封板（Day 8）

1. 删除双轨残留代码与文档。
2. 更新 `#0008` 总览、`#0021` 审计状态、迁移说明。
3. 执行全量回归并冻结接口。

## 实施里程碑

1. M1：编排基础设施完成并可运行。
2. M2：DI 单轨落地，启动期依赖图可验证。
3. M3：核心 settings subscriber 完成，删除 `ApplyAllSettings`。
4. M4：文档与测试收口，接口冻结。

## 验收标准

1. DI：核心能力只有容器一种获取路径。
2. Settings：`ApplyAllSettings` 不存在；`CommitSettings` 为唯一入口。
3. 编排：顺序由 `phase + priority` 决定，不依赖注册顺序。
4. 回归：设置变更、profile 切换、reset 场景行为一致。
5. 故障：缺依赖/订阅冲突/阶段非法均明确报错，不允许静默跳过。
6. 静态检查：
   - `rg "ApplyAllSettings\\("` = 0
   - `rg "ResolveRequiredService\\("` 在业务层有实际使用
   - `rg "addon\\.[A-Z].*="` 不作为服务注入手段新增

## 风险与控制

1. 风险：订阅顺序冲突。  
   - 控制：phase+priority 校验、冲突测试、可视化执行日志。

2. 风险：大改引入启动时序问题。  
   - 控制：Bootstrap 断言 + fail-fast，不做静默降级。

3. 风险：迁移范围大导致一次性回归压力高。  
   - 控制：按 M1-M4 切分提交，但不保留运行时双轨。

## 下一步

1. 立即开始 M1：先落编排器和 subscriber 契约。
2. 同步创建迁移任务单（按模块切分，按 M1-M4 验收）。
