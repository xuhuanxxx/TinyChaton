---
id: 0008
priority: P0
created: 2026-03-02
updated: 2026-03-02
relates: [#0001, #0002, #0003, #0004, #0005, #0006, #0007]
status: ACTIVE
---

# TinyChaton 架构总览规格

## 问题/目标

提供 TinyChaton 完整架构的鸟瞰视图，说明核心模块间的依赖关系与数据流向。

## 架构分层

### 第 1 层：基础设施（Infrastructure）

#### 运行时策略（Runtime Policy）
- **CapabilityPolicyEngine** (#0001)：能力策略引擎，决定功能启停
- **ChatRuntimeMode**：运行时模式管理（ACTIVE/BYPASS）
- **FeatureRegistry**：功能注册表

**职责**：
- 提供能力判定接口 `addon:Can(capability)`
- 管理运行时模式切换
- 无业务逻辑，纯策略判定

#### WoW API 网关（WowApi Gateway）
- **ChatGateway** (#0004)：聊天数据网关（Inbound/Display/Outbound）
- **EnvironmentGate**：环境检测（Taint/Combat）
- **CVarSync**：CVar 同步

**职责**：
- 封装所有 WoW API 调用
- 提供防御性处理与能力检查
- 入口收口，禁止旁路

#### 核心工具（Runtime Utils）
- **Logger**：日志系统
- **Utils**：通用工具函数
- **ObjectPool**：对象池
- **Profiler**：性能分析

**职责**：
- 提供基础工具函数
- 性能优化基础设施
- 可观测性支持

### 第 2 层：领域注册表（Domain Registries）

#### 消息流注册表（Stream Registry）
- **StreamRegistry** (#0002)：消息流定义（CHANNEL/NOTICE）
- **ChannelCandidatesRegistry**：频道候选列表
- **ChannelSemanticResolver**：频道语义解析

**职责**：
- 定义所有频道/流的元数据
- 提供频道查询接口
- 事件到频道的映射

#### 动作注册表（Action Registry）
- **ActionRegistry** (#0003)：动作定义与反向绑定
- **ChannelIdentityResolver**：频道标识解析
- **NamePolicy**：命名策略

**职责**：
- 定义所有可执行动作
- 声明动作适用范围（反向绑定）
- 提供动作执行接口

#### Shelf 注册表（Shelf Registries）
- **ShelfKitRegistry**：工具包定义
- **ShelfColorRegistry**：颜色方案
- **ShelfThemeRegistry**：主题预设
- **ShelfAnchorRegistry**：锚点定义

**职责**：
- 定义 Shelf UI 元素元数据
- 提供主题与配置查询接口

### 第 3 层：核心服务（Domain Services）

#### 消息路由与处理（Chat Ingress）
- **EventRouter** (#0005)：事件路由器与中间件管道
- **EventContextFactory**：事件上下文工厂
- **Filters**：过滤器（Blacklist/Whitelist/Duplicate/RuleMatcher）

**职责**：
- 接收入站聊天事件
- 执行中间件管道（PRE_PROCESS/FILTER/ENRICH/LOG）
- 过滤与阻塞决策

#### 消息变换与显示（Chat Render）
- **MessageFormatter**：消息格式化
- **Transformers**：显示变换器（StripPrefix/CleanMessage/Emotes/Highlight/TimestampInteraction）
- **ChatFont**：字体管理
- **EmotesPanel**：表情面板

**职责**：
- 执行消息显示变换链
- 渲染前处理（高亮/表情/时间戳）
- 字体与样式管理

#### 消息持久化（Chat Storage）
- **SnapshotStore** (#0006)：快照存储与环形缓冲区
- **SnapshotReplayer**：快照回放
- **SnapshotKeys**：快照键管理

**职责**：
- 记录聊天历史到环形缓冲区
- 容量管理与修剪
- 回放历史消息

#### 自动化服务（Chat Automation）
- **AutoWelcome**：自动欢迎
- **AutoJoinHelper**：自动加入频道

**职责**：
- 自动化任务（欢迎消息/自动加入）
- 受能力策略约束（BYPASS 模式禁用）

#### 交互增强（Chat Interaction）
- **LinkHover**：链接悬停
- **StickyChannels**：粘性频道
- **TabCycle**：Tab 循环

**职责**：
- 增强聊天交互体验
- 不修改消息内容，只增强 UI 行为

#### Shelf 服务（Shelf Service）
- **ShelfService** (#0007)：按钮生成与布局逻辑
- **ShelfRender**：Shelf 渲染层
- **SelectionDialog**：选择器对话框

**职责**：
- 生成频道/Kit 按钮列表
- 动态频道匹配与缓存
- 主题属性查询

#### 设置服务（Settings Service）
- **SettingsService**：设置管理
- **SettingsSchema**：设置模式定义
- **SettingsControls**：控件工厂
- **Pages**：设置页面（General/Appearance/Filters/Buttons/Chat/Data/Automation/Profile）

**职责**：
- 配置管理与持久化
- 设置 UI 生成
- 配置迁移与校验

### 第 4 层：应用层（Application）

#### 引导与生命周期（Bootstrap）
- **Bootstrap**：启动入口
- **Lifecycle**：生命周期管理
- **Runtime**：运行时初始化
- **Modules**：模块加载
- **ContainerSetup**：依赖注入容器设置
- **Database**：数据库初始化

**职责**：
- 插件启动与关闭流程
- 模块初始化顺序管理
- 数据库迁移与规范化

#### 依赖注入（Dependency Injection）
- **Container**：DI 容器

**职责**：
- 管理模块依赖关系
- 延迟加载与单例管理

#### 事件总线（Events）
- **Events**：全局事件总线

**职责**：
- 模块间事件通信
- 解耦模块依赖

## 数据流

### 入站消息流（Inbound Message Flow）

```
WoW Chat Event
  ↓
ChatGateway.Inbound:Allow()  [能力检查]
  ↓
EventRouter.Dispatch()  [事件路由]
  ↓
Middleware Pipeline:
  1. PRE_PROCESS  [预处理]
  2. FILTER       [过滤决策] → 阻塞或放行
  3. ENRICH       [增强处理]
  4. LOG          [快照记录]
  ↓
ChatGateway.Display:Transform()  [显示变换]
  ↓
Transformer Chain:
  - StripPrefix
  - CleanMessage
  - Emotes
  - Highlight
  - TimestampInteraction
  ↓
WoW ChatFrame Display
```

### 出站消息流（Outbound Message Flow）

```
User Action (Shelf 按钮/命令)
  ↓
ActionRegistry.execute()  [动作执行]
  ↓
ChatGateway.Outbound:SendChat()  [能力检查]
  ↓
SendChatMessage()  [WoW API]
```

### Shelf 刷新流（Shelf Refresh Flow）

```
Trigger (配置变更/频道变化/手动刷新)
  ↓
ShelfService:RefreshShelf()
  ↓
Generate Buttons:
  1. StreamRegistry → 频道按钮
  2. KitRegistry → Kit 按钮
  3. ActionRegistry → 动作绑定
  4. User Config → Pin/Order/Bindings
  ↓
Sort & Filter
  ↓
ShelfRender:UpdateButtons()  [UI 渲染]
```

## 依赖关系图

```
[Infrastructure Layer]
  CapabilityPolicyEngine ← ChatRuntimeMode
  ChatGateway ← CapabilityPolicyEngine
  
[Registry Layer]
  StreamRegistry (独立)
  ActionRegistry ← StreamRegistry
  ShelfRegistries (独立)
  
[Service Layer]
  EventRouter ← ChatGateway + StreamRegistry
  SnapshotStore ← CapabilityPolicyEngine
  ShelfService ← StreamRegistry + ActionRegistry + ShelfRegistries
  SettingsService ← SettingsSchema
  
[Application Layer]
  Bootstrap ← All Services
  Container ← All Modules
```

## 关键约束

### 架构不变量（来自 AGENT.md）

1. **策略驱动**：功能启停由 CapabilityPolicyEngine 统一决定
2. **生命周期可逆**：所有服务可 enable/disable/teardown
3. **数据驱动**：频道/动作/Shelf 定义以注册表为真相源
4. **入口收口**：所有聊天数据必须经过 ChatGateway 三个入口之一
5. **启动规范化**：历史数据在 Bootstrap 阶段规范化

### 防御性处理

- 所有 Gateway 入口验证能力与数据类型
- 所有 Transformer/Middleware 使用 `pcall` 隔离错误
- 所有注册表查询返回 `nil` 而非抛出错误

### 性能约束

- 入站消息处理：< 5ms（Gateway + Middleware + Transformer）
- Shelf 刷新：< 10ms（数据层）
- 快照记录：< 1ms（单条消息）

## 验证标准

### 架构一致性

- [ ] 所有功能模块通过 `addon:Can()` 查询能力
- [ ] 所有频道定义在 `STREAM_REGISTRY` 中
- [ ] 所有动作定义在 `ACTION_REGISTRY` 中
- [ ] 所有聊天消息通过 `ChatGateway` 处理

### 模块解耦

- [ ] Registry 层无业务逻辑依赖
- [ ] Service 层不直接调用 WoW API（通过 Gateway）
- [ ] Infrastructure 层无领域概念

### 生命周期

- [ ] 所有 Service 可独立 enable/disable
- [ ] 禁用后无残留副作用（事件注销/Hook 恢复）
- [ ] 重新启用后功能完整恢复

## 结论/下一步

本规格提供了 TinyChaton 的完整架构视图。各模块详细规格见关联的 SPEC 文档。

待完善文档：
- [ ] #0009 数据库迁移与规范化规格
- [ ] #0010 设置系统规格
- [ ] #0011 过滤器规格
- [ ] #0012 变换器规格
- [ ] #0013 自动化服务规格
