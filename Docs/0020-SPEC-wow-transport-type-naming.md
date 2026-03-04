---
id: 0020
priority: P0
created: 2026-03-05
updated: 2026-03-05
relates: [#0002, #0004, #0011, #0019]
status: ACTIVE
---

# wowChatType 命名规范

## 目标

统一 WoW 协议层类型字段命名，避免业务层 `chatType` 与 UI attribute `chatType` 混淆。

## 规范

1. 协议层枚举字段统一命名为 `wowChatType`。
- 例：`SAY`, `YELL`, `GUILD`, `CHANNEL`, `SYSTEM`。

2. 事件映射索引统一命名为 `eventToWowChatType`。

3. 解析函数统一命名为 `GetWowChatTypeByEvent(event)`。

4. 发送网关参数命名：
- `Gateway.Outbound:SendChat(text, wowChatType, language, target)`。

## 允许例外

1. WoW 原生 EditBox attribute 键名 `"chatType"` 必须保留，不改名。
2. 纯 UI 交互流程中与 Blizzard API 强耦合的 `chatType` 字符串字段可保留。

## 禁止项

1. 在 Stream 通用域新增裸 `chatType` 字段或变量。
2. 在编译产物继续使用 `eventToChatType`。
3. 在业务模型把 `wowChatType` 与 `streamKind` 混用。

## 验收

1. 全仓搜索中，裸 `chatType` 只允许出现在白名单例外位置。
2. Stream Registry schema、Snapshot record、Formatter line、Gateway outbound 全部使用 `wowChatType`。
