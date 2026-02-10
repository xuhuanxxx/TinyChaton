local addonName, addon = ...

addon.Gateway = addon.Gateway or {}
local Gateway = addon.Gateway

Gateway.Inbound = Gateway.Inbound or {}
Gateway.Display = Gateway.Display or {}
Gateway.Outbound = Gateway.Outbound or {}

function Gateway.Inbound:Allow(event, frame, ...)
    if not addon.db or not addon.db.enabled then
        return false
    end

    if addon.Can and not addon:Can(addon.CAPABILITIES.READ_CHAT_EVENT) then
        return false
    end

    return true
end

function Gateway.Display:Transform(frame, msg, ...)
    if addon.Can and not addon:Can(addon.CAPABILITIES.MUTATE_CHAT_DISPLAY) then
        return msg, ...
    end

    if type(msg) ~= "string" then
        return msg, ...
    end

    for _, name in ipairs(addon.TRANSFORMER_ORDER or {}) do
        local fn = addon.chatFrameTransformers and addon.chatFrameTransformers[name]
        if fn then
            local ok, result = pcall(fn, frame, msg, ...)
            if ok and result ~= nil then
                msg = result
            end
        end
    end

    return msg, ...
end

function Gateway.Outbound:SendChat(text, chatType, language, target)
    if addon.Can and not addon:Can(addon.CAPABILITIES.EMIT_CHAT_ACTION) then
        return false
    end

    if type(text) ~= "string" or text == "" then
        return false
    end

    SendChatMessage(text, chatType, language, target)
    return true
end
