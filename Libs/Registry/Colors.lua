local addonName, addon = ...
local L = addon.L

-- =========================================================================
-- COLORS REGISTRY
-- 统一管理所有颜色主题和配色数据 (合并原 ColorSets 和 ColorSchemes)
-- =========================================================================

addon.Colors = {
    -- 1. 主题定义 (原 ColorSets)
    themes = {
        white = { 
            order = 10,
            name = L["COLORSET_WHITE"], 
            desc = "Uniform white text for all buttons" 
        },
        blizzard = { 
            order = 20,
            name = L["COLORSET_BLIZZARD"], 
            desc = "Classic Blizzard gold/yellow text" 
        },
        rainbow = { 
            order = 30,
            name = L["COLORSET_RAINBOW"], 
            desc = "Distinct colors for each channel and tool" 
        },
    },
    
    -- 2. 颜色数据 (原 ColorSchemes)
    -- 按 [Category][Key][Theme] 组织
    data = {
        -- =====================================================================
        -- CHANNEL 颜色主题
        -- =====================================================================
        -- =====================================================================
        -- CHANNEL 颜色主题
        -- =====================================================================
        CHANNEL = {
            say = {
                white = {1, 1, 1, 1},
                blizzard = {1, 0.82, 0, 1},
                rainbow = {1, 1, 1, 1},
            },
            yell = {
                white = {1, 1, 1, 1},
                blizzard = {1, 0.82, 0, 1},
                rainbow = {1, 0.25, 0.25, 1},
            },
            party = {
                white = {1, 1, 1, 1},
                blizzard = {1, 0.82, 0, 1},
                rainbow = {0.66, 0.66, 1, 1},
            },
            raid = {
                white = {1, 1, 1, 1},
                blizzard = {1, 0.82, 0, 1},
                rainbow = {1, 0.5, 0, 1},
            },
            instance = {
                white = {1, 1, 1, 1},
                blizzard = {1, 0.82, 0, 1},
                rainbow = {1, 0.5, 0, 1},
            },
            battleground = {
                white = {1, 1, 1, 1},
                blizzard = {1, 0.82, 0, 1},
                rainbow = {1, 0.5, 0, 1},
            },
            guild = {
                white = {1, 1, 1, 1},
                blizzard = {1, 0.82, 0, 1},
                rainbow = {0.25, 1, 0.25, 1},
            },
            officer = {
                white = {1, 1, 1, 1},
                blizzard = {1, 0.82, 0, 1},
                rainbow = {0.25, 0.75, 0.25, 1},
            },
            emote = {
                white = {1, 1, 1, 1},
                blizzard = {1, 0.82, 0, 1},
                rainbow = {1, 0.5, 0.25, 1},
            },
            general = {
                white = {1, 1, 1, 1},
                blizzard = {1, 0.82, 0, 1},
                rainbow = {0.8, 1, 0.8, 1},
            },
            trade = {
                white = {1, 1, 1, 1},
                blizzard = {1, 0.82, 0, 1},
                rainbow = {1, 0.8, 0.8, 1},
            },
            localdefense = {
                white = {1, 1, 1, 1},
                blizzard = {1, 0.82, 0, 1},
                rainbow = {0.8, 0.8, 1, 1},
            },
            lfg = {
                white = {1, 1, 1, 1},
                blizzard = {1, 0.82, 0, 1},
                rainbow = {1, 1, 0.8, 1},
            },
            services = {
                white = {1, 1, 1, 1},
                blizzard = {1, 0.82, 0, 1},
                rainbow = {0.8, 1, 1, 1},
            },
            world = {
                white = {1, 1, 1, 1},
                blizzard = {1, 0.82, 0, 1},
                rainbow = {0.8, 0.8, 1, 1},
            },
            worlddefense = {
                white = {1, 1, 1, 1},
                blizzard = {1, 0.82, 0, 1},
                rainbow = {1, 0.5, 0.5, 1},
            },
            beginner = {
                white = {1, 1, 1, 1},
                blizzard = {1, 0.82, 0, 1},
                rainbow = {0.5, 1, 0.5, 1},
            },
            guildrecruit = {
                white = {1, 1, 1, 1},
                blizzard = {1, 0.82, 0, 1},
                rainbow = {0.5, 0.7, 1, 1},
            },
            whisper = {
                white = {1, 1, 1, 1},
                blizzard = {1, 0.82, 0, 1},
                rainbow = {1, 0.5, 1, 1},
            },
            bn_whisper = {
                white = {1, 1, 1, 1},
                blizzard = {1, 0.82, 0, 1},
                rainbow = {0, 1, 0.96, 1}, -- 蓝绿色
            },
        },
        
        -- =====================================================================
        -- KIT 颜色主题
        -- =====================================================================
        KIT = {
            readyCheck = {
                white = {1, 1, 1, 1},
                blizzard = {1, 0.82, 0, 1},
                rainbow = {1, 1, 1, 1},
            },
            resetInstances = {
                white = {1, 1, 1, 1},
                blizzard = {1, 0.82, 0, 1},
                rainbow = {1, 1, 1, 1},
            },
            countdown = {
                white = {1, 1, 1, 1},
                blizzard = {1, 0.82, 0, 1},
                rainbow = {1, 1, 1, 1},
            },
            roll = {
                white = {1, 1, 1, 1},
                blizzard = {1, 0.82, 0, 1},
                rainbow = {1, 1, 1, 1},
            },
            filter = {
                white = {1, 1, 1, 1},
                blizzard = {1, 0.82, 0, 1},
                rainbow = {1, 1, 1, 1},
            },
            macro = {
                white = {1, 1, 1, 1},
                blizzard = {1, 0.82, 0, 1},
                rainbow = {1, 1, 1, 1},
            },
            leave = {
                white = {1, 1, 1, 1},
                blizzard = {1, 0.82, 0, 1},
                rainbow = {1, 0.5, 0.5, 1}, -- 红色
            },
            emotePanel = {
                white = {1, 1, 1, 1},
                blizzard = {1, 0.82, 0, 1},
                rainbow = {1, 1, 1, 1},
            },
            reload = {
                white = {1, 1, 1, 1},
                blizzard = {1, 0.82, 0, 1},
                rainbow = {1, 1, 1, 1},
            },
        }
    }
}

-- =========================================================================
-- API Implementation
-- =========================================================================

local Colors = addon.Colors

--- 获取指定 Stream/KIT 在指定主题下的颜色
--- @param category string "CHANNEL" 或 "KIT"
--- @param key string 逻辑名称，如 "say", "readyCheck"
--- @param theme string 主题名称，如 "white", "blizzard", "rainbow"
--- @return table 颜色数组 {r, g, b, a}
function addon:GetColor(category, key, theme)
    local default = {1, 1, 1, 1}
    
    if not Colors.data[category] then return default end
    if not Colors.data[category][key] then return default end
    
    local entry = Colors.data[category][key]
    return entry[theme] or entry.white or default
end

--- 获取频道颜色（简化接口）
function addon:GetChannelColor(streamKey, theme)
    return self:GetColor("CHANNEL", streamKey, theme)
end

--- 获取 KIT 颜色（简化接口）
function addon:GetKitColor(kitKey, theme)
    return self:GetColor("KIT", kitKey, theme)
end

--- [NEW] 获取频道基础颜色（用于内容回填，始终使用标准配色）
--- 对应 "rainbow" 主题下的定义 (Standard Game Colors)
function addon:GetChannelBaseColor(streamKey)
    return self:GetColor("CHANNEL", streamKey, "rainbow")
end

--- 获取所有颜色方案（用于设置界面下拉列表）
function addon:GetColorSetOptions()
    -- Use Blizzard Settings API container if available
    -- This ensures compatibility with Settings.CreateDropdown
    if Settings and Settings.CreateControlTextContainer then
        local c = Settings.CreateControlTextContainer()
        local list = {}
        for key, def in pairs(Colors.themes) do
            table.insert(list, { key = key, name = def.name, order = def.order })
        end
        table.sort(list, function(a, b) return (a.order or 0) < (b.order or 0) end)
        
        for _, item in ipairs(list) do
            c:Add(item.key, item.name)
        end
        return c:GetData()
    end

    -- Fallback for legacy or if Settings not loaded yet (shouldn't happen in config context)
    local list = {}
    for key, def in pairs(Colors.themes) do
        table.insert(list, { key = key, name = def.name, order = def.order })
    end
    table.sort(list, function(a, b) return (a.order or 0) < (b.order or 0) end)
    return list
end

--- 获取按键颜色 (兼容接口，供 Shelf 使用)
--- @param element table 必须包含 element.key 和 隐含的 category (通过查找)
--- 注意：由于 element 不再携带 colors，我们需要推断 category
function addon:GetButtonColor(element)
    local theme = "rainbow"
    if addon.Shelf and addon.Shelf.GetThemeProperty then
        theme = addon.Shelf:GetThemeProperty("colorSet") or "rainbow"
    end
    
    -- No more forced override here. Theme data handles it cleanly.
    
    -- 推断 Category
    -- 如果是 stream (有 chatType 或 events)，则是 CHANNEL
    -- 如果是 kit (有 kitKey? 或者是 KIT_REGISTRY 中的项)，则是 KIT
    
    local category = "CHANNEL"
    if element.actions or element.execute then
        -- 这是一个复杂的推断，因为 Shelf 传递的 element 可能是 Stream 也可能是 Kit
        -- 最好的方式是在 element 中显式标记 category
        -- 此时我们尝试查找 Kit
        if element.key and Colors.data.KIT[element.key] then
            category = "KIT"
        end
    end
    
    -- 如果 element 明确有 category 字段，使用它
    if element.category then
        category = element.category == "kit" and "KIT" or "CHANNEL"
    end
    
    return addon:GetColor(category, element.key, theme)
end

-- 兼容旧的 ColorSetRegistry 访问 (如果有)
addon.ColorSetRegistry = {
    GetColor = function(self, element, setKey)
        return addon:GetButtonColor(element) -- 简化的重定向
    end,
    GetAllSets = function(self)
        -- Legacy interface returning Settings data which is now standard
        return addon:GetColorSetOptions()
    end
}
