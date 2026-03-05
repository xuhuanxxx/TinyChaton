local addonName, addon = ...

addon.FrameDisplayHookService = addon.FrameDisplayHookService or {}
local Service = addon.FrameDisplayHookService

Service.hookedFrames = Service.hookedFrames or {}

local function GetFrameKey(frame)
    if addon.FrameResolver and type(addon.FrameResolver.GetFrameName) == "function" then
        local name = addon.FrameResolver:GetFrameName(frame)
        if type(name) == "string" and name ~= "" then
            return name
        end
    end
    return tostring(frame)
end

local function ResolveLineId(...)
    local packed = addon.Utils and addon.Utils.PackArgs and addon.Utils.PackArgs(...) or { ... }
    for i = 1, packed.n or #packed do
        local value = packed[i]
        if type(value) == "number" then
            return value
        end
    end
    return nil
end

function Service:EnsureHook(frame)
    if type(frame) ~= "table" or type(frame.AddMessage) ~= "function" then
        return false
    end

    local key = GetFrameKey(frame)
    if self.hookedFrames[key] then
        return true
    end

    local origAddMessage = frame.AddMessage
    frame._TinyChatonOrigAddMessage = frame._TinyChatonOrigAddMessage or origAddMessage
    frame._TinyChatonHookedAddMessage = true

    frame.AddMessage = function(targetFrame, msg, ...)
        if targetFrame._TinyChatonInAddMessageHook then
            return origAddMessage(targetFrame, msg, ...)
        end

        targetFrame._TinyChatonInAddMessageHook = true

        local finalMsg = msg
        local lineId = ResolveLineId(...)
        local bridge = addon.RealtimeDisplayBridge
        local envelope = bridge and bridge.Consume and bridge:Consume(targetFrame, msg, lineId) or nil
        if type(envelope) == "table" and addon.DisplayAugmentPipeline and addon.DisplayAugmentPipeline.Render then
            local rendered = addon.DisplayAugmentPipeline:Render(targetFrame, envelope)
            if type(rendered) == "table" and type(rendered.displayText) == "string" then
                finalMsg = rendered.displayText
            end
        end

        local ok, result = pcall(origAddMessage, targetFrame, finalMsg, ...)
        targetFrame._TinyChatonInAddMessageHook = nil

        if not ok then
            error(result)
        end
        return result
    end

    self.hookedFrames[key] = true
    return true
end

return Service
