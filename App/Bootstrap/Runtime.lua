local addonName, addon = ...

addon.chatFrameTransformers = addon.chatFrameTransformers or {}
addon.callbacks = addon.callbacks or {}
addon.moduleRegistry = addon.moduleRegistry or {}

-- No addon global bridge: keep runtime references explicit and local-only.
if _G.TinyChaton == addon then
    _G.TinyChaton = nil
end

function addon:RegisterCallback(event, func, owner)
    if not event or not func then return end
    if not self.callbacks[event] then
        self.callbacks[event] = {}
    end
    table.insert(self.callbacks[event], { func = func, owner = owner })
end

function addon:UnregisterCallback(event, owner)
    if not self.callbacks[event] or owner == nil then return end
    for i = #self.callbacks[event], 1, -1 do
        if self.callbacks[event][i].owner == owner then
            table.remove(self.callbacks[event], i)
        end
    end
end

function addon:FireEvent(event, ...)
    if not self.callbacks[event] then return end
    for _, handler in ipairs(self.callbacks[event]) do
        if handler.func then
            local ok, err = pcall(handler.func, ...)
            if not ok and addon.Error then
                addon:Error("Error in event %s: %s", tostring(event), tostring(err))
            end
        end
    end
end

function addon:RegisterChatFrameTransformer(name, fn)
    if not name or not fn then return end
    self.chatFrameTransformers[name] = fn
end

addon.TRANSFORMER_ORDER = addon.TRANSFORMER_ORDER or {
    "display_strip_prefix",
    "display_highlight",
    "clean_message",
    "channel_formatter",
    "interaction_timestamp",
    "visual_emotes",
}

function addon:RegisterModule(name, initFn)
    if not name or not initFn then
        if addon.Error then
            addon:Error("Attempted to register invalid module: %s", tostring(name))
        end
        return
    end
    table.insert(self.moduleRegistry, { name = name, init = initFn })
end
