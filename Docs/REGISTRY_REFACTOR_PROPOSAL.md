# 注册表重构提案 (Registry Refactor Proposal)

**状态**: 待定 (Planned Future Work)
**优先级**: 中 (架构稳健性 & 12.0 兼容性)
**主要目标**: 建立以 **STREAM (信息流)** 为核心的声明式架构，将消息逻辑划分为 **CHANNEL (频道)** 与 **NOTICE (通知)**。

## 1. 背景与背景 (数据现状)

目前的 `CHANNEL_REGISTRY` 逻辑模糊:
- 强行将所有信息源都称为“频道”，导致系统提示、经验获取等非交互内容也必须适配频道的布尔标志（如 `isSystem`）。
- **存在的问题**: 命名泛化导致代码中出现大量“为了适配而适配”的逻辑，难以区分哪些是玩家参与的对话，哪些是系统的单向通知。

## 2. 深度分析：WoW 12.0 的新 API 环境

### 2.1 核心挑战
- **沙盒化数据 (Secret Value)**：主要集中在特定的 `NOTICE` 类信息流（如 Boss 喊话）。
- **防御策略**：通过顶层的 `Stream` 属性来决定是否在该路径上启用插件逻辑，实现 100% 的安全性。

## 3. 建议架构：STREAM > CHANNEL / NOTICE

### 3.1 结构化定义：层级嵌套
我们将放弃扁平的列表结构，改为由 `Stream` 顶层分类驱动的嵌套表。结构本身即代表了类型和能力。

```lua
addon.STREAM_REGISTRY = {
    -- [CHANNEL] 子集：具备发送、粘滞、编号等交互能力的流
    CHANNEL = {
        SYSTEM = {
            { key = "say", chatType = "SAY", events = { "CHAT_MSG_SAY" } },
            { key = "guild", chatType = "GUILD", events = { "CHAT_MSG_GUILD" } },
            -- ... 所有 isSystem 的频道
        },
        DYNAMIC = {
            { key = "general", chatType = "CHANNEL", events = { "CHAT_MSG_CHANNEL" }, mappingKey = "CHANNEL_GENERAL" },
            -- ... 所有 isDynamic 的频道
        },
        PRIVATE = {
            { key = "whisper", chatType = "WHISPER", events = { "CHAT_MSG_WHISPER", "CHAT_MSG_WHISPER_INFORM" } },
            -- ... 私聊类
        }
    },
    
    -- [NOTICE] 子集：由系统生成的单向通知流
    NOTICE = {
        LOG = {
            { key = "experience", events = { "CHAT_MSG_COMBAT_XP_GAIN" } },
            -- ...
        },
        SYSTEM = {
            { key = "system_info", events = { "CHAT_MSG_SYSTEM" } },
            -- ...
        },
        ALERT = {
            { key = "boss_emote", events = { "RAID_BOSS_EMOTE" }, isCombatProtected = true },
            -- ...
        }
    }
}

-- [KIT] 独立表：工具按钮（不属于 Stream 体系）
addon.KIT_REGISTRY = {
    { key = "readyCheck", ... },
    { key = "countdown", ... },
    -- ...
}
```

### 3.2 能力推导逻辑 (Inference)

**核心原则：从位置推导能力，而非依赖布尔标志**

#### 隐式能力表（默认均为 `true`）
- **如果是 `CHANNEL.*` 下的项目**：
  - `defaultPinned = true`（默认钉选到 Shelf）
  - `defaultSnapshotted = true`（支持快照）
  - 自动具备交互 UI、编号显示、粘滞记忆
  
- **如果是 `NOTICE.*` 下的项目**：
  - `defaultPinned = false`
  - `defaultSnapshotted = false`（大部分 NOTICE 不需要快照）
  - 自动剥离交互 UI

- **KIT 项目**（独立于 Stream）：
  - `defaultPinned = true`（默认展示）

#### Shelf UI 筛选规则（代码行 77-80 的逻辑）
工具架只允许以下三类显示：
1. `CHANNEL.SYSTEM`
2. `CHANNEL.DYNAMIC`
3. `KIT`

### 3.3 ACTION 反向绑定机制

**当前问题**：ACTION 当前绑定在频道/KIT 的 `actions` 字段中，导致：
- 如果同一 ACTION 需要服务多个频道，必须在每个频道中重复定义
- ACTION 逻辑与频道逻辑耦合

**重构方案**：让 ACTION 反过来声明自己服务哪些频道/KIT

```lua
-- 新的 ACTION_REGISTRY 结构（独立文件）
addon.ACTION_DEFINITIONS = {
    {
        key = "send",
        label = L["ACTION_SEND"],
        category = "channel",
        -- ACTION 声明自己适用于哪些流
        appliesTo = { 
            streamTypes = { "CHANNEL.SYSTEM", "CHANNEL.DYNAMIC" }  -- 通配所有 CHANNEL.SYSTEM 和 DYNAMIC
        },
        execute = function(streamKey)
            local stream = addon:GetStreamByKey(streamKey)
            if stream then
                addon:ActionSend(stream.chatType)
            end
        end
    },
    {
        key = "readycheck",
        label = L["ACTION_READYCHECK"],
        category = "kit",
        appliesTo = { kits = { "readyCheck" } },
        execute = function() DoReadyCheck() end
    }
}
```

### 3.4 事件驱动的自动化监听 (Event Binding)

**核心层统一分发**：
- 在 `Core.lua` 初始化时，遍历 `STREAM_REGISTRY` 收集所有 `events`
- 为每个唯一事件注册一个全局过滤器
- 当事件触发时，核心分发器：
  1. 识别该事件属于哪个 Stream（通过 `chatType` 或其他参数）
  2. 应用黑名单/高亮逻辑
  3. 将处理后的数据传递给对应模块

```lua
-- 示例：事件统一捕获
function addon:InitEventDispatcher()
    local eventToStreams = {}
    
    -- 遍历 STREAM_REGISTRY 建立映射
    for categoryKey, category in pairs(addon.STREAM_REGISTRY) do
        for subKey, subCategory in pairs(category) do
            for _, stream in ipairs(subCategory) do
                for _, event in ipairs(stream.events or {}) do
                    if not eventToStreams[event] then
                        eventToStreams[event] = {}
                    end
                    table.insert(eventToStreams[event], stream)
                end
            end
        end
    end
    
    -- 注册核心过滤器
    for event, streams in pairs(eventToStreams) do
        ChatFrame_AddMessageEventFilter(event, function(self, evt, msg, ...)
            -- 统一处理：黑名单、高亮、Taint 检测
            -- 分发到各个 stream 的处理器
            return false  -- 不拦截
        end)
    end
end
```

## 4. 核心收益

### 3.1 零接触防御 (Zero-Touch Defense)
通过注册表的 `isCombatProtected` 标志，核心钩子（如 `AddMessage`）可以实现声明式拦截。只要该标志为 `true`，插件逻辑立即短路，杜绝一切 Taint 风险。

### 3.2 逻辑解耦
- **配置解耦**：UI 遍历注册表时只需关心 `canPin`，无需知道它是 Guild 还是 Whisper。
- **扩展解耦**：如果暴雪未来保护了新的事件，只需更新一处注册表定义，全工程自动适配。

## 5. 实施路线图

1. **基础建设**：在 `Core.lua` 定义 `addon.Enum.SourceType`。
2. **结构迁移**：重写 `Libs/Registry/Channels.lua`，将扁平布尔值迁移至 `type` + `flags`。
3. **安全加固**：重做 `IsMessageProtected` 函数，使其完全基于注册表 `flags` 运行。
4. **功能适配**：分模块适配 `Snapshot`, `Visual`, `Shelf` 逻辑。
