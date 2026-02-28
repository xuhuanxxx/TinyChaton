local addonName, addon = ...

-- =========================================================================
-- ThemeRegistry - 外观主题管理系统
-- 统一注册和管理所有UI组件的主题预设
-- =========================================================================

addon.ThemeRegistry = {
    -- 主题预设表: [themeKey] = definition
    presets = {},

    -- 组件绑定表: [componentKey] = { themes = {}, default = nil }
    componentBindings = {},

    -- 属性类型定义
    propertyTypes = {
        color = {
            validate = function(v)
                return type(v) == "table" and #v == 4 and
                       type(v[1]) == "number" and v[1] >= 0 and v[1] <= 1
            end,
            default = {1, 1, 1, 1},
            description = "RGBA color {r, g, b, a}",
        },
        number = {
            validate = function(v, min, max)
                if type(v) ~= "number" then return false end
                if min and v < min then return false end
                if max and v > max then return false end
                return true
            end,
            default = 0,
            description = "Numeric value",
        },
        font = {
            validate = function(v) return type(v) == "string" end,
            default = "",
            description = "Font path or name",
        },
        texture = {
            validate = function(v) return type(v) == "string" end,
            default = "",
            description = "Texture path",
        },
        size = {
            validate = function(v)
                return type(v) == "table" and #v == 2 and
                       type(v[1]) == "number" and type(v[2]) == "number"
            end,
            default = {100, 30},
            description = "Size {width, height}",
        },
        backdrop = {
            validate = function(v)
                return type(v) == "table" and v.bgFile ~= nil
            end,
            default = nil,
            description = "WoW Backdrop definition",
        },
    },
}

local TR = addon.ThemeRegistry

-- =========================================================================
-- 公共API
-- =========================================================================

--- 注册一个主题预设
-- @param key string 主题唯一标识，如 "Modern", "Dark", "Minimal"
-- @param definition table 主题定义
--   - name: 显示名称（本地化键名或字符串）
--   - description: 描述
--   - properties: 属性定义表
--   - extends: (可选) 继承自哪个主题
-- @return boolean 是否注册成功
function TR:RegisterPreset(key, definition)
    if not key or type(key) ~= "string" then
        error("ThemeRegistry: key must be a string")
    end

    if not definition or type(definition) ~= "table" then
        error("ThemeRegistry: definition must be a table")
    end

    -- 检查是否已存在
    if self.presets[key] then
        print("|cFFFF0000ThemeRegistry:|r Warning - overwriting existing theme '" .. key .. "'")
    end

    -- 处理继承
    local finalDefinition = self:MergeWithParent(definition)

    -- 验证属性
    if finalDefinition.properties then
        self:ValidateProperties(finalDefinition.properties)
    end

    self.presets[key] = finalDefinition

    if addon.Debug then
        addon:Debug("ThemeRegistry: Registered theme '%s'", key)
    end

    return true
end

--- 注册组件的主题绑定
-- @param componentKey string 组件标识，如 "shelf", "chatFrame"
-- @param themeKeys table 该组件支持的主题key列表
-- @param defaultTheme string 默认主题key
function TR:RegisterComponent(componentKey, themeKeys, defaultTheme)
    if not componentKey or type(componentKey) ~= "string" then
        error("ThemeRegistry: componentKey must be a string")
    end

    if type(themeKeys) ~= "table" then
        error("ThemeRegistry: themeKeys must be a table")
    end

    -- 验证主题是否存在
    for _, themeKey in ipairs(themeKeys) do
        if not self.presets[themeKey] then
            error("ThemeRegistry: theme '" .. themeKey .. "' not found when registering component '" .. componentKey .. "'")
        end
    end

    -- 验证默认主题
    if defaultTheme and not self.presets[defaultTheme] then
        error("ThemeRegistry: default theme '" .. defaultTheme .. "' not found")
    end

    self.componentBindings[componentKey] = {
        themes = themeKeys,
        default = defaultTheme or themeKeys[1],
    }

    if addon.Debug then
        addon:Debug("ThemeRegistry: Registered component '%s' with %d themes", componentKey, #themeKeys)
    end
end

--- 获取主题预设
-- @param key string 主题key
-- @return table|nil 主题定义
function TR:GetPreset(key)
    return self.presets[key]
end

--- 获取组件支持的所有主题
-- @param componentKey string 组件标识
-- @return table 主题key列表
function TR:GetComponentThemes(componentKey)
    local binding = self.componentBindings[componentKey]
    if not binding then return {} end
    return binding.themes
end

--- 获取组件的默认主题
-- @param componentKey string 组件标识
-- @return string|nil 默认主题key
function TR:GetComponentDefault(componentKey)
    local binding = self.componentBindings[componentKey]
    if not binding then return nil end
    return binding.default
end

--- 获取主题的所有属性（包含继承和默认值）
-- @param themeKey string 主题key
-- @param componentKey string 组件标识（用于过滤该组件使用的属性）
-- @return table 完整的属性表
function TR:GetResolvedProperties(themeKey, componentKey)
    local preset = self.presets[themeKey]
    if not preset then return {} end

    local props = {}

    -- 复制属性
    if preset.properties then
        for k, v in pairs(preset.properties) do
            props[k] = v
        end
    end

    return props
end

--- 检查主题是否支持某个属性
-- @param themeKey string 主题key
-- @param propertyName string 属性名
-- @return boolean
function TR:HasProperty(themeKey, propertyName)
    local preset = self.presets[themeKey]
    if not preset or not preset.properties then return false end
    return preset.properties[propertyName] ~= nil
end

-- =========================================================================
-- 内部辅助函数
-- =========================================================================

--- 与父主题合并
function TR:MergeWithParent(definition)
    if not definition.extends then
        return definition
    end

    local parent = self.presets[definition.extends]
    if not parent then
        error("ThemeRegistry: parent theme '" .. definition.extends .. "' not found")
    end

    -- 递归合并
    local parentMerged = self:MergeWithParent(parent)
    local merged = {}

    -- 复制父主题属性
    for k, v in pairs(parentMerged) do
        if k ~= "properties" then
            merged[k] = v
        end
    end

    -- 复制父主题properties
    if parentMerged.properties then
        merged.properties = {}
        for k, v in pairs(parentMerged.properties) do
            merged.properties[k] = v
        end
    end

    -- 覆盖子主题定义
    for k, v in pairs(definition) do
        if k == "properties" and type(v) == "table" then
            -- 深度合并properties
            merged.properties = merged.properties or {}
            for pk, pv in pairs(v) do
                merged.properties[pk] = pv
            end
        else
            merged[k] = v
        end
    end

    return merged
end

--- 验证属性值
function TR:ValidateProperties(properties)
    for name, value in pairs(properties) do
        -- 这里可以添加更复杂的验证逻辑
        -- 目前只做基础类型检查
        if type(value) == "table" and value._type then
            local typeDef = self.propertyTypes[value._type]
            if typeDef and not typeDef.validate(value.value) then
                print("|cFFFF0000ThemeRegistry:|r Warning - invalid value for property '" .. name .. "'")
            end
        end
    end
end

-- =========================================================================
-- 工具函数：生成设置UI用的选项表
-- =========================================================================

--- 为组件生成主题下拉选项
-- @param componentKey string 组件标识
-- @return table 适合 Settings.CreateControlTextContainer 的数据
function TR:GenerateThemeOptions(componentKey)
    local themes = self:GetComponentThemes(componentKey)
    local options = {}

    for _, themeKey in ipairs(themes) do
        local preset = self.presets[themeKey]
        if preset then
            table.insert(options, {
                key = themeKey,
                label = preset.name or themeKey,
            })
        end
    end

    return options
end

--- 获取主题属性的UI控件类型建议
-- @param propertyName string 属性名
-- @param value any 属性值
-- @return string 控件类型: "slider", "color", "dropdown", "text"
function TR:GetPropertyControlType(propertyName, value)
    local valueType = type(value)

    if valueType == "table" then
        if #value == 4 and type(value[1]) == "number" then
            return "color"
        elseif #value == 2 then
            return "size"
        end
    elseif valueType == "number" then
        if propertyName:match("[Ss]ize") or propertyName:match("[Ss]cale") then
            return "slider"
        elseif propertyName:match("[Aa]lpha") then
            return "slider"
        end
        return "number"
    elseif valueType == "string" then
        if propertyName:match("[Ff]ont") then
            return "font"
        elseif propertyName:match("[Tt]exture") or propertyName:match("[Bb]gFile") then
            return "texture"
        end
        return "text"
    end

    return "text"
end

-- No global export. Access via addon.ThemeRegistry.
