local addonName, addon = ...

addon.CAPABILITIES = addon.CAPABILITIES or {
    READ_CHAT_EVENT = "READ_CHAT_EVENT",
    PROCESS_CHAT_DATA = "PROCESS_CHAT_DATA",
    PERSIST_CHAT_DATA = "PERSIST_CHAT_DATA",
    MUTATE_CHAT_DISPLAY = "MUTATE_CHAT_DISPLAY",
    EMIT_CHAT_ACTION = "EMIT_CHAT_ACTION",
}

local CAP_MATRIX = {
    ACTIVE = {
        READ_CHAT_EVENT = true,
        PROCESS_CHAT_DATA = true,
        PERSIST_CHAT_DATA = true,
        MUTATE_CHAT_DISPLAY = true,
        EMIT_CHAT_ACTION = true,
    },
    BYPASS = {
        READ_CHAT_EVENT = false,
        PROCESS_CHAT_DATA = false,
        PERSIST_CHAT_DATA = false,
        MUTATE_CHAT_DISPLAY = false,
        EMIT_CHAT_ACTION = false,
    },
}

function addon:Can(capability)
    if not capability then
        return true
    end
    local mode = self.GetChatRuntimeMode and self:GetChatRuntimeMode() or "ACTIVE"
    local row = CAP_MATRIX[mode] or CAP_MATRIX.ACTIVE
    return row[capability] == true
end

function addon:EmitChatMessage(text, chatType, language, target)
    if self.Gateway and self.Gateway.Outbound and self.Gateway.Outbound.SendChat then
        return self.Gateway.Outbound:SendChat(text, chatType, language, target)
    end

    if not self:Can(self.CAPABILITIES.EMIT_CHAT_ACTION) then
        return false
    end

    SendChatMessage(text, chatType, language, target)
    return true
end

function addon:InitPolicyEngine()
    -- Deprecated entrypoint kept for compatibility with existing bootstrap calls.
    return
end
