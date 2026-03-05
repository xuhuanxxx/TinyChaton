# 0031 ISSUE 实时/回填一致性未完成项（原生路由硬约束）

## 背景
本轮重构的硬约束是：
1. 实时消息必须走 Blizzard 原生窗口路由。
2. 插件不得通过手动 `AddMessage` 注入实时消息。
3. 目标是修复“消息串窗”。

该约束已生效，实时消息体重复前缀问题也已修复（实时 `arg1` 回到正文级别，不再是整行 display line）。

## 当前问题
在当前实现下，实时/回填渲染一致性仍未完成，主要包括：
1. 点击复制（含 `copyStreams`）未完全一致。
2. `tinychat:send` 发送链接未完全一致。
3. 频道名称缩写（`nameStyle/showNumber`）在实时路径未稳定生效。

## 根因分析
### 已验证事实（缩写相关）
1. 实时链路当前只改正文 `arg1`，不改 `CHAT_MSG_CHANNEL` 事件的频道参数（如 `channelString`）。
2. Blizzard 默认聊天前缀（频道/作者）在事件处理后续阶段生成，主要依赖原始事件参数。
3. 直接改 `channelString` 曾触发 `ChatFrameUtil` 社区频道解析异常（`communityChannel` nil），属于高风险路径。

### 结论
1. 在“只改 `arg1`”条件下，实时频道前缀缩写不会自动生效。
2. 在“直接改事件频道参数”条件下，有稳定性风险。
3. 当前一致性问题不只缩写，还包括 copy/send 两项能力漂移。

## 约束（必须满足）
1. 不破坏“防串窗”主目标：实时仍走原生路由。
2. 不修改 `CHAT_MSG_CHANNEL` 原始参数结构（避免社区频道解析风险）。
3. 不引入全局 `frame:AddMessage` 普改副作用。
4. 不做向下兼容兜底，允许破坏性收敛到单路径实现。

## 目标
1. 让实时频道前缀缩写按配置生效（`nameStyle/showNumber`）。
2. 让实时/回填 copy 行为一致（含 `clickToCopy`、`copyStreams`）。
3. 让实时/回填 send link 行为一致（按 stream outbound 能力）。
4. 不回退到“手动实时注入”模式。

## 非目标
1. 不恢复旧的 regex 后置全局改写方案。
2. 不在本议题内处理旧 snapshot 数据质量问题。
3. 不改变窗口路由策略。

## 风险点
1. 实时前缀由 Blizzard 生成，插件在 filter 阶段可控范围有限。
2. 任何对 `CHAT_MSG_CHANNEL` 参数的侵入修改都可能影响社区频道分支。
3. 若选择后置显示层改写，需避免作用到非本插件消息。
4. 若实时/回填仍保留双路径规则，将持续出现 copy/send/prefix 漂移。

## 问题清单（待实现）
### P0-1 点击复制一致性
现象：
1. 回填可稳定生成 `tinychat:copy`。
2. 实时目前仍可能存在路径差异。

验收：
1. 相同 stream/配置下，实时与回填对 copy 链接的出现与否一致。
2. `clickToCopy=false` 或 `copyStreams[streamKey]=false` 时，两条链路都不注入 copy 链接。

### P0-2 `tinychat:send` 一致性
现象：
1. 回填可生成 `tinychat:send:streamKey`。
2. 实时能力仍有漂移风险。

验收：
1. 实时/回填 send link 规则一致。
2. 无 outbound 能力的 stream 两条链路都不出现 send link。

### P0-3 前缀缩写一致性
现象：
1. 回填可通过 formatter 链路输出配置化前缀。
2. 实时前缀缩写在当前路径下未稳定。

验收：
1. 实时前缀缩写按配置生效。
2. 实时与回填前缀风格一致。
3. 不引入全局副作用。

## 禁止方案（边界约束）
1. 直接改 `CHAT_MSG_CHANNEL` 事件参数中的频道字段。
2. 对整个 `ChatFrame:AddMessage` 做无条件全局改写。

## 验收标准
1. 实时消息不串窗。
2. 实时消息体保持正文级（无重复前缀）。
3. 实时/回填 copy 行为一致（含配置约束）。
4. 实时/回填 send link 行为一致。
5. 实时频道前缀缩写按配置生效，且与回填一致。
6. 非本插件消息不受改写影响。

## 回归测试建议
1. `Realtime_NoCrossWindowInjection`。
2. `Realtime_BodyOnly_NoDuplicatePrefixInArg1`。
3. `Realtime_ClickToCopy_RespectsCopyStreams`。
4. `Replay_ClickToCopy_RespectsCopyStreams`。
5. `Realtime_And_Replay_SendLink_Equivalent`。
6. `Realtime_ChannelPrefix_RespectsNameStyle`（say/guild/channel）。
7. `Realtime_ChannelPrefix_DoesNotMutateChatEventArgs`。
8. `Replay_And_Realtime_PrefixStyle_Equivalent`。
9. `NoGlobalAddMessageRewriteSideEffects`。

## 当前状态
- 已完成：防串窗主目标、实时消息体去冗余。
- 未完成：copy/send/prefix 三项一致性收敛。
