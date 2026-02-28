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

function Gateway.Display:Transform(frame, msg, r, g, b, extraArgs)
    if addon.Can and not addon:Can(addon.CAPABILITIES.MUTATE_CHAT_DISPLAY) then
        return msg, r, g, b, (type(extraArgs) == "table" and extraArgs or {})
    end

    if type(msg) ~= "string" then
        return msg, r, g, b, (type(extraArgs) == "table" and extraArgs or {})
    end

    local currentMsg, currentR, currentG, currentB = msg, r, g, b
    local currentExtra = type(extraArgs) == "table" and extraArgs or {}

    for _, name in ipairs(addon.TRANSFORMER_ORDER or {}) do
        local fn = addon.chatFrameTransformers and addon.chatFrameTransformers[name]
        if fn then
            local ok, nextMsg, nextR, nextG, nextB, nextExtra = pcall(fn, frame, currentMsg, currentR, currentG, currentB, currentExtra)
            if ok then
                if type(nextMsg) == "string" then
                    currentMsg = nextMsg
                end
                if type(nextR) == "number" then
                    currentR = nextR
                end
                if type(nextG) == "number" then
                    currentG = nextG
                end
                if type(nextB) == "number" then
                    currentB = nextB
                end
                if type(nextExtra) == "table" then
                    currentExtra = nextExtra
                elseif nextExtra ~= nil and addon.Warn then
                    addon:Warn("Transformer %s returned invalid extraArgs type: %s", tostring(name), type(nextExtra))
                end
            elseif addon.Warn then
                addon:Warn("Transformer %s failed: %s", tostring(name), tostring(nextMsg))
            end
        end
    end

    return currentMsg, currentR, currentG, currentB, currentExtra
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
