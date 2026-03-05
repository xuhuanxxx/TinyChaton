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

if not addon.TinyCoreRuntimeCapabilityMatrix or type(addon.TinyCoreRuntimeCapabilityMatrix.New) ~= "function" then
    error("TinyCore Runtime CapabilityMatrix is not initialized")
end

addon.RuntimeCapabilityMatrix = addon.RuntimeCapabilityMatrix
    or addon.TinyCoreRuntimeCapabilityMatrix:New(CAP_MATRIX, "ACTIVE")

function addon:Can(capability)
    local mode = self.GetChatRuntimeMode and self:GetChatRuntimeMode() or "ACTIVE"
    return addon.RuntimeCapabilityMatrix:Can(mode, capability)
end

function addon:EmitChatMessage(text, wowChatType, language, target)
    if self.Gateway and self.Gateway.Outbound and self.Gateway.Outbound.SendChat then
        return self.Gateway.Outbound:SendChat(text, wowChatType, language, target)
    end

    return false
end
