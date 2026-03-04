---
id: 0003
priority: P0
created: 2026-03-02
updated: 2026-03-05
relates: [#0001, #0002, #0011]
status: ACTIVE
---

# 动作注册表规格

## 问题/目标

定义 Action Registry 在 Stream V2 下的能力驱动绑定规则。

## Action 定义

```lua
{
  key = "string",
  category = "channel"|"kit",
  actionPlane = "USER_ACTION"|"CHAT_DATA"|"UI_ONLY",
  appliesTo = {
    streamCapabilities = { outbound = true }, -- optional
    streamKeys = { "say", "whisper" },     -- optional
    kits = { "readyCheck" },                 -- optional
  },
  execute = function(targetKey) ... end,
}
```

## 绑定规则

- `streamCapabilities`：遍历 stream，按 capability 精确匹配。
- `streamKeys`：按指定 key 绑定。
- `kits`：按 kit 绑定。
- 不再支持 `streamPaths` 作为核心绑定输入。

## 运行时约束

- 发送动作只保留单一路径：`send_<streamKey>`，并且只绑定到 `capabilities.outbound=true` 的 stream。
- 静音动作只应绑定到 `capabilities.supportsMute=true` 的 stream。
- `mute_toggle` 的落地配置统一写入 `profile.filter.streamBlocked[streamKey]`。
- BYPASS 模式下执行权限仍由 `actionPlane` + `IsPlaneAllowed` 决定。

## BREAKING CHANGES

- 废弃 path 语义绑定（`CHANNEL.SYSTEM`/`CHANNEL.DYNAMIC` 字符串过滤）。

## 验收标准

- `send` 动作只生成在 outbound stream。
- `mute_toggle` 动作只生成在 supportsMute stream。
- system + dynamic 中 `supportsMute=true` 的 stream 均应生成 `mute_toggle_<streamKey>`。
- `notice` stream 不生成发送动作。
