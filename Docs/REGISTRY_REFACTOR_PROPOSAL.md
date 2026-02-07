# 注册表重构提案 (Registry Refactor Proposal)

**状态**: 待定 (Planned Future Work)
**优先级**: 低 (代码洁癖/架构优化)
**主要目标**: 将 `CHANNEL_REGISTRY` 从扁平布尔标志结构迁移到强类型/枚举结构。

## 1. 背景与动机
目前的 `CHANNEL_REGISTRY` 使用多个布尔标志来定义频道特性：
- `isSystem = true` (如 Say, Yell, Guild)
- `isDynamic = true` (如 General, Trade)
- `isPrivate = true` (如 Whisper, BN)
- `isSystemMsg` (隐式，未在注册表中显式定义，但在逻辑中使用)

**存在的问题**:
- **互斥性不明确**: 理论上一个频道不应同时是 `isSystem` 和 `isDynamic`，但代码结构允许这种非法状态。
- **扩展性一般**: 每增加一种新类型，就需要增加一个新的布尔字段，并在所有消费该数据的逻辑中添加 `if/else`。
- **语义模糊**: 某些行为（如“是否可快照”、“是否可钉选”）与“频道类型”绑定过紧，缺乏明确的行为定义。

## 2. 建议架构

引入 `ChannelType` 枚举和明确的行为标志。

### 2.1 新的枚举定义
```lua
addon.Enum = addon.Enum or {}
addon.Enum.ChannelType = {
    SYSTEM  = "SYSTEM",   -- 系统内置 (Say, Yell, Guild, Raid...)
    DYNAMIC = "DYNAMIC",  -- 动态加入 (General, Trade...)
    PRIVATE = "PRIVATE",  -- 私聊类 (Whisper, BN)
    VIRTUAL = "VIRTUAL",  -- 虚拟频道 (如有需扩展)
}
```

### 2.2 注册表项结构变更

**System Channel (Before)**:
```lua
{ 
    key = "say", 
    isSystem = true, 
    defaultPinned = true 
}
```

**System Channel (After)**:
```lua
{ 
    key = "say", 
    type = addon.Enum.ChannelType.SYSTEM,
    -- 明确的行为标志 (Capabilities)
    flags = {
        canPin = true,
        canSnapshot = true,
        autoJoin = false,
    }
}
```

**Dynamic Channel (Before)**:
```lua
{ 
    key = "general", 
    isDynamic = true, 
    requiresAvailabilityCheck = true,
    defaultAutoJoin = true
}
```

**Dynamic Channel (After)**:
```lua
{ 
    key = "general", 
    type = addon.Enum.ChannelType.DYNAMIC,
    flags = {
        canPin = true,
        canSnapshot = true,
        autoJoin = true,
        checkAvailability = true -- 替代 requiresAvailabilityCheck
    }
}
```

## 3. 影响范围与迁移指南

此重构将影响以下核心文件：

### A. 核心定义
- **[MODIFY] `Libs/Registry/Channels.lua`**: 全面重写注册表数据结构。
- **[MODIFY] `Core.lua`**: 定义 `addon.Enum`。

### B. 配置生成 (`Config.lua`)
- **现状**: 使用 `if reg.isSystem or reg.isDynamic then` 来生成默认钉选列表。
- **变更**: 修改为检查 `if reg.flags.canPin then`。这将使逻辑更通用，不再依赖类型判断。

### C. 库架筛选 (`Settings/Pages/Shelf.lua`)
- **现状**: Ribbon 使用硬编码的筛选器 `function(r) return r.isSystem end`。
- **变更**: 修改为 `function(r) return r.type == addon.Enum.ChannelType.SYSTEM end`。

### D. 快照逻辑 (`Modules/Snapshot.lua`)
- **现状**: 依赖 `isSystemMsg` 和 `isNotStorable`（这些标志目前甚至未在 Registry 中显式定义）。
- **变更**: 在 `flags` 中明确定义 `canSnapshot`，彻底移除硬编码的排除逻辑。

## 4. 实施步骤

1.  **定义 Enum**: 在 `Core.lua` 头部添加枚举定义。
2.  **转换 Registry**: 逐个修改 `Libs/Registry/Channels.lua` 中的条目，添加 `type` 和 `flags`。
3.  **适配 Config**: 修改 `Config.lua` 中的 `BuildChannelPins`, `BuildSnapshotChannels` 等函数，改为基于 `flags` 遍历。
4.  **适配 UI**: 全局搜索 `isSystem`, `isDynamic`，替换为新的类型检查或 Capability 检查。
5.  **验证**: 使用现有的重置功能，确保新结构能正确生成默认配置。

## 5. 收益总结
- **代码整洁**: 逻辑更清晰，消除了通过组合布尔值来猜测频道类型的做法。
- **配置解耦**: “频道是什么类型”和“频道能做什么”解耦。未来如果想让某个系统频道支持自动加入，只需修改 flag，无需修改类型逻辑。
