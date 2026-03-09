local addonName, addon = ...
local OpenChat = _G["Chat" .. "Frame_OpenChat"]
local PRI_BASE = addon.PRIORITY_BASE or {}
local PRI_STEP = addon.PRIORITY_STEP or 10

local CAPS_CHANNEL_SYSTEM = {
    inbound = true, outbound = true, snapshotDefault = true, copyDefault = true,
    supportsMute = true, supportsAutoJoin = false, pinnable = true,
}
local CAPS_CHANNEL_DYNAMIC = {
    inbound = true, outbound = true, snapshotDefault = true, copyDefault = true,
    supportsMute = true, supportsAutoJoin = true, pinnable = true,
}
local CAPS_CHANNEL_PRIVATE = {
    inbound = true, outbound = true, snapshotDefault = true, copyDefault = true,
    supportsMute = false, supportsAutoJoin = false, pinnable = false,
}
local CAPS_NOTICE_SYSTEM = {
    inbound = true, outbound = false, snapshotDefault = true, copyDefault = true,
    supportsMute = false, supportsAutoJoin = false, pinnable = false,
}
local CAPS_NOTICE_ALERT = {
    inbound = true, outbound = false, snapshotDefault = false, copyDefault = false,
    supportsMute = false, supportsAutoJoin = false, pinnable = false,
}

local function CopyCaps(caps)
    local out = {}
    for key, value in pairs(caps or {}) do
        out[key] = value == true
    end
    return out
end

local function BuildStreamList(kind, group, caps, streams)
    for _, stream in ipairs(streams or {}) do
        stream.kind = kind
        stream.group = group
        stream.capabilities = CopyCaps(caps)
        if stream.capabilities.supportsMute == true then
            stream.defaultBindings = stream.defaultBindings or {}
            if stream.defaultBindings.right == nil then
                stream.defaultBindings.right = "mute_toggle"
            end
        end
        stream.defaultPinned = stream.capabilities.pinnable == true
        stream.defaultSnapshotted = stream.capabilities.snapshotDefault == true
        stream.defaultCopyable = stream.capabilities.copyDefault == true
        stream.isInboundOnly = stream.capabilities.outbound ~= true
        if stream.capabilities.supportsAutoJoin == true then
            stream.defaultAutoJoin = stream.defaultAutoJoin == true
        else
            stream.defaultAutoJoin = nil
        end
    end
    return streams
end

-- STREAM_REGISTRY
-- 消息流层级注册表 - Stream > Channel / Notice 架构
-- 流默认行为由显式 schema 字段声明（defaultPinned/defaultSnapshotted/defaultAutoJoin）

addon.STREAM_REGISTRY = {
    -- [CHANNEL] 具备交互能力的消息流（发送、粘滞、编号）
    -- 默认能力：defaultPinned = true, defaultSnapshotted = true
    CHANNEL = {
        -- [SYSTEM] 系统内置频道
        SYSTEM = BuildStreamList("channel", "system", CAPS_CHANNEL_SYSTEM, {
            {
                key = "say",
                wowChatType = "SAY",
                identity = {
                    labelKey = "STREAM_SAY_LABEL",
                    shortOneKey = "STREAM_SAY_SHORT_ONE",
                    shortTwoKey = "STREAM_SAY_SHORT_TWO",
                },

                events = { "CHAT_MSG_SAY" },
                priority = (PRI_BASE.SYSTEM or 100) + PRI_STEP * 0,
                defaultPinned = true,
                defaultSnapshotted = true,
                defaultCopyable = true,
                isInboundOnly = false,
                defaultBindings = { left = "send" },
            },
            {
                key = "yell",
                wowChatType = "YELL",
                identity = {
                    labelKey = "STREAM_YELL_LABEL",
                    shortOneKey = "STREAM_YELL_SHORT_ONE",
                    shortTwoKey = "STREAM_YELL_SHORT_TWO",
                },

                events = { "CHAT_MSG_YELL" },
                priority = (PRI_BASE.SYSTEM or 100) + PRI_STEP * 1,
                defaultPinned = true,
                defaultSnapshotted = true,
                defaultCopyable = true,
                isInboundOnly = false,
                defaultBindings = { left = "send" },
            },
            {
                key = "guild",
                wowChatType = "GUILD",
                identity = {
                    labelKey = "STREAM_GUILD_LABEL",
                    shortOneKey = "STREAM_GUILD_SHORT_ONE",
                    shortTwoKey = "STREAM_GUILD_SHORT_TWO",
                },

                events = { "CHAT_MSG_GUILD" },
                priority = (PRI_BASE.SYSTEM or 100) + PRI_STEP * 2,
                defaultPinned = true,
                defaultSnapshotted = true,
                defaultCopyable = true,
                isInboundOnly = false,
                defaultBindings = { left = "send" },
            },
            {
                key = "officer",
                wowChatType = "OFFICER",
                identity = {
                    labelKey = "STREAM_OFFICER_LABEL",
                    shortOneKey = "STREAM_OFFICER_SHORT_ONE",
                    shortTwoKey = "STREAM_OFFICER_SHORT_TWO",
                },

                events = { "CHAT_MSG_OFFICER" },
                priority = (PRI_BASE.SYSTEM or 100) + PRI_STEP * 3,
                defaultPinned = true,
                defaultSnapshotted = true,
                defaultCopyable = true,
                isInboundOnly = false,
                defaultBindings = { left = "send" },
            },
            {
                key = "party",
                wowChatType = "PARTY",
                identity = {
                    labelKey = "STREAM_PARTY_LABEL",
                    shortOneKey = "STREAM_PARTY_SHORT_ONE",
                    shortTwoKey = "STREAM_PARTY_SHORT_TWO",
                },

                events = { "CHAT_MSG_PARTY", "CHAT_MSG_PARTY_LEADER" },
                priority = (PRI_BASE.SYSTEM or 100) + PRI_STEP * 4,
                defaultPinned = true,
                defaultSnapshotted = true,
                defaultCopyable = true,
                isInboundOnly = false,
                defaultBindings = { left = "send" },
            },
            {
                key = "instance",
                wowChatType = "INSTANCE_CHAT",
                identity = {
                    labelKey = "STREAM_INSTANCE_LABEL",
                    shortOneKey = "STREAM_INSTANCE_SHORT_ONE",
                    shortTwoKey = "STREAM_INSTANCE_SHORT_TWO",
                },

                events = { "CHAT_MSG_INSTANCE_CHAT", "CHAT_MSG_INSTANCE_CHAT_LEADER" },
                priority = (PRI_BASE.SYSTEM or 100) + PRI_STEP * 5,
                defaultPinned = true,
                defaultSnapshotted = true,
                defaultCopyable = true,
                isInboundOnly = false,
                defaultBindings = { left = "send" },
            },
            {
                key = "raid",
                wowChatType = "RAID",
                identity = {
                    labelKey = "STREAM_RAID_LABEL",
                    shortOneKey = "STREAM_RAID_SHORT_ONE",
                    shortTwoKey = "STREAM_RAID_SHORT_TWO",
                },

                events = { "CHAT_MSG_RAID", "CHAT_MSG_RAID_LEADER" },
                priority = (PRI_BASE.SYSTEM or 100) + PRI_STEP * 6,
                defaultPinned = true,
                defaultSnapshotted = true,
                defaultCopyable = true,
                isInboundOnly = false,
                defaultBindings = { left = "send" },
            },
            {
                key = "raid_warning",
                wowChatType = "RAID_WARNING",
                identity = {
                    labelKey = "STREAM_RAID_WARNING_LABEL",
                    shortOneKey = "STREAM_RAID_WARNING_SHORT_ONE",
                    shortTwoKey = "STREAM_RAID_WARNING_SHORT_TWO",
                },

                events = { "CHAT_MSG_RAID_WARNING" },
                priority = (PRI_BASE.SYSTEM or 100) + PRI_STEP * 7,
                defaultPinned = true,
                defaultSnapshotted = true,
                defaultCopyable = true,
                isInboundOnly = false,
                defaultBindings = { left = "send" },
            },
            {
                key = "battleground",
                wowChatType = "BATTLEGROUND",
                identity = {
                    labelKey = "STREAM_BATTLEGROUND_LABEL",
                    shortOneKey = "STREAM_BATTLEGROUND_SHORT_ONE",
                    shortTwoKey = "STREAM_BATTLEGROUND_SHORT_TWO",
                },

                -- Retail does not provide stable CHAT_MSG_BATTLEGROUND* frame events
                -- for this pipeline. Keep action support (/bg), but do not subscribe.
                events = {},
                priority = (PRI_BASE.SYSTEM or 100) + PRI_STEP * 8,
                defaultPinned = true,
                defaultSnapshotted = true,
                defaultCopyable = true,
                isInboundOnly = false,
                defaultBindings = { left = "send" },
            },
            {
                key = "emote",
                wowChatType = "EMOTE",
                identity = {
                    labelKey = "STREAM_EMOTE_LABEL",
                    shortOneKey = "STREAM_EMOTE_SHORT_ONE",
                    shortTwoKey = "STREAM_EMOTE_SHORT_TWO",
                },

                events = { "CHAT_MSG_EMOTE", "CHAT_MSG_TEXT_EMOTE" },
                priority = (PRI_BASE.SYSTEM or 100) + PRI_STEP * 9,
                defaultPinned = true,
                defaultSnapshotted = true,
                defaultCopyable = true,
                isInboundOnly = false,
                defaultBindings = { left = "send" },
            },
        }),

        -- [DYNAMIC] 动态加入频道（需要服务器ID）
        -- Shelf availability detection is intentionally scoped to this group only.
        DYNAMIC = BuildStreamList("channel", "dynamic", CAPS_CHANNEL_DYNAMIC, {
            {
                key = "general",
                wowChatType = "CHANNEL",
                identity = {
                    labelKey = "STREAM_GENERAL_LABEL",
                    shortOneKey = "STREAM_GENERAL_SHORT_ONE",
                    shortTwoKey = "STREAM_GENERAL_SHORT_TWO",
                    candidatesId = "general",
                },

                events = { "CHAT_MSG_CHANNEL" },
                priority = (PRI_BASE.DYNAMIC or 200) + PRI_STEP * 0,
                defaultPinned = true,
                defaultSnapshotted = true,
                defaultCopyable = true,
                isInboundOnly = false,
                defaultAutoJoin = true,
                defaultBindings = { left = "send", right = "mute_toggle" },
            },
            {
                key = "trade",
                wowChatType = "CHANNEL",
                identity = {
                    labelKey = "STREAM_TRADE_LABEL",
                    shortOneKey = "STREAM_TRADE_SHORT_ONE",
                    shortTwoKey = "STREAM_TRADE_SHORT_TWO",
                    candidatesId = "trade",
                },

                events = { "CHAT_MSG_CHANNEL" },
                priority = (PRI_BASE.DYNAMIC or 200) + PRI_STEP * 1,
                defaultPinned = true,
                defaultSnapshotted = true,
                defaultCopyable = true,
                isInboundOnly = false,
                defaultAutoJoin = true,
                defaultBindings = { left = "send", right = "mute_toggle" },
            },
            {
                key = "localdefense",
                wowChatType = "CHANNEL",
                identity = {
                    labelKey = "STREAM_LOCALDEFENSE_LABEL",
                    shortOneKey = "STREAM_LOCALDEFENSE_SHORT_ONE",
                    shortTwoKey = "STREAM_LOCALDEFENSE_SHORT_TWO",
                    candidatesId = "localdefense",
                },

                events = { "CHAT_MSG_CHANNEL" },
                priority = (PRI_BASE.DYNAMIC or 200) + PRI_STEP * 2,
                defaultPinned = true,
                defaultSnapshotted = true,
                defaultCopyable = true,
                isInboundOnly = false,
                defaultAutoJoin = true,
                defaultBindings = { left = "send", right = "mute_toggle" },
            },
            {
                key = "services",
                wowChatType = "CHANNEL",
                identity = {
                    labelKey = "STREAM_SERVICES_LABEL",
                    shortOneKey = "STREAM_SERVICES_SHORT_ONE",
                    shortTwoKey = "STREAM_SERVICES_SHORT_TWO",
                    candidatesId = "services",
                },

                events = { "CHAT_MSG_CHANNEL" },
                priority = (PRI_BASE.DYNAMIC or 200) + PRI_STEP * 3,
                defaultPinned = true,
                defaultSnapshotted = true,
                defaultCopyable = true,
                isInboundOnly = false,
                defaultAutoJoin = true,
                defaultBindings = { left = "send", right = "mute_toggle" },
            },
            {
                key = "lfg",
                wowChatType = "CHANNEL",
                identity = {
                    labelKey = "STREAM_LFG_LABEL",
                    shortOneKey = "STREAM_LFG_SHORT_ONE",
                    shortTwoKey = "STREAM_LFG_SHORT_TWO",
                    candidatesId = "lfg",
                },

                events = { "CHAT_MSG_CHANNEL" },
                priority = (PRI_BASE.DYNAMIC or 200) + PRI_STEP * 4,
                defaultPinned = true,
                defaultSnapshotted = true,
                defaultCopyable = true,
                isInboundOnly = false,
                defaultAutoJoin = true,
                defaultBindings = { left = "send", right = "mute_toggle" },
            },
            {
                key = "world",
                wowChatType = "CHANNEL",
                identity = {
                    labelKey = "STREAM_WORLD_LABEL",
                    shortOneKey = "STREAM_WORLD_SHORT_ONE",
                    shortTwoKey = "STREAM_WORLD_SHORT_TWO",
                    candidatesId = "world",
                },

                events = { "CHAT_MSG_CHANNEL" },
                priority = (PRI_BASE.DYNAMIC or 200) + PRI_STEP * 5,
                defaultPinned = true,
                defaultSnapshotted = true,
                defaultCopyable = true,
                isInboundOnly = false,
                defaultAutoJoin = true,
                defaultBindings = { left = "send", right = "mute_toggle" },
            },
        }),

        -- [PRIVATE] 私聊类频道
        PRIVATE = BuildStreamList("channel", "private", CAPS_CHANNEL_PRIVATE, {
            {
                key = "whisper",
                wowChatType = "WHISPER",
                identity = {
                    labelKey = "STREAM_WHISPER_LABEL",
                    shortOneKey = "STREAM_WHISPER_SHORT_ONE",
                    shortTwoKey = "STREAM_WHISPER_SHORT_TWO",
                },

                events = { "CHAT_MSG_WHISPER", "CHAT_MSG_WHISPER_INFORM" },
                priority = (PRI_BASE.DYNAMIC or 200) + PRI_STEP * 6,
                defaultPinned = false,
                defaultSnapshotted = true,
                defaultCopyable = true,
                isInboundOnly = false,
                defaultBindings = { left = "send" },
            },
        })
    },

    -- [NOTICE] 纯通知类消息流（系统生成、无发送行为）
    -- 默认能力：defaultPinned = false, defaultSnapshotted = false
    NOTICE = {
        -- [LOG] 日志类（经验、物品、货币）
        -- 保留结构供未来扩展
        LOG = {},

        -- [SYSTEM] 系统提示
        SYSTEM = BuildStreamList("notice", "system", CAPS_NOTICE_SYSTEM, {
            {
                key = "system",
                wowChatType = "SYSTEM",
                identity = {
                    labelKey = "STREAM_SYSTEM_NOTICE_LABEL",
                    shortOneKey = "STREAM_SYSTEM_NOTICE_SHORT_ONE",
                    shortTwoKey = "STREAM_SYSTEM_NOTICE_SHORT_TWO",
                },
                events = { "CHAT_MSG_SYSTEM" },
                priority = (PRI_BASE.SYSTEM or 100) + PRI_STEP * 10,
                defaultPinned = false,
                defaultSnapshotted = true,
                defaultCopyable = true,
                isInboundOnly = true,
            },
        }),

        -- [ALERT] 警告类（Boss喊话、表情）
        ALERT = BuildStreamList("notice", "alert", CAPS_NOTICE_ALERT, {
            {
                key = "monster_say",
                wowChatType = "SYSTEM",
                identity = {
                    labelKey = "STREAM_MONSTER_SAY_LABEL",
                    shortOneKey = "STREAM_MONSTER_SAY_SHORT_ONE",
                    shortTwoKey = "STREAM_MONSTER_SAY_SHORT_TWO",
                },
                events = { "CHAT_MSG_MONSTER_SAY" },
                priority = (PRI_BASE.SYSTEM or 100) + PRI_STEP * 20,
                defaultPinned = false,
                defaultSnapshotted = false,
                defaultCopyable = false,
                isInboundOnly = true,
            },
            {
                key = "monster_yell",
                wowChatType = "SYSTEM",
                identity = {
                    labelKey = "STREAM_MONSTER_YELL_LABEL",
                    shortOneKey = "STREAM_MONSTER_YELL_SHORT_ONE",
                    shortTwoKey = "STREAM_MONSTER_YELL_SHORT_TWO",
                },
                events = { "CHAT_MSG_MONSTER_YELL" },
                priority = (PRI_BASE.SYSTEM or 100) + PRI_STEP * 21,
                defaultPinned = false,
                defaultSnapshotted = false,
                defaultCopyable = false,
                isInboundOnly = true,
            },
            {
                key = "monster_emote",
                wowChatType = "SYSTEM",
                identity = {
                    labelKey = "STREAM_MONSTER_EMOTE_LABEL",
                    shortOneKey = "STREAM_MONSTER_EMOTE_SHORT_ONE",
                    shortTwoKey = "STREAM_MONSTER_EMOTE_SHORT_TWO",
                },
                events = { "CHAT_MSG_MONSTER_EMOTE" },
                priority = (PRI_BASE.SYSTEM or 100) + PRI_STEP * 22,
                defaultPinned = false,
                defaultSnapshotted = false,
                defaultCopyable = false,
                isInboundOnly = true,
            },
            {
                key = "monster_whisper",
                wowChatType = "SYSTEM",
                identity = {
                    labelKey = "STREAM_MONSTER_WHISPER_LABEL",
                    shortOneKey = "STREAM_MONSTER_WHISPER_SHORT_ONE",
                    shortTwoKey = "STREAM_MONSTER_WHISPER_SHORT_TWO",
                },
                events = { "CHAT_MSG_MONSTER_WHISPER" },
                priority = (PRI_BASE.SYSTEM or 100) + PRI_STEP * 23,
                defaultPinned = false,
                defaultSnapshotted = false,
                defaultCopyable = false,
                isInboundOnly = true,
            },
            {
                key = "monster_party",
                wowChatType = "SYSTEM",
                identity = {
                    labelKey = "STREAM_MONSTER_PARTY_LABEL",
                    shortOneKey = "STREAM_MONSTER_PARTY_SHORT_ONE",
                    shortTwoKey = "STREAM_MONSTER_PARTY_SHORT_TWO",
                },
                events = { "CHAT_MSG_MONSTER_PARTY" },
                priority = (PRI_BASE.SYSTEM or 100) + PRI_STEP * 24,
                defaultPinned = false,
                defaultSnapshotted = false,
                defaultCopyable = false,
                isInboundOnly = true,
            },
            {
                key = "raid_boss_emote",
                wowChatType = "SYSTEM",
                identity = {
                    labelKey = "STREAM_RAID_BOSS_EMOTE_LABEL",
                    shortOneKey = "STREAM_RAID_BOSS_EMOTE_SHORT_ONE",
                    shortTwoKey = "STREAM_RAID_BOSS_EMOTE_SHORT_TWO",
                },
                events = { "CHAT_MSG_RAID_BOSS_EMOTE" },
                priority = (PRI_BASE.SYSTEM or 100) + PRI_STEP * 25,
                defaultPinned = false,
                defaultSnapshotted = false,
                defaultCopyable = false,
                isInboundOnly = true,
            },
            {
                key = "raid_boss_whisper",
                wowChatType = "SYSTEM",
                identity = {
                    labelKey = "STREAM_RAID_BOSS_WHISPER_LABEL",
                    shortOneKey = "STREAM_RAID_BOSS_WHISPER_SHORT_ONE",
                    shortTwoKey = "STREAM_RAID_BOSS_WHISPER_SHORT_TWO",
                },
                events = { "CHAT_MSG_RAID_BOSS_WHISPER" },
                priority = (PRI_BASE.SYSTEM or 100) + PRI_STEP * 26,
                defaultPinned = false,
                defaultSnapshotted = false,
                defaultCopyable = false,
                isInboundOnly = true,
            },
        })
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

function addon:OpenChatForActionSend(payload)
    local data = type(payload) == "table" and payload or {}
    local wowChatType = data.wowChatType
    if type(wowChatType) ~= "string" or wowChatType == "" then
        return false, "payload_invalid"
    end

    if wowChatType == "CHANNEL" then
        local id = tonumber(data.channelId) or nil
        if not id or id <= 0 then
            return false, "target_unresolved"
        end
        OpenChat("/" .. id .. " ")
        return true
    end

    local cmd
    if wowChatType == "WHISPER" then
        cmd = "w"
    else
        cmd = SLASH_COMMANDS[wowChatType] or string.lower(wowChatType)
    end
    OpenChat("/" .. cmd .. " ")
    return true
end
