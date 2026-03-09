local addonName, addon = ...

addon.Gateway = addon.Gateway or {}
local Gateway = addon.Gateway

Gateway.Inbound = Gateway.Inbound or {}
Gateway.Outbound = Gateway.Outbound or {}

function Gateway.Inbound:Allow(event, frame, ...)
    if addon.Profiler and addon.Profiler.Start then
        addon.Profiler:Start("ChatGateway.Inbound.Allow")
    end
    if not addon.db or not addon.db.enabled then
        if addon.Profiler and addon.Profiler.Stop then
            addon.Profiler:Stop("ChatGateway.Inbound.Allow")
        end
        return false
    end

    if addon.Can and not addon:Can(addon.CAPABILITIES.READ_CHAT_EVENT) then
        if addon.Profiler and addon.Profiler.Stop then
            addon.Profiler:Stop("ChatGateway.Inbound.Allow")
        end
        return false
    end

    if addon.Profiler and addon.Profiler.Stop then
        addon.Profiler:Stop("ChatGateway.Inbound.Allow")
    end
    return true
end

function Gateway.Outbound:SendChat(text, wowChatType, language, target)
    if addon.Can and not addon:Can(addon.CAPABILITIES.EMIT_CHAT_ACTION) then
        return false
    end

    if type(text) ~= "string" or text == "" then
        return false
    end

    SendChatMessage(text, wowChatType, language, target)
    return true
end
