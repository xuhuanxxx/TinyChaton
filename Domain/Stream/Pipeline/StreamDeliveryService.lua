local addonName, addon = ...

addon.StreamDeliveryService = addon.StreamDeliveryService or {}
local Service = addon.StreamDeliveryService

function Service:DeliverRealtime(frame, event, streamContext, packedArgs, options)
    local shouldHide = type(options) == "table" and options.shouldHide == true
    if shouldHide then
        return true
    end

    if not packedArgs or type(packedArgs[1]) ~= "string" then
        return false, addon.Utils.UnpackArgs(packedArgs)
    end

    local targetFrame = addon.FrameResolver:ResolveRealtime(frame, event)
    if type(targetFrame) == "table" then
        local envelope = addon.DisplayEnvelope and addon.DisplayEnvelope.FromRealtime
            and addon.DisplayEnvelope.FromRealtime(targetFrame, event, streamContext)
            or nil

        if type(envelope) == "table" and addon.RealtimeDisplayBridge and addon.RealtimeDisplayBridge.Push then
            addon.RealtimeDisplayBridge:Push(targetFrame, envelope)
        end

        if addon.FrameDisplayHookService and addon.FrameDisplayHookService.EnsureHook then
            addon.FrameDisplayHookService:EnsureHook(targetFrame)
        end
    end
    return false, addon.Utils.UnpackArgs(packedArgs)
end

function Service:DeliverReplay(line, options)
    local frame = type(options) == "table" and options.frame or nil
    if not frame then frame = addon.FrameResolver:ResolveReplay(line) end
    if type(frame) ~= "table" then
        return false
    end

    local envelope = addon.DisplayEnvelope and addon.DisplayEnvelope.FromReplayLine
        and addon.DisplayEnvelope.FromReplayLine(line, frame)
        or nil
    if type(envelope) ~= "table" then
        return false
    end

    local rendered = addon.DisplayAugmentPipeline and addon.DisplayAugmentPipeline.Render
        and addon.DisplayAugmentPipeline:Render(frame, envelope)
        or nil
    if type(rendered) ~= "table" or type(rendered.displayText) ~= "string" then
        return false
    end

    local addMessageFn = frame.AddMessage
    if type(addMessageFn) ~= "function" then
        return false
    end

    addMessageFn(frame, rendered.displayText, addon.Utils.UnpackArgs(rendered.extraArgs))
    return true
end
