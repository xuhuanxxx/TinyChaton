local addonName, addon = ...

-- =========================================================================
-- 事件分发器
-- 根据 STREAM_REGISTRY 的 events 字段自动构建事件到 Stream 的映射
-- 在核心层统一处理事件过滤、黑名单、高亮、Taint 检测
-- =========================================================================

addon.EventDispatcher = addon.EventDispatcher or {}
local Dispatcher = addon.EventDispatcher

-- 事件到 Stream 键的映射表 (event -> {streamKey1, streamKey2, ...})
Dispatcher.eventToStreams = {}

-- 已注册的过滤器（避免重复注册）
Dispatcher.registeredFilters = {}

--- 初始化事件分发器
--- 遍历 STREAM_REGISTRY 建立 event -> [streams] 映射
function Dispatcher:Initialize()
    self.eventToStreams = {}
    self.registeredFilters = {}
    
    if not addon.STREAM_REGISTRY then return end
    
    -- 遍历所有 Stream，收集事件映射
    for categoryKey, category in pairs(addon.STREAM_REGISTRY) do
        for subKey, subCategory in pairs(category) do
            for _, stream in ipairs(subCategory) do
                if stream.events then
                    for _, event in ipairs(stream.events) do
                        -- 初始化该事件的 Stream 列表
                        if not self.eventToStreams[event] then
                            self.eventToStreams[event] = {}
                        end
                        
                        -- 添加 Stream 键到映射
                        table.insert(self.eventToStreams[event], stream.key)
                    end
                end
            end
        end
    end
end

--- 注册全局事件过滤器
--- 为每个唯一事件注册一个 ChatFrame_AddMessageEventFilter
function Dispatcher:RegisterFilters()
    for event, streamKeys in pairs(self.eventToStreams) do
        -- 跳过已注册的事件
        if not self.registeredFilters[event] then
            ChatFrame_AddMessageEventFilter(event, function(...)
                return self:OnChatEvent(event, ...)
            end)
            
            self.registeredFilters[event] = true
        end
    end
end

--- 核心事件处理函数
--- @param event string 事件名称
--- @param ... 事件参数
--- @return boolean|nil 是否拦截消息
function Dispatcher:OnChatEvent(event, ...)
    local text, sender, languageID, channelString, target, flags, unknown, channelNumber, channelName, unknown2, counter = ...
    
    -- =====================================================================
    -- 1. 全局黑名单检查
    -- =====================================================================
    if addon.IsPlayerBlacklisted and addon:IsPlayerBlacklisted(sender) then
        -- 如果启用了黑名单且发送者在黑名单中，拦截消息
        return true
    end
    
    -- =====================================================================
    -- 2. Taint 检测（适用于敏感流）
    -- =====================================================================
    -- 这里可以添加 Taint 检测逻辑
    -- if self:IsTaintedMessage(text, sender) then
    --     return true
    -- end
    
    -- =====================================================================
    -- 3. 分发到相关 Streams
    -- =====================================================================
    local streamKeys = self.eventToStreams[event]
    if streamKeys then
        for _, streamKey in ipairs(streamKeys) do
            local stream = addon:GetStreamByKey(streamKey)
            if stream and stream.onEvent then
                -- 调用 Stream 的自定义事件处理器
                local shouldBlock = stream.onEvent(stream, event, ...)
                if shouldBlock then
                    return true
                end
            end
        end
    end
    
    -- =====================================================================
    -- 4. 高亮处理（全局）
    -- =====================================================================
    if addon.ShouldHighlight and addon:ShouldHighlight(text) then
        -- 可以在这里修改消息样式或添加标记
        -- 但 ChatFrame_AddMessageEventFilter 不能直接修改文本
        -- 需要配合其他钩子使用
    end
    
    -- 不拦截消息，继续传递
    return false
end

--- 获取某个事件关联的所有 Stream 键
--- @param event string 事件名称
--- @return table Stream 键数组
function Dispatcher:GetStreamsForEvent(event)
    return self.eventToStreams[event] or {}
end

--- 检查某个 Stream 是否监听指定事件
--- @param streamKey string Stream 键
--- @param event string 事件名称
--- @return boolean 是否监听
function Dispatcher:IsStreamListeningToEvent(streamKey, event)
    local streamKeys = self.eventToStreams[event]
    if not streamKeys then return false end
    
    for _, key in ipairs(streamKeys) do
        if key == streamKey then
            return true
        end
    end
    
    return false
end

-- =========================================================================
-- 在插件加载时自动初始化事件分发器
-- =========================================================================
function addon:InitializeEventDispatcher()
    if not self.EventDispatcher then return end
    
    -- 初始化映射表
    self.EventDispatcher:Initialize()
    
    -- 注册全局过滤器
    self.EventDispatcher:RegisterFilters()
    
    -- 调试信息（可选）
    if self.Debug then
        local eventCount = 0
        for _ in pairs(self.EventDispatcher.eventToStreams) do
            eventCount = eventCount + 1
        end
        self:Debug(string.format("EventDispatcher initialized: %d unique events registered", eventCount))
    end
end
