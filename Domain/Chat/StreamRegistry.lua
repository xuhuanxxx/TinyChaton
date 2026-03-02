local addonName, addon = ...
local OpenChat = _G["Chat" .. "Frame_OpenChat"]
local L = addon.L
local PRI_BASE = addon.PRIORITY_BASE or {}
local PRI_STEP = addon.PRIORITY_STEP or 10

-- STREAM_REGISTRY
-- 消息流层级注册表 - Stream > Channel / Notice 架构
-- 通过嵌套结构隐式推导能力，移除扁平布尔标志

addon.STREAM_REGISTRY = {
    -- [CHANNEL] 具备交互能力的消息流（发送、粘滞、编号）
    -- 默认能力：defaultPinned = true, defaultSnapshotted = true
    CHANNEL = {
        -- [SYSTEM] 系统内置频道
        SYSTEM = {
            {
                key = "say",
                chatType = "SAY",
                shortKey = "STREAM_SAY_SHORT",
                label = L["STREAM_SAY_LABEL"],

                events = { "CHAT_MSG_SAY" },
                priority = (PRI_BASE.SYSTEM or 100) + PRI_STEP * 0,
                defaultBindings = { left = "send" },
            },
            {
                key = "yell",
                chatType = "YELL",
                shortKey = "STREAM_YELL_SHORT",
                label = L["STREAM_YELL_LABEL"],

                events = { "CHAT_MSG_YELL" },
                priority = (PRI_BASE.SYSTEM or 100) + PRI_STEP * 1,
                defaultBindings = { left = "send" },
            },
            {
                key = "guild",
                chatType = "GUILD",
                shortKey = "STREAM_GUILD_SHORT",
                label = L["STREAM_GUILD_LABEL"],

                events = { "CHAT_MSG_GUILD" },
                priority = (PRI_BASE.SYSTEM or 100) + PRI_STEP * 2,
                defaultBindings = { left = "send" },
            },
            {
                key = "officer",
                chatType = "OFFICER",
                shortKey = "STREAM_OFFICER_SHORT",
                label = L["STREAM_OFFICER_LABEL"],

                events = { "CHAT_MSG_OFFICER" },
                priority = (PRI_BASE.SYSTEM or 100) + PRI_STEP * 3,
                defaultBindings = { left = "send" },
            },
            {
                key = "party",
                chatType = "PARTY",
                shortKey = "STREAM_PARTY_SHORT",
                label = L["STREAM_PARTY_LABEL"],

                events = { "CHAT_MSG_PARTY", "CHAT_MSG_PARTY_LEADER" },
                priority = (PRI_BASE.SYSTEM or 100) + PRI_STEP * 4,
                defaultBindings = { left = "send" },
            },
            {
                key = "instance",
                chatType = "INSTANCE_CHAT",
                shortKey = "STREAM_INSTANCE_SHORT",
                label = L["STREAM_INSTANCE_LABEL"],

                events = { "CHAT_MSG_INSTANCE_CHAT", "CHAT_MSG_INSTANCE_CHAT_LEADER" },
                priority = (PRI_BASE.SYSTEM or 100) + PRI_STEP * 5,
                defaultBindings = { left = "send" },
            },
            {
                key = "raid",
                chatType = "RAID",
                shortKey = "STREAM_RAID_SHORT",
                label = L["STREAM_RAID_LABEL"],

                events = { "CHAT_MSG_RAID", "CHAT_MSG_RAID_LEADER" },
                priority = (PRI_BASE.SYSTEM or 100) + PRI_STEP * 6,
                defaultBindings = { left = "send" },
            },
            {
                key = "raid_warning",
                chatType = "RAID_WARNING",
                shortKey = "STREAM_RAID_WARNING_SHORT",
                label = L["STREAM_RAID_WARNING_LABEL"],

                events = { "CHAT_MSG_RAID_WARNING" },
                priority = (PRI_BASE.SYSTEM or 100) + PRI_STEP * 7,
                defaultBindings = { left = "send" },
            },
            {
                key = "battleground",
                chatType = "BATTLEGROUND",
                shortKey = "STREAM_BATTLEGROUND_SHORT",
                label = L["STREAM_BATTLEGROUND_LABEL"],

                -- Retail does not provide stable CHAT_MSG_BATTLEGROUND* frame events
                -- for this pipeline. Keep action support (/bg), but do not subscribe.
                events = {},
                priority = (PRI_BASE.SYSTEM or 100) + PRI_STEP * 8,
                defaultBindings = { left = "send" },
            },
            {
                key = "emote",
                chatType = "EMOTE",
                shortKey = "STREAM_EMOTE_SHORT",
                label = L["STREAM_EMOTE_LABEL"],

                events = { "CHAT_MSG_EMOTE", "CHAT_MSG_TEXT_EMOTE" },
                priority = (PRI_BASE.SYSTEM or 100) + PRI_STEP * 9,
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
                priority = (PRI_BASE.DYNAMIC or 200) + PRI_STEP * 0,
                defaultBindings = { left = "send", right = "mute_toggle" },
            },
            {
                key = "trade",
                chatType = "CHANNEL",
                mappingKey = "STREAM_TRADE_MAPPING",
                shortKey = "STREAM_TRADE_SHORT",
                label = L["STREAM_TRADE_LABEL"],

                events = { "CHAT_MSG_CHANNEL" },
                priority = (PRI_BASE.DYNAMIC or 200) + PRI_STEP * 1,
                defaultBindings = { left = "send", right = "mute_toggle" },
            },
            {
                key = "localdefense",
                chatType = "CHANNEL",
                mappingKey = "STREAM_LOCALDEFENSE_MAPPING",
                shortKey = "STREAM_LOCALDEFENSE_SHORT",
                label = L["STREAM_LOCALDEFENSE_LABEL"],

                events = { "CHAT_MSG_CHANNEL" },
                priority = (PRI_BASE.DYNAMIC or 200) + PRI_STEP * 2,
                defaultBindings = { left = "send", right = "mute_toggle" },
            },
            {
                key = "services",
                chatType = "CHANNEL",
                mappingKey = "STREAM_SERVICES_MAPPING",
                shortKey = "STREAM_SERVICES_SHORT",
                label = L["STREAM_SERVICES_LABEL"],

                events = { "CHAT_MSG_CHANNEL" },
                priority = (PRI_BASE.DYNAMIC or 200) + PRI_STEP * 3,
                defaultBindings = { left = "send", right = "mute_toggle" },
            },
            {
                key = "lfg",
                chatType = "CHANNEL",
                mappingKey = "STREAM_LFG_MAPPING",
                shortKey = "STREAM_LFG_SHORT",
                label = L["STREAM_LFG_LABEL"],

                events = { "CHAT_MSG_CHANNEL" },
                priority = (PRI_BASE.DYNAMIC or 200) + PRI_STEP * 4,
                defaultBindings = { left = "send", right = "mute_toggle" },
            },
            {
                key = "world",
                chatType = "CHANNEL",
                mappingKey = "STREAM_WORLD_MAPPING",
                shortKey = "STREAM_WORLD_SHORT",
                label = L["STREAM_WORLD_LABEL"],

                events = { "CHAT_MSG_CHANNEL" },
                priority = (PRI_BASE.DYNAMIC or 200) + PRI_STEP * 5,
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
                priority = (PRI_BASE.DYNAMIC or 200) + PRI_STEP * 6,
                defaultPinned = false,
                defaultBindings = { left = "send" },
            },
            {
                key = "bn_whisper",
                chatType = "BN_WHISPER",
                shortKey = "STREAM_BATTLENET_SHORT",
                label = L["STREAM_BATTLENET_LABEL"],

                events = { "CHAT_MSG_BN_WHISPER", "CHAT_MSG_BN_WHISPER_INFORM" },
                priority = (PRI_BASE.DYNAMIC or 200) + PRI_STEP * 7,
                defaultPinned = false,
                defaultBindings = { left = "send" },
            },
        }
    },

    -- [NOTICE] 纯通知类消息流（系统生成、无发送行为）
    -- 默认能力：defaultPinned = false, defaultSnapshotted = false
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

-- Action Implementation Helpers
-- 这些函数被 Libs/Registry/Actions.lua 中的 ACTION_DEFINITIONS 调用
-- 它们封装了底层的 WoW API 调用逻辑
--
-- Action Semantics:
-- 1) User-triggered ActionSend from Shelf remains available in all runtime modes.
-- 2) ActionJoin / ActionLeave are intentionally removed from plugin-side channel management.

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
    -- User-triggered channel switch from Shelf remains available in all modes.
    -- This action opens chat input for joined channels.
    if chatType == "CHANNEL" and channelName then
        local id = GetChannelName(channelName)
        if id and id > 0 then
            OpenChat("/" .. id .. " ")
        else
            OpenChat("")
        end
    else
        local cmd = SLASH_COMMANDS[chatType] or string.lower(chatType)
        OpenChat("/" .. cmd .. " ")
    end
end
