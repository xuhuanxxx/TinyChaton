---
id: 0032
priority: P0
created: 2026-03-08
updated: 2026-03-08
assignee: next-ai
relates: [#0015, #0018, #0031]
status: ACTIVE
---

# 显示架构重复实现与实时桥接边界漂移

## 问题/目标
当前聊天显示链路名义上已经收敛到统一渲染核心，但实际运行中仍同时存在：
1. 统一显示核心；
2. 实时显示桥接架构；
3. 旧式 transformer 尾管线。

这导致“统一”只成立于部分中段，而不成立于端到端链路。目标不是立刻改代码，而是先把当前架构问题理清楚，明确哪些模块是主干、哪些只是 bridge、哪些已经形成双实现，后续再按边界收敛。

## 当前架构现状

### 1. 名义上的统一显示主干
当前仓库已经形成一条比较清晰的显示主干：

1. `StreamEventDispatcher`
2. `StreamNormalizeService`
3. `DisplayEnvelope`
4. `DisplayRenderOrchestrator`
5. `MessageFormatter`
6. `DisplayAugmentPipeline`
7. `Gateway.Display.Transform`

回填消息基本完整走这条链路，再由 `StreamDeliveryService.DeliverReplay()` 直接落到 `frame:AddMessage()`。

### 2. 实时路径并未真正走同一落地链路
实时消息没有像回填那样“先 render 再 AddMessage”，而是：

1. 先保持 Blizzard 原生窗口路由；
2. 再由 `RealtimeDisplayCoordinator` hook `frame:AddMessage`；
3. 依靠 `lineId / author+body / queue fallback` 反向匹配原生即将显示的消息；
4. 匹配成功后才进入统一 render core；
5. 匹配失败则直接回落到 Blizzard 原生整行。

因此，当前端到端并不是单链路，而是：
- replay：直接统一链路
- realtime：原生链路 + bridge 后置接入统一链路

### 3. 旧 transformer 机制仍然并存
在 `DisplayAugmentPipeline` 已经成为新显示扩展点后，`Gateway.Display.Transform` 里仍继续执行 `chatFrameTransformers`。

这意味着当前同时存在两套显示扩展机制：
1. 新机制：`DisplayAugmentPipeline`
2. 旧机制：`chatFrameTransformers`

虽然两者目前并非完全重复，但已经构成明显的分层重叠和职责分散。

## 已确认的重复实现/边界漂移

### A. 实时显示桥已经从“适配层”膨胀成第二套架构
`RealtimeDisplayCoordinator` 名义上应是“把 Blizzard 实时消息接回统一显示核心”的 bridge。

但当前它实际上承担了：
1. 运行时挂钩 `frame:AddMessage`；
2. envelope 匹配策略；
3. 匹配失败回退策略；
4. 实时消息是否能进入统一 render core 的最终控制权。

这已经不是单纯适配层，而是第二套运行时显示架构。

### B. 归一化职责历史上存在双实现
`StreamNormalizeService` 与 `DisplayEnvelope` 历史上都在做以下事情：
1. `wowChatType` 推导；
2. channel 基础名归一化；
3. realtime/replay 基础显示字段组装。

这类重复实现容易造成：
1. realtime 与 replay 字段来源不一致；
2. snapshot 入库字段与显示字段真相源分离；
3. 修一个地方漏另一个地方。

### C. snapshot 存储层曾经吸收显示语义
snapshot 记录不仅是数据存储，还保留了部分显示语义字段，例如 channel 基础名。

如果 snapshot store 自己维护一套 channel 名归一化规则，而显示链再维护另一套，就会造成：
1. 实时前缀与回填前缀来源不一致；
2. 历史数据格式和当前显示格式逐步漂移；
3. 存储层与显示层耦合过深。

### D. 链接交互分发虽然统一，但入口历史上不完整
`tinychat:copy` 与 `tinychat:prefix` 已通过 `ChatLinkRouter` 统一分发，这是对的。

但其历史实现只依赖 `SetItemRef`，没有明确接住聊天帧超链接点击入口，说明“分发器统一”与“入口统一”并不等价。

这类问题的本质也是边界不清：统一分发器应服务于真实 UI 入口，而不是假设某个 API 一定覆盖全部点击路径。

## 为什么这是架构问题，而不只是功能 bug
如果继续把 copy、send、prefix、timestamp、颜色这些问题逐个补丁化修复，而不先澄清架构边界，就会持续出现以下模式：

1. 某个功能在 replay 正常，在 realtime 漂移；
2. 某个修复落在 render core，另一个修复落在 realtime bridge；
3. 某个行为既在 augment pipeline 做一次，又在 transformer 尾管线做一次；
4. 表面通过测试，但长期仍无法回答“哪个模块才是唯一真相源”。

这类问题反复出现，说明当前核心矛盾不是单点逻辑错误，而是：
- 单一职责边界未完全收敛；
- bridge 与 core 的边界没有硬约束；
- 新旧两代扩展机制同时存活。

## 建议的架构定性

### 1. 明确主干
以下模块应被视为唯一显示主干：
1. `StreamNormalizeService`
2. `DisplayEnvelope`
3. `DisplayRenderOrchestrator`
4. `MessageFormatter`
5. `DisplayAugmentPipeline`

### 2. 明确 bridge
`RealtimeDisplayCoordinator` 必须明确降级为“实时兼容桥”，而不是与 render core 平级的显示架构。

它允许做的事情：
1. 把 Blizzard 原生实时消息接回统一 render core；
2. 做最小必要的匹配和桥接；
3. 在 bridge 层记录命中/失配诊断。

它不应继续承载的事情：
1. 新的显示业务规则；
2. 额外的显示策略判断；
3. 与 replay 不同的功能实现真相源。

### 3. 明确尾管线策略
`chatFrameTransformers` 需要被明确判定为：
1. 过渡层；或
2. 永久兼容层。

如果是过渡层，就应逐步迁回 `DisplayAugmentPipeline`；
如果是永久兼容层，则必须写清楚：
1. 哪些能力允许留在旧 transformer；
2. 哪些能力必须只写在新 augment pipeline；
3. 两者执行顺序与职责边界。

目前这部分没有被定义清楚。

## 非目标
1. 本 issue 不直接要求移除 `RealtimeDisplayCoordinator`。
2. 本 issue 不要求回退“实时走 Blizzard 原生路由”的既定约束。
3. 本 issue 不直接处理历史 snapshot 数据兼容。
4. 本 issue 不直接重写全部显示模块。

## 风险点
1. 如果直接试图“删掉 bridge”，可能会重新引入串窗问题。
2. 如果不先明确 bridge 边界，后续所有 realtime 特性仍会继续散落到 bridge。
3. 如果不处理两代扩展机制并存，后续会出现更多“到底该改 augment 还是 transformer”的分歧。
4. 如果 snapshot store 继续承载显示语义，存储格式与显示格式漂移会继续累积。

## 待回答的关键问题
1. `DisplayEnvelope` 是否应该彻底退化成 contract assembler，不再包含任何归一化逻辑？
2. `StreamNormalizeService` 是否应成为 realtime/replay/snapshot 共用的唯一归一化真相源？
3. `RealtimeDisplayCoordinator` 是否只保留“匹配 + 接入 render core + 诊断”，禁止承载显示规则？
4. `chatFrameTransformers` 是否进入退役计划，逐步并入 `DisplayAugmentPipeline`？
5. snapshot record 中哪些字段属于“存储事实”，哪些字段其实是“显示衍生值”？

## 验收标准
1. 能清楚回答当前显示主干、bridge、尾管线各自的职责。
2. 能明确指出哪些地方存在双实现，哪些地方只是桥接。
3. 后续 issue/改动不再继续把业务规则堆到 `RealtimeDisplayCoordinator`。
4. 后续显示相关能力新增时，开发者可以明确判断应落在：
   - normalize
   - envelope
   - render core
   - augment pipeline
   - realtime bridge
   - legacy transformer
5. 为后续收敛到“单一显示真相源 + 最小 bridge”提供文档依据。

## 下一步建议
1. 先补一份“当前显示链路核对表”，按模块标记：
   - 主干
   - bridge
   - 兼容层
   - 待退役
2. 再单开收敛 issue：
   - `RealtimeDisplayCoordinator` bridge 边界硬约束
   - `chatFrameTransformers` 并回 `DisplayAugmentPipeline`
   - snapshot record 显示语义去耦
3. 所有后续涉及 realtime/replay 一致性的功能 issue，都应先引用本问题单，避免继续在架构未定的前提下做局部补丁。
