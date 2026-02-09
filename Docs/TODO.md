# TinyChaton 待办改进清单 (TODO)

**文档版本**: 1.0  
**创建日期**: 2026-02-10  
**优先级**: P2 (轻微) / 建议性改进  

---

## 📋 说明

本文档记录代码审查中发现的**轻微问题**和**建议性改进**，这些问题不影响功能使用，但可提升代码质量、性能或可维护性。可在日常迭代中逐步完成。

---

## 🎨 代码风格与一致性

### TODO-001: 统一命名规范

**状态**: ⚠️ 部分完成  
**影响**: 可维护性  
**难度**: 低  

**问题**:
- 局部变量命名不一致（驼峰 vs 下划线）
- 有的用 `channelNameCache`，有的用 `cleanup_counter`

**示例**:
```lua
-- 不一致
local channelNameCache = {}      -- 驼峰 ✅
local cleanup_counter = 0        -- 下划线 ❌
local MAX_COUNT = 100           -- 大写下划线 ✅
```

**建议**:
- 局部变量：小写驼峰 `localVariableName`
- 常量：大写下划线 `CONSTANT_NAME`
- 函数参数：小写驼峰 `paramName`

---

### TODO-002: 统一注释风格

**状态**: ⚠️ 未完成  
**影响**: 可读性  
**难度**: 低  

**问题**:
- 中英文注释混用
- 有的用 `---`，有的用 `--`

**示例**:
```lua
-- 英文
-- Stage: ENRICH (via EventDispatcher)

-- 中文
-- 通过层级位置推导能力，而非依赖布尔标志

-- 中英文混用
-- CHANNEL 下的项默认值
```

**建议**:
- 技术注释使用英文
- 业务逻辑注释可用中文
- 统一使用 `---` 用于函数文档，`--` 用于普通注释

---

### TODO-003: 删除行尾空白

**状态**: ⚠️ 未完成  
**影响**: 代码整洁  
**难度**: 极低  

**问题**:
- 多处存在行尾空格

**修复方法**:
```bash
# 使用 sed 批量删除
find . -name "*.lua" -exec sed -i 's/[[:space:]]*$//' {} \;
```

**或配置编辑器**:
- VSCode: `"files.trimTrailingWhitespace": true`
- 添加 `.editorconfig` 文件

---

## ⚡ 性能优化

### TODO-004: 字符串拼接优化

**状态**: ⚠️ 未完成  
**位置**: `Modules/EmoteHelper.lua`, `Modules/SnapshotManager.lua`  
**影响**: 高频场景性能  
**难度**: 低  

**问题**:
```lua
-- 当前代码
local displayLine = timestamp .. channelTag .. authorTag .. finalText

-- 多次拼接会产生多个中间字符串对象
```

**建议**:
```lua
-- 使用 table.concat
local parts = {timestamp, channelTag, authorTag, finalText}
local displayLine = table.concat(parts)

-- 或一次性格式化
local displayLine = string.format("%s%s%s%s", timestamp, channelTag, authorTag, finalText)
```

**优先级**: 低（仅在确实出现性能问题时处理）

---

### TODO-005: 局部变量缓存全局函数

**状态**: ⚠️ 部分完成  
**影响**: 微性能优化  
**难度**: 低  

**建议**:
```lua
-- 文件顶部添加
local format = string.format
local ipairs = ipairs
local pairs = pairs
local type = type
local GetTime = GetTime

-- 然后在函数中使用局部引用
local now = GetTime()  -- 比 _G.GetTime() 快一点点
```

**注意**: 现代LuaJIT优化很好，这个改进效果有限，优先级低。

---

### TODO-006: 构建完整的反向索引

**状态**: ⚠️ 部分完成  
**位置**: `Modules/Utils.lua`  
**影响**: O(n) → O(1) 性能提升  
**难度**: 中  

**当前状态**:
- 已有 `channelNameCache` 但只在运行时缓存
- 每次服务器重启后缓存清空

**建议**:
```lua
-- 在初始化时构建完整索引
function addon:BuildChannelIndex()
    self._channelIndex = {}
    for _, stream, catKey, subKey in self:IterateAllStreams() do
        if stream.mappingKey then
            self._channelIndex[stream.mappingKey] = stream
        end
        if stream.key then
            self._channelIndex[stream.key] = stream
        end
    end
end

-- 查询时 O(1)
function addon:FindChannelByKey(key)
    return self._channelIndex and self._channelIndex[key]
end
```

---

## 🧪 测试与质量保障

### TODO-007: 添加单元测试框架

**状态**: ⚠️ 未完成  
**影响**: 代码信心、回归防护  
**难度**: 中  

**建议**:
```lua
-- Core/Tests.lua
addon.tests = {}

function addon.tests.RunAll()
    local passed, failed = 0, 0
    for name, test in pairs(addon.tests) do
        if type(test) == "function" and name ~= "RunAll" then
            local ok, err = pcall(test)
            if ok then
                passed = passed + 1
                print(string.format("✓ %s", name))
            else
                failed = failed + 1
                print(string.format("✗ %s: %s", name, err))
            end
        end
    end
    print(string.format("\nResults: %d passed, %d failed", passed, failed))
end

-- 测试示例
function addon.tests.TestDeepCopy()
    local orig = { a = 1, b = { c = 2 } }
    local copy = addon.Utils.DeepCopy(orig)
    assert(copy.a == 1, "Basic copy failed")
    assert(copy.b.c == 2, "Nested copy failed")
    assert(copy ~= orig, "Reference not copied")
    assert(copy.b ~= orig.b, "Nested reference not copied")
end

function addon.tests.TestNormalizeChannelName()
    assert(addon.Utils.NormalizeChannelBaseName("[1. 大脚世界频道]") == "大脚世界频道")
    assert(addon.Utils.NormalizeChannelBaseName("General") == "General")
end

-- Slash命令
SLASH_TINYCHATON_TEST1 = "/tctest"
SlashCmdList["TINYCHATON_TEST"] = function() addon.tests.RunAll() end
```

**测试优先级**:
1. `Utils.DeepCopy` - 核心工具
2. `Utils.NormalizeChannelBaseName` - 频道解析
3. `ChatData:New` - 数据管道
4. `Blacklist.IsPatternSafe` - 安全函数

---

### TODO-008: 添加性能剖析代码

**状态**: ⚠️ 未完成  
**影响**: 性能监控、问题定位  
**难度**: 中  

**建议**:
```lua
-- Core/Profiler.lua
addon.profiler = {
    data = {},
    enabled = false,
}

function addon.profiler:Start(name)
    if not self.enabled then return end
    self.data[name] = self.data[name] or { count = 0, total = 0, max = 0 }
    self.data[name].start = debugprofilestop()
end

function addon.profiler:Stop(name)
    if not self.enabled or not self.data[name] then return end
    local elapsed = debugprofilestop() - self.data[name].start
    local d = self.data[name]
    d.count = d.count + 1
    d.total = d.total + elapsed
    d.max = math.max(d.max, elapsed)
    d.avg = d.total / d.count
end

function addon.profiler:Report()
    print("=== Performance Report ===")
    for name, stats in pairs(self.data) do
        print(string.format("%s: %d calls, %.3fms avg, %.3fms max",
            name, stats.count, stats.avg, stats.max))
    end
end

-- 使用示例
function addon.ChatData:New(...)
    addon.profiler:Start("ChatData:New")
    -- ... 原有逻辑 ...
    addon.profiler:Stop("ChatData:New")
    return chatData
end
```

**监控热点**:
- `ChatData:New` - 每条消息都调用
- `EmoteHelper.Parse` - 每条消息都调用
- `ShortenChannelString` - 每条消息都调用
- `Blacklist.MatchRule` - 每条消息都调用

---

## 📚 文档完善

### TODO-009: 编写架构文档 (ARCHITECTURE.md)

**状态**: ⚠️ 未完成  
**影响**: 新贡献者上手难度  
**难度**: 中  

**建议内容**:
1. **架构概述**
   - 管道模式说明
   - 注册表模式说明
   - 数据流向图

2. **模块开发指南**
   - 如何创建新模块
   - 如何使用 RegisterModule
   - 中间件开发指南

3. **配置文件结构**
   - 数据库结构说明
   - 各配置项含义
   - 迁移策略

4. **事件流图**
   ```
   Chat Event → ChatData → PRE_PROCESS → FILTER → ENRICH → LOG → Display
                   ↓
              Snapshot
   ```

---

### TODO-010: 完善 API 文档

**状态**: ⚠️ 未完成  
**影响**: 可维护性  
**难度**: 低  

**使用 LuaCATS 注解**:
```lua
---@class ChatData
---@field text string 消息内容
---@field author string 发送者
---@field name string 纯名字(不含服务器)
---@field textLower string 小写内容(用于匹配)

---创建新的 ChatData 对象
---@param frame table|nil ChatFrame 对象
---@param event string 事件名
---@param ... any 事件参数
---@return ChatData|nil 成功返回对象，失败返回 nil
function addon.ChatData:New(frame, event, ...)
    -- ...
end
```

---

## 🔧 代码组织

### TODO-011: 拆分过长函数

**状态**: ⚠️ 未完成  
**位置**: `Modules/SnapshotManager.lua:RestoreChannelContent`  
**影响**: 可读性、可测试性  
**难度**: 中  

**当前问题**:
```lua
-- 这个函数 300+ 行，做了太多事情
function RestoreChannelContent()
    -- 检查开关
    -- 获取角色Key
    -- 验证数据
    -- 遍历频道
    -- 构建消息
    -- 应用颜色
    -- 创建链接
    -- 添加时间戳
    -- 发送到聊天框
end
```

**建议拆分**:
```lua
function RestoreChannelContent()
    if not CanRestore() then return end
    local messages = LoadStoredMessages()
    for _, msg in ipairs(messages) do
        local formatted = FormatMessageForDisplay(msg)
        DisplayRestoredMessage(formatted)
    end
end

function CanRestore() ... end
function LoadStoredMessages() ... end
function FormatMessageForDisplay(msg) ... end
function DisplayRestoredMessage(formatted) ... end
```

---

### TODO-012: 提取公共 UI 组件

**状态**: ⚠️ 未完成  
**影响**: 代码复用  
**难度**: 中  

**观察**:
- `Ribbon.lua` 创建了可复用的 Tab 组件 ✅
- 但按钮创建代码在 Shelf 和 Dialog 中重复

**建议**:
```lua
-- Libs/UI/Button.lua
function addon.CreateIconButton(parent, options)
    -- 统一按钮创建逻辑
end

function addon.CreateStyledFrame(parent, options)
    -- 统一 Frame 创建逻辑
end
```

---

## 🚀 高级优化 (未来)

### TODO-013: 实现对象池模式

**状态**: ⚠️ 未完成  
**影响**: 内存分配/GC  
**难度**: 高  

**适用场景**:
- `ChatData` 对象（高频创建）
- 消息解析的中间表
- UI 更新时的临时表

**概念代码**:
```lua
-- Utils/Pool.lua
addon.Pool = {}
local pools = {}

function addon.Pool:Create(name, factory, reset)
    pools[name] = {
        available = {},
        inUse = {},
        factory = factory,
        reset = reset
    }
end

function addon.Pool:Acquire(name)
    local pool = pools[name]
    local obj = table.remove(pool.available) or pool.factory()
    pool.inUse[obj] = true
    return obj
end

function addon.Pool:Release(name, obj)
    local pool = pools[name]
    if pool.inUse[obj] then
        pool.inUse[obj] = nil
        pool.reset(obj)
        table.insert(pool.available, obj)
    end
end
```

**优先级**: 仅在确实存在 GC 问题时实施。

---

### TODO-014: 配置热重载

**状态**: ⚠️ 未完成  
**影响**: 用户体验  
**难度**: 高  

**功能**:
- 修改设置后立即生效，无需 `/reload`
- 使用 `addon:RegisterConfigWatcher(path, callback)`

**示例**:
```lua
addon:RegisterConfigWatcher("plugin.chat.content.emoteRender", function(newValue)
    if newValue then
        addon:StartEmoteTicker()
    else
        addon:StopEmoteTicker()
    end
end)
```

---

## 📊 完成追踪

### 统计

| 类别 | 数量 | 已完成 | 进度 |
|------|------|--------|------|
| 代码风格 | 3 | 0 | 0% |
| 性能优化 | 3 | 1 | 33% |
| 测试与质量 | 2 | 0 | 0% |
| 文档完善 | 2 | 0 | 0% |
| 代码组织 | 2 | 0 | 0% |
| 高级优化 | 2 | 0 | 0% |
| **总计** | **14** | **1** | **7%** |

### 优先级建议

**短期内 (本周)**:
- TODO-003: 删除行尾空白
- TODO-010: 添加 LuaCATS 注解

**中期 (本月)**:
- TODO-007: 单元测试框架
- TODO-009: 架构文档

**长期 (看需求)**:
- TODO-013: 对象池模式
- TODO-014: 配置热重载

---

## 💡 贡献指南

如果你要处理这些 TODO:

1. **先创建 Issue** 说明你要处理哪个 TODO
2. **创建分支** `feature/TODO-XXX`
3. **完成后更新本文档** 标记为已完成
4. **提交 PR** 并关联 Issue

**注意**: 这些改进都是**可选**的，不影响插件功能。

---

*最后更新: 2026-02-10*
