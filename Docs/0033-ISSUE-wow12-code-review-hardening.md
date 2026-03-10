---
id: 0033
priority: P0
created: 2026-03-10
updated: 2026-03-10
assignee: 
relates: [#0001, #0008, #0009, #0021, #0032]
status: ACTIVE
---

# ISSUE: WoW 12.0 全量代码审查（架构/安全/性能/兼容）

## 问题/目标
本审查针对 TinyChaton 当前代码基线执行一次“上线前”级别的严格 code review，重点覆盖：唯一真源、双链路、12.0 API 风险、战斗保护边界、性能与维护成本。输出要求是可落地的整改路径，不是泛化建议。

## 内容

### 总评（四问）
1. **核心架构是否健康**：**中等偏弱（可运行，但历史包袱明显）**。Stream 主链路有“统一网关 + middleware + delivery”的方向，但运行时事件系统、设置提交系统、聊天 UI 交互层仍存在多套入口并存，架构不变量被局部破坏。
2. **唯一真源是否建立**：**部分建立，未闭环**。`STREAM_REGISTRY` 与 Settings Schema 在“定义层”相对统一；但运行时状态（事件分发状态、频道切换状态、自动化计时状态、snapshot lineCount）仍有多点维护与隐式副本。
3. **最需要立刻处理的前三个问题**：
   - **P0**：`TabCycle` 在无 combat 保护判断下直接 `SetAttribute` 修改聊天输入框属性，属于战斗安全高风险路径。
   - **P0**：存在两套并行事件系统（`RegisterEvent` vs `RegisterCallback`）和多 Frame 自建监听，导致同一语义多入口、可观测性差、生命周期不可逆。
   - **P1**：`Snapshot` 计数与存储双写（`lineCount` + ring buffer 实际值）+ 异步清理 ticker，存在一致性漂移与高压场景抖动风险。
4. **最大长期维护成本来源**：**“双链路 + 过度抽象并存”**（DI/Orchestrator/Feature plane 的抽象层本身不坏，但与历史直连/旁路代码并存，形成“看似统一，实际多中心”）。

---

### 问题清单（按严重级别排序）

| 严重级别 | 问题标题 | 所在文件和函数 | 问题现象 | 根因 | 影响范围 | 建议修复方案 | 立即修改 |
|---|---|---|---|---|---|---|---|
| P0 | 战斗中修改聊天输入框属性的受保护风险 | `Domain/Chat/Interaction/TabCycle.lua` `OnTabPressed` | 直接 `SetAttribute("chatType"/"channelTarget")` + `ChatEdit_UpdateHeader`，无 `InCombatLockdown` 与 secure 边界兜底 | 交互功能实现假设“编辑框可随时改属性” | 进战斗时可能 taint、静默失效或污染后续输入框行为 | 增加 combat gate：战斗中仅更新“待切换意图”，离战后统一 apply；并封装为 `ChatEditChannelService:SetTarget(editBox, target)` 单入口 | 是 |
| P0 | 事件系统双轨并行，唯一入口被破坏 | `App/Events.lua`、`App/Bootstrap/Runtime.lua`、`Infrastructure/Runtime/RuntimeCoordinator.lua`、`Domain/Chat/Automation/AutoWelcome.lua` | 同时存在 `RegisterEvent`(WoW Frame) 与 `RegisterCallback`(addon bus)，且多个模块自建 Frame 监听 | 历史迁移未收口到统一 Event Gateway | 订阅关系不可追踪、卸载不可逆、重复触发/漏触发难排查 | 统一成“WoW Event -> addon callback bus”单向桥；业务模块禁新建事件 Frame（除 secure 必要例外） | 是 |
| P1 | Snapshot 存储计数双写，存在一致性漂移 | `Domain/Stream/Storage/SnapshotStore.lua`、`Domain/Stream/Storage/SnapshotReplayer.lua` | `lineCount` 缓存与 ring buffer 实际长度并行维护；清理/trim/replay 多处更新计数 | 为性能做缓存，但缺乏强一致模型 | 历史回放上限、清理停止条件、UI 显示可能不一致 | 建立单一真源：只以 ring buffer 真实值为准；`lineCount` 改为按需缓存并附版本戳 | 是 |
| P1 | 自动欢迎状态表潜在无界增长 | `Domain/Chat/Automation/AutoWelcome.lua` `state.lastSentAtByKey` | key 为 `scene:name`，长期运行可累计大量历史玩家名，无淘汰策略 | 仅新增不清理 | 长时间团本/公会环境内存常驻增长 | 增加 TTL/LRU（例如仅保留近 N 条或近 X 小时） | 是 |
| P1 | 自动欢迎基于系统文本模板匹配，跨语种/补丁文案脆弱 | `Domain/Chat/Automation/AutoWelcome.lua` `getSceneFormatString/buildPattern/getJoinedPlayer` | 依赖 `ERR_*` 字符串模板解析玩家名；文案变化将失效 | 使用“消息文本反解析”替代结构化事件 | 功能在不同 locale 或后续补丁出现误判/漏判 | 优先改为结构化事件（可用时）；保留文本匹配作为降级路径并加 telemetry | 否（短期可观测后改） |
| P1 | Hook 不可逆功能依赖运行时 if 早退，Disable 语义不完整 | `Domain/Chat/Interaction/LinkHover.lua`、`Domain/Chat/Interaction/TabCycle.lua`、`Infrastructure/WowApi/ChatLinkRouter.lua` | `HookScript/hooksecurefunc` 后无法解除，`onDisable` 基本空实现 | 生命周期可逆约束未完全贯彻 | Feature toggling 一致性下降，调试困难 | 显式记录“不可逆 hook 白名单”；统一在回调首行 capability+feature gate，且提供诊断状态 | 否 |
| P2 | SetCVar 写入路径分散，系统状态与配置层边界模糊 | `Domain/Settings/SettingsSchema.lua`、`Infrastructure/WowApi/CVarSync.lua` | timestamp 同时由设置项和 middleware 监听管理，语义重叠 | 缺少系统 CVar 统一 adapter | 时间戳行为在外部改动时可见性差 | 引入 `SystemCVarService` 统一读写/监听/回滚 | 否 |
| P2 | `ExecuteSettingsIntent` 调用形态混用（对象 vs 参数） | 多处调用，定义在 `Domain/Settings/SettingsOrchestrator.lua` | 既支持 table intent 又支持 `(reason, scope, source)` | 兼容层长期保留 | 新代码易继续复制旧风格，增加认知成本 | 确立唯一签名（table intent），旧签名打日志后移除 | 否 |
| P2 | 高频 ticker 清理策略在高压场景有抖动窗口 | `Domain/Stream/Storage/SnapshotReplayer.lua` `TriggerEviction/PerformEvictionBatch` | `0.05s` ticker 每批 50 条，多流并发下持续运行 | 采用固定频率而非预算驱动 | 大秘境/团本高聊天流量下 CPU 峰值波动 | 改为 budget 模式：按 `debugprofilestop` 控制每帧耗时上限 | 否 |
| P3 | 反射式全局 API 访问降低可读性并增审计难度 | 例如 `local CF = _G["Create".."Frame"]` | 混淆式访问并非必要 | 历史规避/风格遗留 | 安全审计与静态检查成本上升 | 统一直接局部绑定：`local CreateFrame = CreateFrame` | 否 |
| P3 | “高疑似”12.0 兼容风险：频道加入仍走全局旧接口 | `Domain/Chat/Automation/AutoJoinHelper.lua` `JoinChannelByName` | 继续可跑，但 12.0 后推荐路径可能偏向 `C_ChatInfo` 族接口 | 旧接口兼容层未统一 | 未来补丁可能继续叠加分支 | 增加 `ChatChannelApiAdapter`：优先新 API，保留回退 | 否（高疑似） |

---

### 架构重构建议（明确收口，不泛谈）

#### 1) 模块合并与边界收口
- **合并建议 A（事件层）**
  - 合并目标：`App/Events.lua` + `RuntimeCoordinator`/`AutoWelcome` 等自建 Frame 监听入口。
  - 设计：建立 `Infrastructure/WowApi/EventGateway.lua` 作为唯一 WoW 事件订阅点。
  - 约束：业务模块只允许 `addon:RegisterCallback`，不允许直接 `CreateFrame():RegisterEvent`。
- **合并建议 B（聊天交互层）**
  - 合并 `TabCycle`、`StickyChannels`、`LinkHover` 的“编辑框 hook 生命周期管理”。
  - 建立 `ChatEditHookService`，统一负责 Hook 幂等、feature gate、combat gate。

#### 2) 唯一真源收口
- **状态：snapshot 计数**
  - 当前数据流：`ringBuffer.size` -> 多处 `SetSnapshotLineCount/Adjust`（并行维护）。
  - 建议数据流：`ringBuffer.size`（唯一真源）-> `GetSnapshotLineCount()`按版本缓存（只读派生）。
- **状态：聊天目标频道（TabCycle）**
  - 当前：editBox attribute 直接写 + UI header 直接刷。
  - 建议：`ChatEditChannelState`（单点状态）-> 非战斗 apply 到 editBox（派生视图）。

#### 3) 删除双链路
- 删除 `ExecuteSettingsIntent(reason, scope, source)` 旧签名路径（或至少禁止新调用）。
- 删除“模块内部自建 Event Frame”模式，统一经过 EventGateway。
- 删除 snapshot 计数双写 API（保留读接口，写接口内部私有化）。

#### 4) 统一 API 封装
- 新建 `Infrastructure/WowApi/ChatApiAdapter.lua`
  - 封装 `SendChatMessage`、频道加入/查询、CVar 读写。
  - 所有 Domain 层只调 adapter，不直接触达全局 API。
- 新建 `Infrastructure/WowApi/CombatGuard.lua`
  - 提供 `RunNowOrDeferUntilOutOfCombat(fn, key)`。

---

### 12.0 API 与战斗安全专项检查

#### A. API 风险清单
| 旧调用位置 | 风险类型 | 12.0 影响 | 建议替代 | 迁移优先级 |
|---|---|---|---|---|
| `AutoJoinHelper.lua` 使用 `_G.JoinChannelByName` | 高疑似旧接口依赖 | 继续可跑但未来语义/权限可能收紧 | `ChatChannelApiAdapter` 优先 `C_ChatInfo` 路径，失败回退 | P2 |
| `SettingsSchema.lua` 直接 `C_CVar.SetCVar` | 系统配置写入分散 | 插件与系统设置交互边界更需可控 | 统一 `SystemCVarService` + 来源标记 | P2 |
| `TabCycle.lua` 直接 `SetAttribute` | 受保护对象/taint 风险 | 安全边界更严格，战斗中行为更敏感 | combat defer + 单点 apply 服务 | P0 |

#### B. protected / taint / combat lockdown 高风险项
1. `TabCycle` 在输入框上直接写 attribute 且无 combat 保护（P0）。
2. `HookScript` / `hooksecurefunc` 不可逆，若回调内遗漏 capability gate，容易在战斗态触发意外路径（当前多数有 guard，但治理方式分散）。
3. `AutoWelcome`/`AutoJoin` 自动化动作应严格受 CapabilityPolicy 与用户显式开关约束（当前具备，但建议统一通过 `ChatApiAdapter + PolicyAuditLog` 增强审计）。

---

### 性能专项检查

#### CPU
1. **Snapshot 清理 ticker 固定 20Hz**
   - 触发条件：`lineCount > max`。
   - 最坏场景：团本/大秘境高频聊天 + 多 stream 并发积压。
   - 风险：持续小批次清理造成帧间抖动。
2. **ChatBubble 扫描递归 + ticker**
   - 触发条件：启用 emote bubble 渲染。
   - 最坏场景：主城大量泡泡/密集喊话，递归 `FindFontString` 多次执行。
   - 风险：CPU 热点在 UI 树遍历。
3. **多事件系统并行回调**
   - 触发条件：运行时模式切换/登录阶段。
   - 最坏场景：重复 reconcile 与重复 event 分发。
   - 风险：不必要的回调链成本和调试开销。

#### 内存
1. **常驻增长：`AutoWelcome.lastSentAtByKey` 无淘汰**（长期在线累积）。
2. **瞬时分配：Snapshot trim/replay 构建临时 heap/states**（高流量恢复时 GC 峰值）。
3. **不可逆 hook + 闭包常驻**（可接受但需集中登记，防“功能关了但闭包仍活跃”的误判）。

---

### Secret 与敏感值检查
- 未发现硬编码 token/apiKey/password/webhook。
- 发现的“敏感暴露面”主要是**调试开关/命令入口**：
  - `SLASH_TINYCHATON_LINKDEBUG` 可在聊天打开链路调试（非秘密，但建议仅 dev 模式启用或加权限提示）。
- SavedVariables 中 snapshot/chat 内容属于**用户数据**，应在文档中明确“可能包含私人聊天文本”的导出风险。

---

### 附加检查清单结论
- 事件注册与注销：存在自建 Frame 监听，不完全纳入统一注销路径（需收口）。
- Ace3：未使用 Ace3，无规范性问题。
- SavedVariables 与运行时状态混用：Snapshot 有混用倾向（`lineCount` 与运行时逻辑耦合）。
- 全局命名空间泄漏：存在 slash 命令全局常量（可接受），未见明显意外全局变量爆出。
- Hook/SecureHook/RawHook：`hooksecurefunc` 仅见 `SetItemRef`，风险可控但不可逆。
- tooltip/nameplate/aura 扫描：主要是 chat bubble 扫描，需关注主城场景成本。
- 装备/饰品/法术/天赋缓存：本插件不属核心路径，未见高风险。
- 版本分支膨胀：高疑似点在频道 API 兼容层尚未统一，未来补丁可能继续加分支。

---

### 最小改动方案（优先级）
1. **P0（当天可做）**：给 `TabCycle` 增加 combat defer（进战不写 attribute，离战一次性 apply）。
2. **P0（1~2 天）**：新增 EventGateway，禁止新增业务层 `CreateFrame:RegisterEvent`，先迁移 `AutoWelcome`、`RuntimeCoordinator`。
3. **P1（1~2 天）**：`AutoWelcome.lastSentAtByKey` 增加 TTL 清理（例如每 30 分钟清理 6 小时前条目）。
4. **P1（2~3 天）**：Snapshot `lineCount` 改为只读缓存，删除外部写接口调用点。
5. **P2（并行）**：抽 `ChatApiAdapter` 收口 `JoinChannel/SendChatMessage/CVar`，补 12.0 兼容策略。

## 结论/下一步
- 本审查确认：项目可用，但“统一架构目标”尚未真正闭环，当前最大风险来自双链路和战斗安全边界。优先按最小改动方案完成 P0/P1，即可显著降低线上不确定性与后续维护成本。
- 待验证事项：
  1. `TabCycle` 在战斗态的实际 taint 复现日志（建议加最小化诊断）。
  2. 频道 API 在 12.0 环境下 `JoinChannelByName` 与 `C_ChatInfo` 路径表现对比。
