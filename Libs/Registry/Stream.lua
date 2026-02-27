local addonName, addon = ...
local L = addon.L

-- =========================================================================
-- STREAM_REGISTRY
-- 消息流层级注册表 - Stream > Channel / Notice 架构
-- 通过嵌套结构隐式推导能力，移除扁平布尔标志
-- =========================================================================

addon.STREAM_REGISTRY = {
    -- =====================================================================
    -- [CHANNEL] 具备交互能力的消息流（发送、粘滞、编号）
    -- 默认能力：defaultPinned = true, defaultSnapshotted = true
    -- =====================================================================
    CHANNEL = {
        -- [SYSTEM] 系统内置频道
        SYSTEM = {
            {
                key = "say",
                chatType = "SAY",
                shortKey = "STREAM_SAY_SHORT",
                label = L["STREAM_SAY_LABEL"],

                events = { "CHAT_MSG_SAY" },
                order = 10,
                defaultBindings = { left = "send" },
            },
            {
                key = "yell",
                chatType = "YELL",
                shortKey = "STREAM_YELL_SHORT",
                label = L["STREAM_YELL_LABEL"],

                events = { "CHAT_MSG_YELL" },
                order = 20,
                defaultBindings = { left = "send" },
            },
            {
                key = "party",
                chatType = "PARTY",
                shortKey = "STREAM_PARTY_SHORT",
                label = L["STREAM_PARTY_LABEL"],

                events = { "CHAT_MSG_PARTY", "CHAT_MSG_PARTY_LEADER" },
                order = 40,
                defaultBindings = { left = "send" },
            },
            {
                key = "raid",
                chatType = "RAID",
                shortKey = "STREAM_RAID_SHORT",
                label = L["STREAM_RAID_LABEL"],

                events = { "CHAT_MSG_RAID", "CHAT_MSG_RAID_LEADER", "CHAT_MSG_RAID_WARNING" },
                order = 50,
                defaultBindings = { left = "send" },
            },
            {
                key = "instance",
                chatType = "INSTANCE_CHAT",
                shortKey = "STREAM_INSTANCE_SHORT",
                label = L["STREAM_INSTANCE_LABEL"],

                events = { "CHAT_MSG_INSTANCE_CHAT", "CHAT_MSG_INSTANCE_CHAT_LEADER" },
                order = 60,
                defaultBindings = { left = "send" },
            },
            {
                key = "battleground",
                chatType = "BATTLEGROUND",
                shortKey = "STREAM_BATTLEGROUND_SHORT",
                label = L["STREAM_BATTLEGROUND_LABEL"],

                events = { "CHAT_MSG_BATTLEGROUND", "CHAT_MSG_BATTLEGROUND_LEADER" },
                order = 65,
                defaultPinned = false,  -- 明确override默认值
                defaultBindings = { left = "send" },
            },
            {
                key = "guild",
                chatType = "GUILD",
                shortKey = "STREAM_GUILD_SHORT",
                label = L["STREAM_GUILD_LABEL"],

                events = { "CHAT_MSG_GUILD" },
                order = 70,
                defaultBindings = { left = "send" },
            },
            {
                key = "officer",
                chatType = "OFFICER",
                shortKey = "STREAM_OFFICER_SHORT",
                label = L["STREAM_OFFICER_LABEL"],

                events = { "CHAT_MSG_OFFICER" },
                order = 80,
                defaultPinned = false,
                defaultBindings = { left = "send" },
            },
            {
                key = "emote",
                chatType = "EMOTE",
                shortKey = "STREAM_EMOTE_SHORT",
                label = L["STREAM_EMOTE_LABEL"],

                events = { "CHAT_MSG_EMOTE", "CHAT_MSG_TEXT_EMOTE" },
                order = 85,
                defaultPinned = false,
                defaultBindings = { left = "send" },
            },
        },

        -- [DYNAMIC] 动态加入频道（需要服务器ID）
        -- Shelf availability detection is intentionally scoped to this group only.
        DYNAMIC = {
            {
                key = "general",
                chatType = "CHANNEL",
                mappingKey = "STREAM_GENERAL_MAPPING",
                shortKey = "STREAM_GENERAL_SHORT",
                label = L["STREAM_GENERAL_LABEL"],

                events = { "CHAT_MSG_CHANNEL" },
                order = 90,
                defaultBindings = { left = "send", right = "mute_toggle" },
            },
            {
                key = "trade",
                chatType = "CHANNEL",
                mappingKey = "STREAM_TRADE_MAPPING",
                shortKey = "STREAM_TRADE_SHORT",
                label = L["STREAM_TRADE_LABEL"],

                events = { "CHAT_MSG_CHANNEL" },
                order = 91,
                defaultBindings = { left = "send", right = "mute_toggle" },
            },
            {
                key = "localdefense",
                chatType = "CHANNEL",
                mappingKey = "STREAM_LOCALDEFENSE_MAPPING",
                shortKey = "STREAM_LOCALDEFENSE_SHORT",
                label = L["STREAM_LOCALDEFENSE_LABEL"],

                events = { "CHAT_MSG_CHANNEL" },
                order = 92,
                defaultPinned = false,
                defaultBindings = { left = "send", right = "mute_toggle" },
            },
            {
                key = "lfg",
                chatType = "CHANNEL",
                mappingKey = "STREAM_LFG_MAPPING",
                shortKey = "STREAM_LFG_SHORT",
                label = L["STREAM_LFG_LABEL"],

                events = { "CHAT_MSG_CHANNEL" },
                order = 93,
                defaultBindings = { left = "send", right = "mute_toggle" },
            },
            {
                key = "services",
                chatType = "CHANNEL",
                mappingKey = "STREAM_SERVICES_MAPPING",
                shortKey = "STREAM_SERVICES_SHORT",
                label = L["STREAM_SERVICES_LABEL"],

                events = { "CHAT_MSG_CHANNEL" },
                order = 94,
                defaultPinned = false,
                defaultBindings = { left = "send", right = "mute_toggle" },
            },
            {
                key = "world",
                chatType = "CHANNEL",
                mappingKey = "STREAM_WORLD_MAPPING",
                shortKey = "STREAM_WORLD_SHORT",
                label = L["STREAM_WORLD_LABEL"],

                events = { "CHAT_MSG_CHANNEL" },
                order = 100,
                defaultBindings = { left = "send", right = "mute_toggle" },
            },
        },

        -- [PRIVATE] 私聊类频道
        PRIVATE = {
            {
                key = "whisper",
                chatType = "WHISPER",
                shortKey = "STREAM_WHISPER_SHORT",
                label = L["STREAM_WHISPER_LABEL"],

                events = { "CHAT_MSG_WHISPER", "CHAT_MSG_WHISPER_INFORM" },
                order = 30,
                defaultPinned = false,
                defaultBindings = { left = "send" },
            },
            {
                key = "bn_whisper",
                chatType = "BN_WHISPER",
                shortKey = "STREAM_BATTLENET_SHORT",
                label = L["STREAM_BATTLENET_LABEL"],

                events = { "CHAT_MSG_BN_WHISPER", "CHAT_MSG_BN_WHISPER_INFORM" },
                order = 66,
                defaultPinned = false,
                defaultBindings = { left = "send" },
            },
        }
    },

    -- =====================================================================
    -- [NOTICE] 纯通知类消息流（系统生成、无发送行为）
    -- 默认能力：defaultPinned = false, defaultSnapshotted = false
    -- =====================================================================
    NOTICE = {
        -- [LOG] 日志类（经验、物品、货币）
        -- 保留结构供未来扩展
        LOG = {},

        -- [SYSTEM] 系统提示
        -- 保留结构供未来扩展
        SYSTEM = {},

        -- [ALERT] 警告类（Boss喊话、表情）
        -- 保留结构供未来扩展
        ALERT = {}
    }
}

-- =========================================================================
-- Action Implementation Helpers
-- 这些函数被 Libs/Registry/Actions.lua 中的 ACTION_DEFINITIONS 调用
-- 它们封装了底层的 WoW API 调用逻辑
--
-- Action Semantics (Do not regress):
-- 1) User-triggered channel actions from Shelf are ALWAYS available:
--    - ActionSend: open chat input for a stream/channel
--    - ActionJoin: manual join channel
--    - ActionLeave: manual leave channel
-- 2) Policy capability EMIT_CHAT_ACTION gates AUTOMATED emissions only
--    (e.g., AutoWelcome / AutoJoinHelper / background sends), not manual Shelf actions.
-- =========================================================================

local SLASH_COMMANDS = {
    ["INSTANCE_CHAT"] = "instance",
    ["RAID_WARNING"] = "rw",
    ["BATTLEGROUND"] = "bg",
    ["GUILD"] = "guild",
    ["OFFICER"] = "officer",
    ["PARTY"] = "party",
    ["RAID"] = "raid",
    ["SAY"] = "say",
    ["YELL"] = "yell",
    ["EMOTE"] = "e",
}

function addon:ActionSend(chatType, channelKey, channelName)
    -- User-triggered channel switch from Shelf should remain available in all modes.
    -- This action only opens chat input (or routes to a joined channel), and is not
    -- treated as background/automated emission.
    if chatType == "CHANNEL" and channelName then
        local id = GetChannelName(channelName)
        if id and id > 0 then
            ChatFrame_OpenChat("/" .. id .. " ")
        else
            if channelName then
                JoinChannelByName(channelName)
            end
        end
    else
        local cmd = SLASH_COMMANDS[chatType] or string.lower(chatType)
        ChatFrame_OpenChat("/" .. cmd .. " ")
    end
end

function addon:ActionJoin(channelName)
    -- User-triggered channel management from Shelf should remain available in all modes.
    if channelName then JoinChannelByName(channelName) end
end

function addon:ActionLeave(channelName)
    -- User-triggered channel management from Shelf should remain available in all modes.
    if channelName then LeaveChannelByName(channelName) end
end
