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
                colors = {
                    white = {1, 1, 1, 1},
                    blizzard = {1, 0.82, 0, 1},
                    rainbow = {1, 1, 1, 1},
                },
                events = { "CHAT_MSG_SAY" },
                order = 10, 
                defaultBindings = { left = "send" }, 
            },
            { 
                key = "yell", 
                chatType = "YELL", 
                shortKey = "STREAM_YELL_SHORT", 
                label = L["STREAM_YELL_LABEL"], 
                colors = {
                    white = {1, 1, 1, 1},
                    blizzard = {1, 0.82, 0, 1},
                    rainbow = {1, 0.25, 0.25, 1},
                },
                events = { "CHAT_MSG_YELL" },
                order = 20, 
                defaultBindings = { left = "send" }, 
            },
            { 
                key = "party", 
                chatType = "PARTY", 
                shortKey = "STREAM_PARTY_SHORT", 
                label = L["STREAM_PARTY_LABEL"], 
                colors = {
                    white = {1, 1, 1, 1},
                    blizzard = {1, 0.82, 0, 1},
                    rainbow = {0.67, 0.67, 1, 1},
                },
                events = { "CHAT_MSG_PARTY", "CHAT_MSG_PARTY_LEADER" },
                order = 40, 
                defaultBindings = { left = "send" }, 
            },
            { 
                key = "raid", 
                chatType = "RAID", 
                shortKey = "STREAM_RAID_SHORT", 
                label = L["STREAM_RAID_LABEL"], 
                colors = {
                    white = {1, 1, 1, 1},
                    blizzard = {1, 0.82, 0, 1},
                    rainbow = {1, 0.5, 0, 1},
                },
                events = { "CHAT_MSG_RAID", "CHAT_MSG_RAID_LEADER", "CHAT_MSG_RAID_WARNING" },
                order = 50, 
                defaultBindings = { left = "send" }, 
            },
            { 
                key = "instance", 
                chatType = "INSTANCE_CHAT", 
                shortKey = "STREAM_INSTANCE_SHORT", 
                label = L["STREAM_INSTANCE_LABEL"], 
                colors = {
                    white = {1, 1, 1, 1},
                    blizzard = {1, 0.82, 0, 1},
                    rainbow = {1, 0.5, 0, 1},
                },
                events = { "CHAT_MSG_INSTANCE_CHAT", "CHAT_MSG_INSTANCE_CHAT_LEADER" },
                order = 60, 
                defaultBindings = { left = "send" }, 
            },
            { 
                key = "battleground", 
                chatType = "BATTLEGROUND", 
                shortKey = "STREAM_BATTLEGROUND_SHORT", 
                label = L["STREAM_BATTLEGROUND_LABEL"], 
                colors = {
                    white = {1, 1, 1, 1},
                    blizzard = {1, 0.82, 0, 1},
                    rainbow = {1, 0.5, 0, 1},
                },
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
                colors = {
                    white = {1, 1, 1, 1},
                    blizzard = {1, 0.82, 0, 1},
                    rainbow = {0.25, 1, 0.25, 1},
                },
                events = { "CHAT_MSG_GUILD" },
                order = 70, 
                defaultBindings = { left = "send" }, 
            },
            { 
                key = "officer", 
                chatType = "OFFICER", 
                shortKey = "STREAM_OFFICER_SHORT", 
                label = L["STREAM_OFFICER_LABEL"], 
                colors = {
                    white = {1, 1, 1, 1},
                    blizzard = {1, 0.82, 0, 1},
                    rainbow = {0.25, 0.75, 0.25, 1},
                },
                events = { "CHAT_MSG_OFFICER" },
                requiresAvailabilityCheck = true, 
                order = 80, 
                defaultPinned = false,
                defaultBindings = { left = "send" }, 
            },
            { 
                key = "emote", 
                chatType = "EMOTE", 
                shortKey = "STREAM_EMOTE_SHORT", 
                label = L["STREAM_EMOTE_LABEL"], 
                colors = {
                    white = {1, 1, 1, 1},
                    blizzard = {1, 0.82, 0, 1},
                    rainbow = {1, 0.5, 0, 1},
                },
                events = { "CHAT_MSG_EMOTE", "CHAT_MSG_TEXT_EMOTE" },
                order = 85, 
                defaultPinned = false,
                defaultBindings = { left = "send" }, 
            },
        },
        
        -- [DYNAMIC] 动态加入频道（需要服务器ID）
        DYNAMIC = {
            { 
                key = "general", 
                chatType = "CHANNEL", 
                mappingKey = "STREAM_GENERAL_MAPPING", 
                shortKey = "STREAM_GENERAL_SHORT", 
                label = L["STREAM_GENERAL_LABEL"], 
                colors = { white = {1, 1, 1, 1}, blizzard = {1, 0.82, 0, 1}, rainbow = {0.8, 1, 0.8, 1} },
                events = { "CHAT_MSG_CHANNEL" },
                requiresAvailabilityCheck = true, 
                order = 90, 
                defaultAutoJoin = true,
                defaultBindings = { left = "send", right = "leave" },
            },
            { 
                key = "trade", 
                chatType = "CHANNEL", 
                mappingKey = "STREAM_TRADE_MAPPING", 
                shortKey = "STREAM_TRADE_SHORT", 
                label = L["STREAM_TRADE_LABEL"], 
                colors = { white = {1, 1, 1, 1}, blizzard = {1, 0.82, 0, 1}, rainbow = {1, 0.8, 0.8, 1} },
                events = { "CHAT_MSG_CHANNEL" },
                requiresAvailabilityCheck = true, 
                order = 91, 
                defaultAutoJoin = true,
                defaultBindings = { left = "send", right = "leave" },
            },
            { 
                key = "localdefense", 
                chatType = "CHANNEL", 
                mappingKey = "STREAM_LOCALDEFENSE_MAPPING", 
                shortKey = "STREAM_LOCALDEFENSE_SHORT", 
                label = L["STREAM_LOCALDEFENSE_LABEL"], 
                colors = { white = {1, 1, 1, 1}, blizzard = {1, 0.82, 0, 1}, rainbow = {0.8, 0.8, 1, 1} },
                events = { "CHAT_MSG_CHANNEL" },
                requiresAvailabilityCheck = true, 
                order = 92, 
                defaultPinned = false,
                defaultAutoJoin = true,
                defaultBindings = { left = "send", right = "leave" },
            },
            { 
                key = "lfg", 
                chatType = "CHANNEL", 
                mappingKey = "STREAM_LFG_MAPPING", 
                shortKey = "STREAM_LFG_SHORT", 
                label = L["STREAM_LFG_LABEL"], 
                colors = { white = {1, 1, 1, 1}, blizzard = {1, 0.82, 0, 1}, rainbow = {1, 1, 0.8, 1} },
                events = { "CHAT_MSG_CHANNEL" },
                requiresAvailabilityCheck = true, 
                order = 93, 
                defaultAutoJoin = true,
                defaultBindings = { left = "send", right = "leave" },
            },
            { 
                key = "services", 
                chatType = "CHANNEL", 
                mappingKey = "STREAM_SERVICES_MAPPING", 
                shortKey = "STREAM_SERVICES_SHORT", 
                label = L["STREAM_SERVICES_LABEL"], 
                colors = { white = {1, 1, 1, 1}, blizzard = {1, 0.82, 0, 1}, rainbow = {0.8, 1, 1, 1} },
                events = { "CHAT_MSG_CHANNEL" },
                requiresAvailabilityCheck = true, 
                order = 94, 
                defaultPinned = false,
                defaultAutoJoin = true,
                defaultBindings = { left = "send", right = "leave" },
            },
            { 
                key = "world", 
                chatType = "CHANNEL", 
                mappingKey = "STREAM_WORLD_MAPPING", 
                shortKey = "STREAM_WORLD_SHORT", 
                label = L["STREAM_WORLD_LABEL"], 
                colors = {
                    white = {1, 1, 1, 1},
                    blizzard = {1, 0.82, 0, 1},
                    rainbow = {0.8, 0.8, 1, 1},
                },
                events = { "CHAT_MSG_CHANNEL" },
                requiresAvailabilityCheck = true, 
                order = 100, 
                defaultAutoJoin = true, 
                defaultBindings = { left = "send", right = "leave" }, 
            },
            { 
                key = "worlddefense", 
                chatType = "CHANNEL", 
                mappingKey = "STREAM_WORLDDEFENSE_MAPPING", 
                shortKey = "STREAM_WORLDDEFENSE_SHORT", 
                label = L["STREAM_WORLDDEFENSE_LABEL"], 
                colors = { white = {1, 1, 1, 1}, blizzard = {1, 0.82, 0, 1}, rainbow = {1, 0.5, 0.5, 1} },
                events = { "CHAT_MSG_CHANNEL" },
                requiresAvailabilityCheck = true, 
                order = 101, 
                defaultPinned = false,
                defaultAutoJoin = true,
                defaultBindings = { left = "send", right = "leave" },
            },
            { 
                key = "beginner", 
                chatType = "CHANNEL", 
                mappingKey = "STREAM_BEGINNER_MAPPING", 
                shortKey = "STREAM_BEGINNER_SHORT", 
                label = L["STREAM_BEGINNER_LABEL"], 
                colors = { white = {1, 1, 1, 1}, blizzard = {1, 0.82, 0, 1}, rainbow = {0.5, 1, 0.5, 1} },
                events = { "CHAT_MSG_CHANNEL" },
                requiresAvailabilityCheck = true, 
                order = 102, 
                defaultPinned = false,
                defaultAutoJoin = true,
                defaultBindings = { left = "send", right = "leave" },
            },
            { 
                key = "guildrecruit", 
                chatType = "CHANNEL", 
                mappingKey = "STREAM_GUILDRECRUITMENT_MAPPING", 
                shortKey = "STREAM_GUILDRECRUITMENT_SHORT", 
                label = L["STREAM_GUILDRECRUITMENT_LABEL"], 
                colors = { white = {1, 1, 1, 1}, blizzard = {1, 0.82, 0, 1}, rainbow = {0.5, 0.7, 1, 1} },
                events = { "CHAT_MSG_CHANNEL" },
                requiresAvailabilityCheck = true, 
                order = 103, 
                defaultPinned = false,
                defaultAutoJoin = true,
                defaultBindings = { left = "send", right = "leave" },
            },
        },
        
        -- [PRIVATE] 私聊类频道
        PRIVATE = {
            { 
                key = "whisper", 
                chatType = "WHISPER", 
                shortKey = "STREAM_WHISPER_SHORT", 
                label = L["STREAM_WHISPER_LABEL"], 
                colors = {
                    white = {1, 1, 1, 1},
                    blizzard = {1, 0.82, 0, 1},
                    rainbow = {1, 0.5, 1, 1},
                },
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
                colors = {
                    white = {1, 1, 1, 1},
                    blizzard = {1, 0.82, 0, 1},
                    rainbow = {1, 0.5, 1, 1},
                },
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
        LOG = {
            -- 待扩展：Experience, Loot, Money, Reputation, Skill
        },
        
        -- [SYSTEM] 系统提示
        SYSTEM = {
            -- 待扩展：System messages, Achievements
        },
        
        -- [ALERT] 警告类（Boss喊话、表情）
        ALERT = {
            -- 待扩展：RAID_BOSS_EMOTE, CHAT_MSG_MONSTER_YELL
            -- 这些项需要标记 isCombatProtected = true
        }
    }
}

-- =========================================================================
-- Helper Functions (保留用于兼容旧的 ACTION 调用)
-- =========================================================================

function addon:ActionSend(chatType, channelKey, channelName)
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
        ChatFrame_OpenChat("/" .. string.lower(chatType) .. " ")
    end
end

function addon:ActionJoin(channelName)
    if channelName then JoinChannelByName(channelName) end
end

function addon:ActionLeave(channelName)
    if channelName then LeaveChannelByName(channelName) end
end
