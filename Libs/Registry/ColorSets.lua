local addonName, addon = ...
local L = addon.L

-- =========================================================================
-- ColorSetRegistry - 字体颜色方案注册表
-- 只定义有哪些颜色方案，实际颜色由频道/工具自己定义
-- =========================================================================

addon.ColorSetRegistry = {
    sets = {},
}

local CSR = addon.ColorSetRegistry

--- 注册颜色方案
-- @param key string 方案标识：white/blizzard/channel
-- @param definition table 方案定义
--   - name: 显示名称
--   - description: 描述
function CSR:RegisterSet(key, definition)
    if not key or type(key) ~= "string" then
        error("ColorSetRegistry: key must be a string")
    end
    
    self.sets[key] = definition
end

--- 获取颜色方案
function CSR:GetSet(key)
    return self.sets[key]
end

--- 获取所有颜色方案（用于下拉列表）
function CSR:GetAllSets()
    local list = {}
    for key, def in pairs(self.sets) do
        table.insert(list, { key = key, name = def.name })
    end
    table.sort(list, function(a, b) return a.key < b.key end)
    return list
end

--- 获取元素在指定方案下的颜色
-- @param element table 频道或工具对象（必须包含 colors 字段）
-- @param setKey string 颜色方案key
-- @return table 颜色值 {r, g, b, a}
function CSR:GetColor(element, setKey)
    if not element or not element.colors then
        return {1, 1, 1, 1}
    end
    
    -- 获取方案对应的颜色，如果没有则回退到 white
    local color = element.colors[setKey] or element.colors.white or {1, 1, 1, 1}
    return color
end

-- =========================================================================
-- 注册默认颜色方案
-- =========================================================================

-- 方案1：纯白（统一白色）
CSR:RegisterSet("white", {
    name = L["COLORSET_WHITE"],
    description = "Uniform white text for all buttons",
})

-- 方案2：暴雪游戏黄（经典金色）
CSR:RegisterSet("blizzard", {
    name = L["COLORSET_BLIZZARD"],
    description = "Classic Blizzard gold/yellow text",
})

-- 方案3：彩虹色（每个频道/工具有自己的独特颜色）
CSR:RegisterSet("rainbow", {
    name = L["COLORSET_RAINBOW"],
    description = "Distinct colors for each channel and tool",
})

-- =========================================================================
-- 辅助函数：获取按钮颜色
-- =========================================================================

function addon:GetButtonColor(element)
    local colorSetKey = "rainbow"
    if addon.Shelf and addon.Shelf.GetThemeProperty then
        colorSetKey = addon.Shelf:GetThemeProperty("colorSet") or "rainbow"
    end
    
    return addon.ColorSetRegistry:GetColor(element, colorSetKey)
end

-- =========================================================================
-- 辅助函数：获取所有颜色组选项（用于设置界面）
-- =========================================================================

function addon:GetColorSetOptions()
    local sets = addon.ColorSetRegistry:GetAllSets()
    local c = Settings.CreateControlTextContainer()
    
    for _, setInfo in ipairs(sets) do
        c:Add(setInfo.key, setInfo.name)
    end
    
    return c:GetData()
end
