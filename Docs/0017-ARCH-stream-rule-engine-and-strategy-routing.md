---
id: 0017
priority: P0
created: 2026-03-05
updated: 2026-03-05
relates: [#0014, #0015]
status: ACTIVE
---

# Stream Rule Engine 与策略路由

## 目标

建立真正的 kind 可扩展规则执行框架，替代旧 `addon.Filters.*` 直连调用。

## 组件

1. `StreamRuleEngine`
- `RegisterKindStrategy(kind, strategy)`
- `EvaluateRealtime(streamContext)`
- `EvaluateSnapshot(lineContext)`
- `ClearAllCaches(reason)`

2. `StreamRuleMatcher`
- `GetRuleCache(namespace, config, version)`
- 命名空间缓存（不再写死 blacklist/whitelist）

3. 默认策略
- `ChannelRulesStrategy`：black/white/duplicate
- `NoticeRulesStrategy`：no-op

## 决策对象

`decision` 结构：
- `blocked: boolean`
- `reasons: table<string>`
- `metadataPatch: table`

## 集成关系

1. Dispatcher 构建 `streamContext`。
2. Visibility 调用 RuleEngine 得到规则决策。
3. Visibility 再执行 `streamBlocked` 终判。

## 扩展方式

新增 kind 规则只需要：
1. 实现 strategy（`EvaluateRealtime/EvaluateSnapshot`）。
2. 调用 `RegisterKindStrategy(newKind, strategy)`。

无需修改：Dispatcher、Visibility、Settings、Storage 主流程。
