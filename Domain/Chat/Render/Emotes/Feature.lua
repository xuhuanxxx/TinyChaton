local addonName, addon = ...

addon.EmotesFeature = addon.EmotesFeature or {}
local Feature = addon.EmotesFeature

local function ShouldEnable(skipFeatureCheck)
    if not addon.db or not addon.db.enabled then
        return false
    end

    if not skipFeatureCheck and addon.IsFeatureEnabled and not addon:IsFeatureEnabled("EmotesRender") then
        return false
    end

    if addon.Can and addon.CAPABILITIES and not addon:Can(addon.CAPABILITIES.MUTATE_CHAT_DISPLAY) then
        return false
    end

    return addon:GetConfig("profile.chat.content.emoteRender", true)
end

function Feature:Reconcile(options)
    local opts = type(options) == "table" and options or {}
    local enable = ShouldEnable(opts.skipFeatureCheck == true)

    if addon.ChatLineEmoteAdapter and type(addon.ChatLineEmoteAdapter.Enable) == "function" then
        if enable then
            addon.ChatLineEmoteAdapter:Enable()
        else
            addon.ChatLineEmoteAdapter:Disable()
        end
    end

    if addon.ChatBubbleEmoteAdapter and type(addon.ChatBubbleEmoteAdapter.Reconcile) == "function" then
        addon.ChatBubbleEmoteAdapter:Reconcile(enable)
    end
end

function addon:InitEmotesFeature()
    local function Reconcile()
        Feature:Reconcile()
    end

    addon:RegisterFeature("EmotesRender", {
        requires = { "MUTATE_CHAT_DISPLAY" },
        plane = addon.RUNTIME_PLANES and addon.RUNTIME_PLANES.CHAT_DATA or "CHAT_DATA",
        onEnable = function()
            Feature:Reconcile({ skipFeatureCheck = true })
        end,
        onDisable = function()
            if addon.ChatLineEmoteAdapter then
                addon.ChatLineEmoteAdapter:Disable()
            end
            if addon.ChatBubbleEmoteAdapter then
                addon.ChatBubbleEmoteAdapter:Disable()
            end
        end,
    })

    if addon.RegisterCallback then
        addon:RegisterCallback("SETTINGS_INTENT_COMPLETED", Reconcile, "EmotesFeature")
        addon:RegisterCallback("CHAT_RUNTIME_MODE_CHANGED", Reconcile, "EmotesFeature")
    end
end

addon:RegisterModule("EmotesFeature", addon.InitEmotesFeature)
