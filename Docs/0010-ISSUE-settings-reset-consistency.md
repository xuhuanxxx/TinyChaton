---
id: 0010
priority: P1
created: 2026-03-03
updated: 2026-03-03
assignee: next-ai
relates: [#0009, #0008]
status: ACTIVE
---

# 设置重置一致性问题交接

## 问题/目标
当前“单页面重置”和“插件全局重置”在部分设置项上存在实现风格不一致，历史上已导致 MultiDropdown 项（如自动加入频道）出现重置后状态偏差。目标是统一重置链路，保证所有页面重置与全局重置都严格回到同一默认真相源。

## 内容

### 背景与现状
- 已完成：`Automation` 页重置已改为实时读取 `addon.DEFAULTS.profile.automation`，并显式回推 MultiDropdown 的默认选择，避免旧 UI 值回写覆盖默认值。
- 已完成：流默认行为已回归 `STREAM_REGISTRY` 显式 schema（`defaultPinned/defaultSnapshotted/defaultAutoJoin`），`DEFAULTS` 从注册表构建。
- 仍存在：其他页面（例如 Chat 页）仍使用 `SetValue(GetValue())` 的刷新模式，与 Automation 页的显式回推模式不一致。

### 关键风险
1. MultiDropdown 组件在页面重置场景下仍可能出现“UI 缓存态回写 DB”风险（取决于具体页面调用方式）。
2. 各页面重置逻辑分散且风格不统一，后续改动容易再次引入“单页重置与全局重置不一致”。
3. 缺少统一的重置后 UI 同步 helper，重复代码较多。

### 影响范围
- `Domain/Settings/Pages/Automation.lua`
- `Domain/Settings/Pages/Chat.lua`
- `Domain/Settings/SettingsControls.lua`
- 可能涉及其他使用 `AddProxyMultiDropdown` 的设置页

### 建议方案（给下一个 AI）
1. 在 `SettingsControls.lua` 增加统一 helper：
   - 输入：`setting` + `selectionTable`（或由 getter 获取）
   - 输出：安全刷新 UI，不让旧 UI 状态反向污染 DB
2. 将 `Automation` 与 `Chat` 页的 MultiDropdown 重置刷新统一改为该 helper。
3. 页面重置统一规范：
   - 先写 DB 默认值（来源必须是 `addon.DEFAULTS`）
   - 再调用统一 helper 刷新控件
   - 最后 `ApplyAllSettings()`
4. 对所有 `RegisterPageReset` 回调做一次审计，检查是否存在“从 UI 反写 DB”的潜在路径。

### 验收标准
1. 单页面重置与插件全局重置结果一致（至少覆盖以下场景）：
   - 自动加入动态频道（Automation）
   - 快照频道选择（Chat）
2. 任意重置操作后，重新打开设置页，UI 勾选状态与 DB 内容完全一致。
3. 不新增第二默认来源，默认值仅来自 `addon.DEFAULTS`（而 `DEFAULTS` 来源于注册表/配置构建链路）。
4. 内建测试补齐或更新，覆盖 MultiDropdown 重置一致性。

## 结论/下一步
本 issue 不是“默认值定义错误”，而是“重置实现与控件同步机制不统一”。下一步由下一个 AI 统一 MultiDropdown 的重置刷新机制，并完成跨页面一致性回归，防止同类问题再次出现。
