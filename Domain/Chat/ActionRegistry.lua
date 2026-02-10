local addonName, addon = ...
local OpenChat = _G["Chat" .. "Frame_OpenChat"]
local L = addon.L

-- =========================================================================
-- ACTION_DEFINITIONS
-- ACTION 反向绑定：ACTION 声明自己适用于哪些 Stream/KIT
-- 取代原有在频道/KIT 中定义 actions 的方式
-- =========================================================================

addon.ACTION_DEFINITIONS = {
    -- =====================================================================
    -- [SEND] 发送消息到频道
    -- =====================================================================
    {
        key = "send",
        label = L["ACTION_PREFIX_SEND"],
        category = "channel",
        -- 声明此 ACTION 适用于哪些 Stream
        appliesTo = {
            streamPaths = { "CHANNEL.SYSTEM", "CHANNEL.DYNAMIC" }
        },
        -- 执行函数接收 streamKey 参数
        execute = function(streamKey)
            local stream = addon:GetStreamByKey(streamKey)
            if not stream then return end

            if stream.chatType then
                addon:ActionSend(stream.chatType, streamKey, stream.mappingKey and L[stream.mappingKey])
            end
        end,
        -- 生成标签的函数
        getLabel = function(streamKey)
            local stream = addon:GetStreamByKey(streamKey)
            return stream and (stream.label or "") or ""
        end,
        getTooltip = function()
            return L["TOOLTIP_SEND_TO"]
        end
    },

    -- =====================================================================
    -- [MUTE_TOGGLE] Dynamic channel visibility toggle
    -- =====================================================================
    {
        key = "mute_toggle",
        label = L["ACTION_MUTE_TOGGLE"],
        category = "channel",
        appliesTo = {
            streamPaths = { "CHANNEL.DYNAMIC" }
        },
        execute = function(streamKey)
            if addon.VisibilityPolicy and addon.VisibilityPolicy.ToggleDynamicChannelMute then
                addon.VisibilityPolicy:ToggleDynamicChannelMute(streamKey)
            end
            if addon.RefreshShelf then
                addon:RefreshShelf()
            end
        end,
        getLabel = function(streamKey)
            local stream = addon:GetStreamByKey(streamKey)
            if stream and stream.label then
                return L["ACTION_MUTE_TOGGLE"] .. " " .. stream.label
            end
            return L["ACTION_MUTE_TOGGLE"]
        end,
        getTooltip = function()
            return L["TOOLTIP_MUTE_TOGGLE"]
        end
    },

    -- =====================================================================
    -- [WHISPER_SEND] 私聊发送（特殊处理）
    -- =====================================================================
    {
        key = "whisper_send",
        label = L["ACTION_PREFIX_SEND"],
        category = "channel",
        appliesTo = {
            streamKeys = { "whisper", "bn_whisper" }
        },
        execute = function(streamKey)
            if streamKey == "whisper" then
                OpenChat("/w ")
            elseif streamKey == "bn_whisper" then
                OpenChat("/w ")
            end
        end,
        getLabel = function(streamKey)
            local stream = addon:GetStreamByKey(streamKey)
            return stream and stream.label or ""
        end,
        getTooltip = function()
            return L["TOOLTIP_SEND_TO"]
        end
    },

    -- =====================================================================
    -- [EMOTE_SEND] 表情发送
    -- =====================================================================
    {
        key = "emote_send",
        label = L["ACTION_PREFIX_SEND"],
        category = "channel",
        appliesTo = {
            streamKeys = { "emote" }
        },
        execute = function()
            OpenChat("/e ")
        end,
        getLabel = function(streamKey)
            local stream = addon:GetStreamByKey(streamKey)
            return stream and stream.label or ""
        end,
        getTooltip = function()
            return L["TOOLTIP_SEND_TO"]
        end
    },

    -- =====================================================================
    -- [KIT ACTIONS] 工具按钮操作
    -- =====================================================================
    {
        key = "readycheck",
        category = "kit",
        appliesTo = { kits = { "readyCheck" } },
        execute = function() DoReadyCheck() end,
        getLabel = function() return L["KIT_READYCHECK"] end,
        getTooltip = function() return L["KIT_READYCHECK_TOOLTIP"] end
    },
    {
        key = "reset_instances",
        category = "kit",
        appliesTo = { kits = { "resetInstances" } },
        execute = function() ResetInstances() end,
        getLabel = function() return L["KIT_RESET_INSTANCES"] end,
        getTooltip = function() return L["KIT_RESET_INSTANCES_TOOLTIP"] end
    },
    {
        key = "countdown_primary",
        category = "kit",
        appliesTo = { kits = { "countdown" } },
        execute = function()
            C_PartyInfo.DoCountdown(addon.db.plugin.shelf.kitOptions.countdown.primary or 10)
        end,
        getLabel = function() return L["ACTION_TIMER_PRIMARY"] end,
        getTooltip = function() return L["ACTION_TIMER_PRIMARY_DESC"] end
    },
    {
        key = "countdown_secondary",
        category = "kit",
        appliesTo = { kits = { "countdown" } },
        execute = function()
            C_PartyInfo.DoCountdown(addon.db.plugin.shelf.kitOptions.countdown.secondary or 5)
        end,
        getLabel = function() return L["ACTION_TIMER_SECONDARY"] end,
        getTooltip = function() return L["ACTION_TIMER_SECONDARY_DESC"] end
    },
    {
        key = "countdown_cancel",
        category = "kit",
        appliesTo = { kits = { "countdown" } },
        execute = function() C_PartyInfo.DoCountdown(0) end,
        getLabel = function() return L["ACTION_CANCEL"] end,
        getTooltip = function() return L["ACTION_CANCEL"] end
    },
    {
        key = "roll",
        category = "kit",
        appliesTo = { kits = { "roll" } },
        execute = function() RandomRoll(1, 100) end,
        getLabel = function() return L["KIT_ROLL"] end,
        getTooltip = function() return L["KIT_ROLL_TOOLTIP"] end
    },
    {
        key = "filter_toggle",
        category = "kit",
        appliesTo = { kits = { "filter" } },
        execute = function()
            if addon.db.plugin.filter then
                addon.db.plugin.filter.enabled = not addon.db.plugin.filter.enabled
                addon:ApplyFilterSettings()
                print(L["LABEL_FILTER"] .. " " .. (addon.db.plugin.filter.enabled and L["LABEL_STATUS_ENABLED"] or L["LABEL_STATUS_DISABLED"]))
            end
        end,
        getLabel = function() return L["KIT_FILTER"] end,
        getTooltip = function() return L["KIT_FILTER_TOOLTIP"] end
    },
    {
        key = "macro_toggle",
        category = "kit",
        appliesTo = { kits = { "macro" } },
        execute = function()
            if MacroFrame and MacroFrame:IsShown() then
                HideUIPanel(MacroFrame)
            else
                ShowMacroFrame()
            end
        end,
        getLabel = function() return L["KIT_MACRO"] end,
        getTooltip = function() return L["KIT_MACRO_TOOLTIP"] end
    },
    {
        key = "leave_party",
        category = "kit",
        appliesTo = { kits = { "leave" } },
        execute = function() C_PartyInfo.LeaveParty() end,
        getLabel = function() return L["KIT_LEAVE"] end,
        getTooltip = function() return L["KIT_LEAVE_TOOLTIP"] end
    },
    {
        key = "emote_panel",
        category = "kit",
        appliesTo = { kits = { "emotePanel" } },
        execute = function(self)
            if addon.ToggleEmotePanel then
                addon:ToggleEmotePanel(self)
            end
        end,
        getLabel = function() return L["KIT_EMOTE"] end,
        getTooltip = function() return L["KIT_EMOTE_TOOLTIP"] end
    },
    {
        key = "reload_ui",
        category = "kit",
        appliesTo = { kits = { "reload" } },
        execute = function() ReloadUI() end,
        getLabel = function() return L["KIT_RELOAD"] end,
        getTooltip = function() return L["KIT_RELOAD_TOOLTIP"] end
    },
}

-- =========================================================================
-- 构建 ACTION_REGISTRY (从 ACTION_DEFINITIONS 生成)
-- 这个函数应该在 Shelf 初始化时调用
-- =========================================================================

function addon:BuildActionRegistryFromDefinitions()
    local registry = {}

    -- 遍历所有 ACTION 定义
    for _, actionDef in ipairs(self.ACTION_DEFINITIONS or {}) do
        -- 如果 ACTION 声明了 streamPaths
        if actionDef.appliesTo and actionDef.appliesTo.streamPaths then
            for _, pathPattern in ipairs(actionDef.appliesTo.streamPaths) do
                -- 查找匹配此路径的所有 Stream
                for categoryKey, category in pairs(self.STREAM_REGISTRY or {}) do
                    for subKey, subCategory in pairs(category) do
                        local currentPath = categoryKey .. "." .. subKey
                        if currentPath == pathPattern then
                            -- 为这个子类别下的所有 Stream 生成 ACTION
                            for _, stream in ipairs(subCategory) do
                                local fullKey = actionDef.key .. "_" .. stream.key
                                local label = actionDef.getLabel and actionDef.getLabel(stream.key) or actionDef.label
                                
                                -- 统一前缀处理
                                if actionDef.category == "channel" and actionDef.key:match("send") then
                                    label = L["ACTION_PREFIX_SEND"] .. (label or "")
                                end

                                registry[fullKey] = {
                                    key = fullKey,
                                    label = label,
                                    tooltip = actionDef.getTooltip and actionDef.getTooltip(stream.key) or nil,
                                    streamKey = stream.key,
                                    category = actionDef.category,
                                    execute = function(...)
                                        actionDef.execute(stream.key, ...)
                                    end
                                }
                            end
                        end
                    end
                end
            end
        end

        -- 如果 ACTION 声明了特定的 streamKeys
        if actionDef.appliesTo and actionDef.appliesTo.streamKeys then
            for _, streamKey in ipairs(actionDef.appliesTo.streamKeys) do
                local fullKey = actionDef.key .. "_" .. streamKey
                local label = actionDef.getLabel and actionDef.getLabel(streamKey) or actionDef.label

                -- 统一前缀处理
                if actionDef.category == "channel" and actionDef.key:match("send") then
                    label = L["ACTION_PREFIX_SEND"] .. (label or "")
                end

                registry[fullKey] = {
                    key = fullKey,
                    label = label,
                    tooltip = actionDef.getTooltip and actionDef.getTooltip(streamKey) or nil,
                    streamKey = streamKey,
                    category = actionDef.category,
                    execute = function(...)
                        actionDef.execute(streamKey, ...)
                    end
                }
            end
        end

        -- 如果 ACTION 声明了 kits
        if actionDef.appliesTo and actionDef.appliesTo.kits then
            for _, kitKey in ipairs(actionDef.appliesTo.kits) do
                local fullKey = "kit_" .. kitKey .. "_" .. actionDef.key
                local label = actionDef.getLabel and actionDef.getLabel(kitKey) or actionDef.label

                -- 统一前缀处理：工具类
                if actionDef.category == "kit" then
                    label = L["ACTION_PREFIX_KIT"] .. (label or "")
                end

                registry[fullKey] = {
                    key = fullKey,
                    label = label,
                    tooltip = actionDef.getTooltip and actionDef.getTooltip(kitKey) or nil,
                    kitKey = kitKey,
                    category = "kit",
                    execute = actionDef.execute
                }
            end
        end
    end

    return registry
end
