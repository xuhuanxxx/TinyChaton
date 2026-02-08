local addonName, addon = ...

-- =========================================================================
-- COLOR_SCHEMES
-- 统一管理所有频道和 KIT 的颜色主题
-- 按照逻辑名称（key）组织，支持多种主题（white, blizzard, rainbow）
-- =========================================================================

addon.COLOR_SCHEMES = {
    -- =====================================================================
    -- CHANNEL 颜色主题
    -- =====================================================================
    CHANNEL = {
        -- 说话
        say = {
            white = {1, 1, 1, 1},
            blizzard = {1, 1, 1, 1},
            rainbow = {1, 1, 1, 1},
        },
        -- 大喊
        yell = {
            white = {1, 1, 1, 1},
            blizzard = {1, 0.25, 0.25, 1},
            rainbow = {1, 0.25, 0.25, 1},
        },
        -- 队伍
        party = {
            white = {1, 1, 1, 1},
            blizzard = {0.66, 0.66, 1, 1},
            rainbow = {0.66, 0.66, 1, 1},
        },
        -- 团队
        raid = {
            white = {1, 1, 1, 1},
            blizzard = {1, 0.5, 0, 1},
            rainbow = {1, 0.5, 0, 1},
        },
        -- 副本
        instance = {
            white = {1, 1, 1, 1},
            blizzard = {1, 0.5, 0, 1},
            rainbow = {1, 0.5, 0, 1},
        },
        -- 战场
        battleground = {
            white = {1, 1, 1, 1},
            blizzard = {1, 0.5, 0, 1},
            rainbow = {1, 0.5, 0, 1},
        },
        -- 公会
        guild = {
            white = {1, 1, 1, 1},
            blizzard = {0.25, 1, 0.25, 1},
            rainbow = {0.25, 1, 0.25, 1},
        },
        -- 官员
        officer = {
            white = {1, 1, 1, 1},
            blizzard = {0.25, 0.75, 0.25, 1},
            rainbow = {0.25, 0.75, 0.25, 1},
        },
        -- 表情
        emote = {
            white = {1, 1, 1, 1},
            blizzard = {1, 0.5, 0.25, 1},
            rainbow = {1, 0.5, 0.25, 1},
        },
        -- 综合
        general = {
            white = {1, 1, 1, 1},
            blizzard = {1, 0.75, 0.75, 1},
            rainbow = {1, 0.75, 0.75, 1},
        },
        -- 交易
        trade = {
            white = {1, 1, 1, 1},
            blizzard = {1, 0.75, 0.75, 1},
            rainbow = {1, 0.75, 0.75, 1},
        },
        -- 本地防务
        localdefense = {
            white = {1, 1, 1, 1},
            blizzard = {1, 0.75, 0.75, 1},
            rainbow = {1, 0.75, 0.75, 1},
        },
        -- 寻求组队
        lfg = {
            white = {1, 1, 1, 1},
            blizzard = {1, 0.75, 0.75, 1},
            rainbow = {1, 0.75, 0.75, 1},
        },
        -- 服务
        services = {
            white = {1, 1, 1, 1},
            blizzard = {1, 0.75, 0.75, 1},
            rainbow = {1, 0.75, 0.75, 1},
        },
        -- 世界
        world = {
            white = {1, 1, 1, 1},
            blizzard = {1, 0.75, 0.75, 1},
            rainbow = {1, 0.75, 0.75, 1},
        },
        -- 世界防务
        worlddefense = {
            white = {1, 1, 1, 1},
            blizzard = {1, 0.75, 0.75, 1},
            rainbow = {1, 0.75, 0.75, 1},
        },
        -- 新手
        beginner = {
            white = {1, 1, 1, 1},
            blizzard = {1, 0.75, 0.75, 1},
            rainbow = {1, 0.75, 0.75, 1},
        },
        -- 公会招募
        guildrecruit = {
            white = {1, 1, 1, 1},
            blizzard = {1, 0.75, 0.75, 1},
            rainbow = {1, 0.75, 0.75, 1},
        },
        -- 密语
        whisper = {
            white = {1, 1, 1, 1},
            blizzard = {1, 0.5, 1, 1},
            rainbow = {1, 0.5, 1, 1},
        },
        -- 战网密语
        bn_whisper = {
            white = {1, 1, 1, 1},
            blizzard = {0, 1, 0.96, 1},  -- 蓝绿色
            rainbow = {0, 1, 0.96, 1},
        },
    },
    
    -- =====================================================================
    -- KIT 颜色主题
    -- =====================================================================
    KIT = {
        -- 准备检查
        readyCheck = {
            white = {1, 1, 1, 1},
            blizzard = {1, 0.82, 0, 1},
            rainbow = {1, 1, 1, 1},
        },
        -- 重置副本
        resetInstances = {
            white = {1, 1, 1, 1},
            blizzard = {1, 0.82, 0, 1},
            rainbow = {1, 1, 1, 1},
        },
        -- 倒计时
        countdown = {
            white = {1, 1, 1, 1},
            blizzard = {1, 0.82, 0, 1},
            rainbow = {1, 1, 1, 1},
        },
        -- 掷骰子
        roll = {
            white = {1, 1, 1, 1},
            blizzard = {1, 0.82, 0, 1},
            rainbow = {1, 1, 1, 1},
        },
        -- 过滤器
        filter = {
            white = {1, 1, 1, 1},
            blizzard = {1, 0.82, 0, 1},
            rainbow = {1, 1, 1, 1},
        },
        -- 宏
        macro = {
            white = {1, 1, 1, 1},
            blizzard = {1, 0.82, 0, 1},
            rainbow = {1, 1, 1, 1},
        },
        -- 离开队伍（红色警示）
        leave = {
            white = {1, 1, 1, 1},
            blizzard = {1, 0.82, 0, 1},
            rainbow = {1, 0.5, 0.5, 1},  -- 红色
        },
        -- 表情面板
        emotePanel = {
            white = {1, 1, 1, 1},
            blizzard = {1, 0.82, 0, 1},
            rainbow = {1, 1, 1, 1},
        },
        -- 重载UI
        reload = {
            white = {1, 1, 1, 1},
            blizzard = {1, 0.82, 0, 1},
            rainbow = {1, 1, 1, 1},
        },
    },
}

-- =========================================================================
-- 辅助函数：获取颜色
-- =========================================================================

--- 获取指定 Stream/KIT 在指定主题下的颜色
--- @param category string "CHANNEL" 或 "KIT"
--- @param key string 逻辑名称，如 "say", "readyCheck"
--- @param theme string 主题名称，如 "white", "blizzard", "rainbow"
--- @return table|nil 颜色数组 {r, g, b, a} 或 nil
function addon:GetColor(category, key, theme)
    if not self.COLOR_SCHEMES then return nil end
    if not self.COLOR_SCHEMES[category] then return nil end
    if not self.COLOR_SCHEMES[category][key] then return nil end
    
    return self.COLOR_SCHEMES[category][key][theme] or self.COLOR_SCHEMES[category][key].white
end

--- 获取频道颜色（简化接口）
--- @param streamKey string 频道逻辑名称
--- @param theme string 主题名称
--- @return table|nil 颜色数组
function addon:GetChannelColor(streamKey, theme)
    return self:GetColor("CHANNEL", streamKey, theme)
end

--- 获取 KIT 颜色（简化接口）
--- @param kitKey string KIT 逻辑名称
--- @param theme string 主题名称
--- @return table|nil 颜色数组
function addon:GetKitColor(kitKey, theme)
    return self:GetColor("KIT", kitKey, theme)
end
