local addonName, addon = ...
local L = addon.L

local function ResolveStreamLabel(stream)
    if not stream then return "" end
    local identity = addon.ResolveDisplayIdentity and addon:ResolveDisplayIdentity(stream, "channel", {}) or nil
    return (identity and identity.label) or stream.key or ""
end

local function ResolveSendPayload(intent, stream)
    if type(stream) ~= "table" or type(stream.wowChatType) ~= "string" or stream.wowChatType == "" then
        return nil, "target_unresolved"
    end

    local payload = {
        wowChatType = stream.wowChatType,
        streamKey = stream.key,
    }

    if stream.wowChatType == "CHANNEL" then
        local dynamic = addon.ResolveDynamicActiveName and addon:ResolveDynamicActiveName(stream, {}) or nil
        payload.channelName = dynamic and dynamic.activeName or nil

        local semantic = addon.ChannelSemanticResolver
        if semantic and type(semantic.ResolveDynamic) == "function" then
            local resolved = semantic.ResolveDynamic({
                streamKey = stream.key,
                channelName = payload.channelName,
            })
            payload.channelId = resolved and tonumber(resolved.channelId) or nil
        end

        if not payload.channelId or payload.channelId <= 0 then
            return nil, "target_unresolved"
        end
    end

    return payload
end

local function DefaultPayload(intent)
    if type(intent) ~= "table" then
        return {}
    end
    return type(intent.payload) == "table" and intent.payload or {}
end

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
        targetKind = "stream",
        actionPlane = "USER_ACTION",
        appliesTo = {
            streamCapabilities = { outbound = true },
            streamKind = "channel",
        },
        normalizePayload = function(intent, stream)
            return ResolveSendPayload(intent, stream)
        end,
        execute = function(_, _, payload)
            return addon:OpenChatForActionSend(payload)
        end,
        getLabel = function(streamKey)
            local stream = addon:GetStreamByKey(streamKey)
            return ResolveStreamLabel(stream)
        end,
        getTooltip = function()
            return L["TOOLTIP_SEND_TO"]
        end
    },

    -- =====================================================================
    -- [MUTE_TOGGLE] Stream visibility toggle
    -- =====================================================================
    {
        key = "mute_toggle",
        label = L["ACTION_MUTE_TOGGLE"],
        category = "channel",
        targetKind = "stream",
        actionPlane = "CHAT_DATA",
        appliesTo = {
            streamCapabilities = { supportsMute = true },
            streamKind = "channel",
        },
        normalizePayload = function(intent)
            return DefaultPayload(intent)
        end,
        execute = function(_, stream)
            local streamKey = stream and stream.key or nil
            if type(streamKey) ~= "string" or streamKey == "" then
                return false, "invalid_target"
            end
            if addon.StreamVisibilityService and addon.StreamVisibilityService.ToggleStreamBlocked then
                addon.StreamVisibilityService:ToggleStreamBlocked(streamKey)
            end
            if addon.RefreshShelf then
                addon:RefreshShelf()
            end
            return true
        end,
        getLabel = function(streamKey)
            local stream = addon:GetStreamByKey(streamKey)
            local label = ResolveStreamLabel(stream)
            if label ~= "" then
                return L["ACTION_MUTE_TOGGLE"] .. " " .. label
            end
            return L["ACTION_MUTE_TOGGLE"]
        end,
        getTooltip = function()
            return L["TOOLTIP_MUTE_TOGGLE"]
        end
    },

    -- =====================================================================
    -- [KIT ACTIONS] 工具按钮操作
    -- =====================================================================
    {
        key = "readycheck",
        category = "kit",
        targetKind = "kit",
        actionPlane = "UI_ONLY",
        appliesTo = { kits = { "readyCheck" } },
        normalizePayload = function(intent)
            return DefaultPayload(intent)
        end,
        execute = function()
            DoReadyCheck()
            return true
        end,
        getLabel = function() return L["KIT_READYCHECK"] end,
        getTooltip = function() return L["KIT_READYCHECK_TOOLTIP"] end
    },
    {
        key = "reset_instances",
        category = "kit",
        targetKind = "kit",
        actionPlane = "UI_ONLY",
        appliesTo = { kits = { "resetInstances" } },
        normalizePayload = function(intent)
            return DefaultPayload(intent)
        end,
        execute = function()
            ResetInstances()
            return true
        end,
        getLabel = function() return L["KIT_RESET_INSTANCES"] end,
        getTooltip = function() return L["KIT_RESET_INSTANCES_TOOLTIP"] end
    },
    {
        key = "countdown_primary",
        category = "kit",
        targetKind = "kit",
        actionPlane = "UI_ONLY",
        appliesTo = { kits = { "countdown" } },
        normalizePayload = function(intent)
            return DefaultPayload(intent)
        end,
        execute = function()
            local countdown = addon.db and addon.db.profile and addon.db.profile.automation and addon.db.profile.automation.countdown
            C_PartyInfo.DoCountdown(countdown and countdown.primarySeconds or 10)
            return true
        end,
        getLabel = function() return L["ACTION_TIMER_PRIMARY"] end,
        getTooltip = function() return L["ACTION_TIMER_PRIMARY_DESC"] end
    },
    {
        key = "countdown_secondary",
        category = "kit",
        targetKind = "kit",
        actionPlane = "UI_ONLY",
        appliesTo = { kits = { "countdown" } },
        normalizePayload = function(intent)
            return DefaultPayload(intent)
        end,
        execute = function()
            local countdown = addon.db and addon.db.profile and addon.db.profile.automation and addon.db.profile.automation.countdown
            C_PartyInfo.DoCountdown(countdown and countdown.secondarySeconds or 5)
            return true
        end,
        getLabel = function() return L["ACTION_TIMER_SECONDARY"] end,
        getTooltip = function() return L["ACTION_TIMER_SECONDARY_DESC"] end
    },
    {
        key = "countdown_cancel",
        category = "kit",
        targetKind = "kit",
        actionPlane = "UI_ONLY",
        appliesTo = { kits = { "countdown" } },
        normalizePayload = function(intent)
            return DefaultPayload(intent)
        end,
        execute = function()
            C_PartyInfo.DoCountdown(0)
            return true
        end,
        getLabel = function() return L["ACTION_CANCEL"] end,
        getTooltip = function() return L["ACTION_CANCEL"] end
    },
    {
        key = "roll",
        category = "kit",
        targetKind = "kit",
        actionPlane = "UI_ONLY",
        appliesTo = { kits = { "roll" } },
        normalizePayload = function(intent)
            return DefaultPayload(intent)
        end,
        execute = function()
            RandomRoll(1, 100)
            return true
        end,
        getLabel = function() return L["KIT_ROLL"] end,
        getTooltip = function() return L["KIT_ROLL_TOOLTIP"] end
    },
    {
        key = "macro_toggle",
        category = "kit",
        targetKind = "kit",
        actionPlane = "UI_ONLY",
        appliesTo = { kits = { "macro" } },
        normalizePayload = function(intent)
            return DefaultPayload(intent)
        end,
        execute = function()
            if MacroFrame and MacroFrame:IsShown() then
                HideUIPanel(MacroFrame)
            else
                ShowMacroFrame()
            end
            return true
        end,
        getLabel = function() return L["KIT_MACRO"] end,
        getTooltip = function() return L["KIT_MACRO_TOOLTIP"] end
    },
    {
        key = "leave_party",
        category = "kit",
        targetKind = "kit",
        actionPlane = "UI_ONLY",
        appliesTo = { kits = { "leave" } },
        normalizePayload = function(intent)
            return DefaultPayload(intent)
        end,
        execute = function()
            C_PartyInfo.LeaveParty()
            return true
        end,
        getLabel = function() return L["KIT_LEAVE"] end,
        getTooltip = function() return L["KIT_LEAVE_TOOLTIP"] end
    },
    {
        key = "emote_panel",
        category = "kit",
        targetKind = "kit",
        actionPlane = "USER_ACTION",
        appliesTo = { kits = { "emotePanel" } },
        normalizePayload = function(intent)
            local context = type(intent) == "table" and intent.context or nil
            return {
                buttonFrame = context and context.buttonFrame or nil,
            }
        end,
        execute = function(_, _, payload)
            if addon.ToggleEmotePanel then
                addon:ToggleEmotePanel(payload and payload.buttonFrame or nil)
            end
            return true
        end,
        getLabel = function() return L["KIT_EMOTE"] end,
        getTooltip = function() return L["KIT_EMOTE_TOOLTIP"] end
    },
    {
        key = "reload_ui",
        category = "kit",
        targetKind = "kit",
        actionPlane = "UI_ONLY",
        appliesTo = { kits = { "reload" } },
        normalizePayload = function(intent)
            return DefaultPayload(intent)
        end,
        execute = function()
            ReloadUI()
            return true
        end,
        getLabel = function() return L["KIT_RELOAD"] end,
        getTooltip = function() return L["KIT_RELOAD_TOOLTIP"] end
    },
}

-- =========================================================================
-- 构建 ACTION_REGISTRY (从 ACTION_DEFINITIONS 生成)
-- 这个函数应该在 Shelf 初始化时调用
-- =========================================================================

function addon:BuildActionRegistryFromDefinitions()
    if not addon.TinyCoreRegistryCompiler or type(addon.TinyCoreRegistryCompiler.New) ~= "function" then
        error("TinyCore RegistryCompiler is not initialized")
    end
    if not addon.TinyCoreRegistryActionPasses or type(addon.TinyCoreRegistryActionPasses.CreatePipeline) ~= "function" then
        error("TinyCore Registry ActionPasses is not initialized")
    end

    self._actionRegistryCompiler = self._actionRegistryCompiler or addon.TinyCoreRegistryCompiler:New({
        passes = addon.TinyCoreRegistryActionPasses.CreatePipeline(),
    })

    return self._actionRegistryCompiler:Run(self.ACTION_DEFINITIONS or {}, {
        iterateCompiledStreams = function()
            return self:IterateCompiledStreams()
        end,
        getStreamCapabilities = function(streamKey)
            return self:GetStreamCapabilities(streamKey)
        end,
        actionPrefixSend = L["ACTION_PREFIX_SEND"] or "",
        actionPrefixKit = L["ACTION_PREFIX_KIT"] or "",
    })
end
