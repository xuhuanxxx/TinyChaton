local addonName, addon = ...
local L = addon.L

-- =========================================================================
-- CHANNEL_REGISTRY
-- 频道定义和默认行为配置
-- 每个频道可以定义多种颜色方案
-- =========================================================================

addon.CHANNEL_REGISTRY = {
    { 
        key = "say", 
        chatType = "SAY", 
        shortKey = "CHANNEL_SAY_SHORT", 
        label = L["CHANNEL_SAY"], 
        colors = {
            white = {1, 1, 1, 1},
            blizzard = {1, 0.82, 0, 1},
            rainbow = {1, 1, 1, 1},
        },
        isSystem = true, 
        order = 10, 
        defaultPinned = true, 
        defaultSnapshotted = true, 
        defaultAutoJoin = false, 
        defaultBindings = { left = "send" }, 
        actions = { 
            { key = "send", label = L["ACTION_PREFIX_SEND"] .. L["CHANNEL_SAY"], tooltip = L["TOOLTIP_SEND_TO"], execute = function() addon:ActionSend("SAY") end } 
        } 
    },
    { 
        key = "yell", 
        chatType = "YELL", 
        shortKey = "CHANNEL_YELL_SHORT", 
        label = L["CHANNEL_YELL"], 
        colors = {
            white = {1, 1, 1, 1},
            blizzard = {1, 0.82, 0, 1},
            rainbow = {1, 0.25, 0.25, 1},
        },
        isSystem = true, 
        order = 20, 
        defaultPinned = true, 
        defaultSnapshotted = true, 
        defaultAutoJoin = false, 
        defaultBindings = { left = "send" }, 
        actions = { 
            { key = "send", label = L["ACTION_PREFIX_SEND"] .. L["CHANNEL_YELL"], tooltip = L["TOOLTIP_SEND_TO"], execute = function() addon:ActionSend("YELL") end } 
        } 
    },
    { 
        key = "whisper", 
        chatType = "WHISPER", 
        shortKey = "CHANNEL_WHISPER_SHORT", 
        label = L["CHANNEL_WHISPER"], 
        colors = {
            white = {1, 1, 1, 1},
            blizzard = {1, 0.82, 0, 1},
            rainbow = {1, 0.5, 1, 1},
        },
        isPrivate = true, 
        order = 30, 
        defaultPinned = false, 
        defaultSnapshotted = true, 
        defaultAutoJoin = false, 
        defaultBindings = { left = "send" }, 
        actions = { 
            { key = "send", label = L["ACTION_PREFIX_SEND"] .. L["CHANNEL_WHISPER"], tooltip = L["TOOLTIP_SEND_TO"], execute = function() ChatFrame_OpenChat("/w ") end } 
        } 
    },
    { 
        key = "party", 
        chatType = "PARTY", 
        shortKey = "CHANNEL_PARTY_SHORT", 
        label = L["CHANNEL_PARTY"], 
        colors = {
            white = {1, 1, 1, 1},
            blizzard = {1, 0.82, 0, 1},
            rainbow = {0.67, 0.67, 1, 1},
        },
        isSystem = true, 
        order = 40, 
        defaultPinned = true, 
        defaultSnapshotted = true, 
        defaultAutoJoin = false, 
        defaultBindings = { left = "send" }, 
        actions = { 
            { key = "send", label = L["ACTION_PREFIX_SEND"] .. L["CHANNEL_PARTY"], tooltip = L["TOOLTIP_SEND_TO"], execute = function() addon:ActionSend("PARTY") end } 
        } 
    },
    { 
        key = "raid", 
        chatType = "RAID", 
        shortKey = "CHANNEL_RAID_SHORT", 
        label = L["CHANNEL_RAID"], 
        colors = {
            white = {1, 1, 1, 1},
            blizzard = {1, 0.82, 0, 1},
            rainbow = {1, 0.5, 0, 1},
        },
        isSystem = true, 
        order = 50, 
        defaultPinned = true, 
        defaultSnapshotted = true, 
        defaultAutoJoin = false, 
        defaultBindings = { left = "send" }, 
        actions = { 
            { key = "send", label = L["ACTION_PREFIX_SEND"] .. L["CHANNEL_RAID"], tooltip = L["TOOLTIP_SEND_TO"], execute = function() addon:ActionSend("RAID") end } 
        } 
    },
    { 
        key = "instance", 
        chatType = "INSTANCE_CHAT", 
        shortKey = "CHANNEL_INSTANCE_SHORT", 
        label = L["CHANNEL_INSTANCE"], 
        colors = {
            white = {1, 1, 1, 1},
            blizzard = {1, 0.82, 0, 1},
            rainbow = {1, 0.5, 0, 1},
        },
        isSystem = true, 
        order = 60, 
        defaultPinned = true, 
        defaultSnapshotted = true, 
        defaultAutoJoin = false, 
        defaultBindings = { left = "send" }, 
        actions = { 
            { key = "send", label = L["ACTION_PREFIX_SEND"] .. L["CHANNEL_INSTANCE"], tooltip = L["TOOLTIP_SEND_TO"], execute = function() addon:ActionSend("INSTANCE_CHAT") end } 
        } 
    },
    { 
        key = "battleground", 
        chatType = "BATTLEGROUND", 
        shortKey = "CHANNEL_BATTLEGROUND_SHORT", 
        label = L["CHANNEL_BATTLEGROUND"], 
        colors = {
            white = {1, 1, 1, 1},
            blizzard = {1, 0.82, 0, 1},
            rainbow = {1, 0.5, 0, 1},
        },
        isSystem = true, 
        order = 65, 
        defaultPinned = false, 
        defaultSnapshotted = true, 
        defaultAutoJoin = false, 
        defaultBindings = { left = "send" }, 
        actions = { 
            { key = "send", label = L["ACTION_PREFIX_SEND"] .. L["CHANNEL_BATTLEGROUND"], tooltip = L["TOOLTIP_SEND_TO"], execute = function() addon:ActionSend("BATTLEGROUND") end } 
        } 
    },
    { 
        key = "bn_whisper", 
        chatType = "BN_WHISPER", 
        shortKey = "CHANNEL_BATTLENET_SHORT", 
        label = L["CHANNEL_BATTLENET"], 
        colors = {
            white = {1, 1, 1, 1},
            blizzard = {1, 0.82, 0, 1},
            rainbow = {1, 0.5, 1, 1},
        },
        isPrivate = true, 
        order = 66, 
        defaultPinned = false, 
        defaultSnapshotted = true, 
        defaultAutoJoin = false, 
        defaultBindings = { left = "send" }, 
        actions = { 
            { key = "send", label = L["ACTION_PREFIX_SEND"] .. L["CHANNEL_BATTLENET"], tooltip = L["TOOLTIP_SEND_TO"], execute = function() ChatFrame_OpenChat("/w ") end } 
        } 
    },
    { 
        key = "guild", 
        chatType = "GUILD", 
        shortKey = "CHANNEL_GUILD_SHORT", 
        label = L["CHANNEL_GUILD"], 
        colors = {
            white = {1, 1, 1, 1},
            blizzard = {1, 0.82, 0, 1},
            rainbow = {0.25, 1, 0.25, 1},
        },
        isSystem = true, 
        order = 70, 
        defaultPinned = true, 
        defaultSnapshotted = true, 
        defaultAutoJoin = false, 
        defaultBindings = { left = "send" }, 
        actions = { 
            { key = "send", label = L["ACTION_PREFIX_SEND"] .. L["CHANNEL_GUILD"], tooltip = L["TOOLTIP_SEND_TO"], execute = function() addon:ActionSend("GUILD") end } 
        } 
    },
    { 
        key = "officer", 
        chatType = "OFFICER", 
        shortKey = "CHANNEL_OFFICER_SHORT", 
        label = L["CHANNEL_OFFICER"], 
        colors = {
            white = {1, 1, 1, 1},
            blizzard = {1, 0.82, 0, 1},
            rainbow = {0.25, 0.75, 0.25, 1},
        },
        isSystem = true, 
        requiresAvailabilityCheck = true, 
        order = 80, 
        defaultPinned = false, 
        defaultSnapshotted = true, 
        defaultAutoJoin = false, 
        defaultBindings = { left = "send" }, 
        actions = { 
            { key = "send", label = L["ACTION_PREFIX_SEND"] .. L["CHANNEL_OFFICER"], tooltip = L["TOOLTIP_SEND_TO"], execute = function() addon:ActionSend("OFFICER") end } 
        } 
    },
    { 
        key = "emote", 
        chatType = "EMOTE", 
        shortKey = "CHANNEL_EMOTE_SHORT", 
        label = L["CHANNEL_EMOTE"], 
        colors = {
            white = {1, 1, 1, 1},
            blizzard = {1, 0.82, 0, 1},
            rainbow = {1, 0.5, 0, 1},
        },
        isSystem = true, 
        order = 85, 
        defaultPinned = false, 
        defaultSnapshotted = true, 
        defaultAutoJoin = false, 
        defaultBindings = { left = "send" }, 
        actions = { 
            { key = "send", label = L["ACTION_PREFIX_SEND"] .. L["CHANNEL_EMOTE"], tooltip = L["TOOLTIP_SEND_TO"], execute = function() ChatFrame_OpenChat("/e ") end } 
        } 
    },
    { 
        key = "general", 
        chatType = "CHANNEL", 
        mappingKey = "CHANNEL_GENERAL_MAPPING", 
        shortKey = "CHANNEL_GENERAL_SHORT", 
        label = L["CHANNEL_GENERAL"], 
        colors = { white = {1, 1, 1, 1}, blizzard = {1, 0.82, 0, 1}, rainbow = {0.8, 1, 0.8, 1} },
        isDynamic = true, requiresAvailabilityCheck = true, order = 90, 
        defaultPinned = true, defaultSnapshotted = true, defaultAutoJoin = true,
        defaultBindings = { left = "send", right = "leave" },
        actions = {
            { key = "send", label = L["ACTION_PREFIX_SEND"] .. L["CHANNEL_GENERAL"], tooltip = L["TOOLTIP_SEND_TO"], execute = function() addon:ActionSend("CHANNEL", "general", L["CHANNEL_GENERAL_MAPPING"]) end },
            { key = "join", label = string.format(L["ACTION_JOIN"], L["CHANNEL_GENERAL"]), tooltip = L["TOOLTIP_JOIN"], execute = function() addon:ActionJoin(L["CHANNEL_GENERAL_MAPPING"]) end },
            { key = "leave", label = string.format(L["ACTION_LEAVE"], L["CHANNEL_GENERAL"]), tooltip = L["TOOLTIP_LEAVE"], execute = function() addon:ActionLeave(L["CHANNEL_GENERAL_MAPPING"]) end }
        }
    },
    { 
        key = "trade", 
        chatType = "CHANNEL", 
        mappingKey = "CHANNEL_TRADE_MAPPING", 
        shortKey = "CHANNEL_TRADE_SHORT", 
        label = L["CHANNEL_TRADE"], 
        colors = { white = {1, 1, 1, 1}, blizzard = {1, 0.82, 0, 1}, rainbow = {1, 0.8, 0.8, 1} },
        isDynamic = true, requiresAvailabilityCheck = true, order = 91, 
        defaultPinned = true, defaultSnapshotted = true, defaultAutoJoin = true,
        defaultBindings = { left = "send", right = "leave" },
        actions = {
            { key = "send", label = L["ACTION_PREFIX_SEND"] .. L["CHANNEL_TRADE"], tooltip = L["TOOLTIP_SEND_TO"], execute = function() addon:ActionSend("CHANNEL", "trade", L["CHANNEL_TRADE_MAPPING"]) end },
            { key = "join", label = string.format(L["ACTION_JOIN"], L["CHANNEL_TRADE"]), tooltip = L["TOOLTIP_JOIN"], execute = function() addon:ActionJoin(L["CHANNEL_TRADE_MAPPING"]) end },
            { key = "leave", label = string.format(L["ACTION_LEAVE"], L["CHANNEL_TRADE"]), tooltip = L["TOOLTIP_LEAVE"], execute = function() addon:ActionLeave(L["CHANNEL_TRADE_MAPPING"]) end }
        }
    },
    { 
        key = "localdefense", 
        chatType = "CHANNEL", 
        mappingKey = "CHANNEL_LOCALDEFENSE_MAPPING", 
        shortKey = "CHANNEL_LOCALDEFENSE_SHORT", 
        label = L["CHANNEL_LOCALDEFENSE"], 
        colors = { white = {1, 1, 1, 1}, blizzard = {1, 0.82, 0, 1}, rainbow = {0.8, 0.8, 1, 1} },
        isDynamic = true, requiresAvailabilityCheck = true, order = 92, 
        defaultPinned = false, defaultSnapshotted = true, defaultAutoJoin = true,
        defaultBindings = { left = "send", right = "leave" },
        actions = {
            { key = "send", label = L["ACTION_PREFIX_SEND"] .. L["CHANNEL_LOCALDEFENSE"], tooltip = L["TOOLTIP_SEND_TO"], execute = function() addon:ActionSend("CHANNEL", "localdefense", L["CHANNEL_LOCALDEFENSE_MAPPING"]) end },
            { key = "join", label = string.format(L["ACTION_JOIN"], L["CHANNEL_LOCALDEFENSE"]), tooltip = L["TOOLTIP_JOIN"], execute = function() addon:ActionJoin(L["CHANNEL_LOCALDEFENSE_MAPPING"]) end },
            { key = "leave", label = string.format(L["ACTION_LEAVE"], L["CHANNEL_LOCALDEFENSE"]), tooltip = L["TOOLTIP_LEAVE"], execute = function() addon:ActionLeave(L["CHANNEL_LOCALDEFENSE_MAPPING"]) end }
        }
    },
    { 
        key = "lfg", 
        chatType = "CHANNEL", 
        mappingKey = "CHANNEL_LFG_MAPPING", 
        shortKey = "CHANNEL_LFG_SHORT", 
        label = L["CHANNEL_LFG"], 
        colors = { white = {1, 1, 1, 1}, blizzard = {1, 0.82, 0, 1}, rainbow = {1, 1, 0.8, 1} },
        isDynamic = true, requiresAvailabilityCheck = true, order = 93, 
        defaultPinned = true, defaultSnapshotted = true, defaultAutoJoin = true,
        defaultBindings = { left = "send", right = "leave" },
        actions = {
            { key = "send", label = L["ACTION_PREFIX_SEND"] .. L["CHANNEL_LFG"], tooltip = L["TOOLTIP_SEND_TO"], execute = function() addon:ActionSend("CHANNEL", "lfg", L["CHANNEL_LFG_MAPPING"]) end },
            { key = "join", label = string.format(L["ACTION_JOIN"], L["CHANNEL_LFG"]), tooltip = L["TOOLTIP_JOIN"], execute = function() addon:ActionJoin(L["CHANNEL_LFG_MAPPING"]) end },
            { key = "leave", label = string.format(L["ACTION_LEAVE"], L["CHANNEL_LFG"]), tooltip = L["TOOLTIP_LEAVE"], execute = function() addon:ActionLeave(L["CHANNEL_LFG_MAPPING"]) end }
        }
    },
    { 
        key = "services", 
        chatType = "CHANNEL", 
        mappingKey = "CHANNEL_SERVICES_MAPPING", 
        shortKey = "CHANNEL_SERVICES_SHORT", 
        label = L["CHANNEL_SERVICES"], 
        colors = { white = {1, 1, 1, 1}, blizzard = {1, 0.82, 0, 1}, rainbow = {0.8, 1, 1, 1} },
        isDynamic = true, requiresAvailabilityCheck = true, order = 94, 
        defaultPinned = false, defaultSnapshotted = true, defaultAutoJoin = true,
        defaultBindings = { left = "send", right = "leave" },
        actions = {
            { key = "send", label = L["ACTION_PREFIX_SEND"] .. L["CHANNEL_SERVICES"], tooltip = L["TOOLTIP_SEND_TO"], execute = function() addon:ActionSend("CHANNEL", "services", L["CHANNEL_SERVICES_MAPPING"]) end },
            { key = "join", label = string.format(L["ACTION_JOIN"], L["CHANNEL_SERVICES"]), tooltip = L["TOOLTIP_JOIN"], execute = function() addon:ActionJoin(L["CHANNEL_SERVICES_MAPPING"]) end },
            { key = "leave", label = string.format(L["ACTION_LEAVE"], L["CHANNEL_SERVICES"]), tooltip = L["TOOLTIP_LEAVE"], execute = function() addon:ActionLeave(L["CHANNEL_SERVICES_MAPPING"]) end }
        }
    },
    { 
        key = "world", 
        chatType = "CHANNEL", 
        mappingKey = "CHANNEL_WORLD_MAPPING", 
        shortKey = "CHANNEL_WORLD_SHORT", 
        label = L["CHANNEL_WORLD"], 
        colors = {
            white = {1, 1, 1, 1},
            blizzard = {1, 0.82, 0, 1},
            rainbow = {0.8, 0.8, 1, 1},
        },
        isDynamic = true, 
        requiresAvailabilityCheck = true, 
        order = 100, 
        defaultPinned = true, 
        defaultSnapshotted = true, 
        defaultAutoJoin = true, 
        defaultBindings = { left = "send", right = "leave" }, 
        actions = { 
            { key = "send", label = L["ACTION_PREFIX_SEND"] .. L["CHANNEL_WORLD"], tooltip = L["TOOLTIP_SEND_TO"], execute = function() addon:ActionSend("CHANNEL", "world", L["CHANNEL_WORLD_MAPPING"]) end }, 
            { key = "join", label = string.format(L["ACTION_JOIN"], L["CHANNEL_WORLD"]), tooltip = L["TOOLTIP_JOIN"], execute = function() addon:ActionJoin(L["CHANNEL_WORLD_MAPPING"]) end }, 
            { key = "leave", label = string.format(L["ACTION_LEAVE"], L["CHANNEL_WORLD"]), tooltip = L["TOOLTIP_LEAVE"], execute = function() addon:ActionLeave(L["CHANNEL_WORLD_MAPPING"]) end } 
        } 
    },
    { 
        key = "worlddefense", 
        chatType = "CHANNEL", 
        mappingKey = "CHANNEL_WORLDDEFENSE_MAPPING", 
        shortKey = "CHANNEL_WORLDDEFENSE_SHORT", 
        label = L["CHANNEL_WORLDDEFENSE"], 
        colors = { white = {1, 1, 1, 1}, blizzard = {1, 0.82, 0, 1}, rainbow = {1, 0.5, 0.5, 1} },
        isDynamic = true, requiresAvailabilityCheck = true, order = 101, 
        defaultPinned = false, defaultSnapshotted = true, defaultAutoJoin = true,
        defaultBindings = { left = "send", right = "leave" },
        actions = {
            { key = "send", label = L["ACTION_PREFIX_SEND"] .. L["CHANNEL_WORLDDEFENSE"], tooltip = L["TOOLTIP_SEND_TO"], execute = function() addon:ActionSend("CHANNEL", "worlddefense", L["CHANNEL_WORLDDEFENSE_MAPPING"]) end },
            { key = "join", label = string.format(L["ACTION_JOIN"], L["CHANNEL_WORLDDEFENSE"]), tooltip = L["TOOLTIP_JOIN"], execute = function() addon:ActionJoin(L["CHANNEL_WORLDDEFENSE_MAPPING"]) end },
            { key = "leave", label = string.format(L["ACTION_LEAVE"], L["CHANNEL_WORLDDEFENSE"]), tooltip = L["TOOLTIP_LEAVE"], execute = function() addon:ActionLeave(L["CHANNEL_WORLDDEFENSE_MAPPING"]) end }
        }
    },
    { 
        key = "beginner", 
        chatType = "CHANNEL", 
        mappingKey = "CHANNEL_BEGINNER_MAPPING", 
        shortKey = "CHANNEL_BEGINNER_SHORT", 
        label = L["CHANNEL_BEGINNER"], 
        colors = { white = {1, 1, 1, 1}, blizzard = {1, 0.82, 0, 1}, rainbow = {0.5, 1, 0.5, 1} },
        isDynamic = true, requiresAvailabilityCheck = true, order = 102, 
        defaultPinned = false, defaultSnapshotted = true, defaultAutoJoin = true,
        defaultBindings = { left = "send", right = "leave" },
        actions = {
            { key = "send", label = L["ACTION_PREFIX_SEND"] .. L["CHANNEL_BEGINNER"], tooltip = L["TOOLTIP_SEND_TO"], execute = function() addon:ActionSend("CHANNEL", "beginner", L["CHANNEL_BEGINNER_MAPPING"]) end },
            { key = "join", label = string.format(L["ACTION_JOIN"], L["CHANNEL_BEGINNER"]), tooltip = L["TOOLTIP_JOIN"], execute = function() addon:ActionJoin(L["CHANNEL_BEGINNER_MAPPING"]) end },
            { key = "leave", label = string.format(L["ACTION_LEAVE"], L["CHANNEL_BEGINNER"]), tooltip = L["TOOLTIP_LEAVE"], execute = function() addon:ActionLeave(L["CHANNEL_BEGINNER_MAPPING"]) end }
        }
    },
    { 
        key = "guildrecruit", 
        chatType = "CHANNEL", 
        mappingKey = "CHANNEL_GUILDRECRUITMENT_MAPPING", 
        shortKey = "CHANNEL_GUILDRECRUITMENT_SHORT", 
        label = L["CHANNEL_GUILDRECRUITMENT"], 
        colors = { white = {1, 1, 1, 1}, blizzard = {1, 0.82, 0, 1}, rainbow = {0.5, 0.7, 1, 1} },
        isDynamic = true, requiresAvailabilityCheck = true, order = 103, 
        defaultPinned = false, defaultSnapshotted = true, defaultAutoJoin = true,
        defaultBindings = { left = "send", right = "leave" },
        actions = {
            { key = "send", label = L["ACTION_PREFIX_SEND"] .. L["CHANNEL_GUILDRECRUITMENT"], tooltip = L["TOOLTIP_SEND_TO"], execute = function() addon:ActionSend("CHANNEL", "guildrecruit", L["CHANNEL_GUILDRECRUITMENT_MAPPING"]) end },
            { key = "join", label = string.format(L["ACTION_JOIN"], L["CHANNEL_GUILDRECRUITMENT"]), tooltip = L["TOOLTIP_JOIN"], execute = function() addon:ActionJoin(L["CHANNEL_GUILDRECRUITMENT_MAPPING"]) end },
            { key = "leave", label = string.format(L["ACTION_LEAVE"], L["CHANNEL_GUILDRECRUITMENT"]), tooltip = L["TOOLTIP_LEAVE"], execute = function() addon:ActionLeave(L["CHANNEL_GUILDRECRUITMENT_MAPPING"]) end }
        }
    },
}

-- 为其他频道继续添加...

-- =========================================================================
-- Helper Functions
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
