# AGENT.md - TinyChaton AI 编码原则

本文档描述 `TinyChaton` 的核心开发理念与不可触碰的红线。
**AI 助手在此项目编码时，必须遵循以下原则。**

## 1. 核心设计哲学

-   **极简主义 (Minimalism)**：只做最核心的聊天增强。拒绝臃肿。
-   **数据驱动 (Data-Driven)**：`Libs/Registry/Stream.lua` 是唯一的真理来源 (Source of Truth)。所有逻辑应围绕注册表构建，而非硬编码。
-   **模块化 (Modularity)**：保持功能之间的解耦。功能模块应自包含并自我注册。

## 2. 关键架构原则

### 2.1 逻辑与视觉分离
-   **逻辑层 (EventDispatcher)**：负责数据处理（如日志记录、播放音效）。
    -   *必须* 尊重战斗锁定 (Combat Lockdown)，避免全屏 Taint。
-   **视觉层 (Transformers)**：负责文本渲染（如时间戳、缩写、颜色）。
    -   *可以* 安全地 Hook `AddMessage`，但需警惕特殊内容。

### 2.2 防御性编程 (关于“无用代码”)
-   **不要盲目删除**：如果注册表中存在看似未使用的属性（grep 无结果），通常意味着它是为未来特性预留的接口，或者是为了保持数据结构的完整性。**除非你完全理解其设计意图，否则不要删除。**

## 3. 环境约束（绝对红线）

### ❌ 严禁操作
1.  **触碰受保护事件**:
    -   绝对不要尝试过滤或处理 `MONSTER_YELL/SAY` 等受保护事件。这会导致副本中功能失效。
    -   让暴雪原生 UI 处理它们。
2.  **处理非字符串消息**:
    -   在 Hook `AddMessage` 时，必须检查 `type(text) == "string"`。
    -   忽略所有 `Secret Value`（非字符串对象），否则会导致崩溃。
3.  **污染全局环境**:
    -   修改全局变量前必须备份。
    -   尽可能使用局部变量。

## 4. 最佳实践

-   **Combat Safe**: 涉及 UI 逻辑的代码，必须考虑战斗中的 Taint 问题。默认假设代码会在 H 团本 Boss 战中运行。
-   **Secure Hooks**: 优先使用 `hooksecurefunc` 而非直接替换。
-   **Locales**: 所有用户可见字符串必须通过 `addon.L` 获取。

## 5. 开发工具与环境

### 5.1 本地 Lua 环境
-   环境已就绪：本地 Shell 支持 `lua` 和 `luac` 命令。
-   **验证逻辑 (lua)**：利用 `lua -e '...'` 运行小段代码验证逻辑（如正则、字符串处理）。
-   **验证语法 (luac)**：利用 `luac -p <file.lua>` 仅检查语法错误而不运行代码，确保没有漏掉 `end` 或括号。

## 6. Lua 编码规范

### 6.1 基础风格
-   **Local 优先**：始终使用 `local` 声明变量。严禁意外创建全局变量。
-   **缩进**：使用 4 空格缩进。
-   **字符串**：优先使用双引号 `"`。
-   **分号**：Lua 不强制分号，仅在必要时（消除歧义）使用。

### 6.2 命名约定
-   **常量**：全大写下划线，如 `MAX_LOG_ENTRIES`。
-   **私有函数**：`local function DoSomething()`。
-   **公开 API**：`function addon:DoSomething()` 或 `addon.DoSomething = function() ... end`。
-   **变量**：小驼峰 `local myVar`。

### 6.3 性能与安全
-   **表遍历**：使用 `ipairs` 遍历数组，`pairs` 遍历哈希表。
-   **字符串连接**：在紧密循环中避免大量 `..`，优先使用 table buffer (`table.insert` + `table.concat`)。
-   **全局查找**：如果在循环中频繁调用全局函数（如 `string.format`），请在文件顶部将其 local 化 (`local format = string.format`)。
