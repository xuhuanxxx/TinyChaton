local addonName, addon = ...

addon.DisplayRenderOrchestrator = addon.DisplayRenderOrchestrator or {}
local Orchestrator = addon.DisplayRenderOrchestrator

local function BuildLine(envelope)
    if type(envelope) ~= "table" then
        return nil
    end

    local meta = type(envelope.channelMeta) == "table" and envelope.channelMeta or {}
    local normalized = meta.channelBaseName
    if normalized and addon.Utils and addon.Utils.NormalizeChannelBaseName then
        normalized = addon.Utils.NormalizeChannelBaseName(normalized)
    end

    local streamMeta = nil
    if envelope.wowChatType == "CHANNEL" then
        streamMeta = {
            channelId = meta.channelId,
            channelBaseName = meta.channelBaseName,
            channelBaseNameNormalized = normalized,
        }
    end

    return {
        text = type(envelope.rawText) == "string" and envelope.rawText or "",
        author = type(envelope.author) == "string" and envelope.author or "",
        wowChatType = envelope.wowChatType,
        streamKey = envelope.streamKey,
        kind = envelope.streamKind,
        group = envelope.streamGroup,
        streamMeta = streamMeta,
        time = envelope.timestamp or time(),
        classFilename = envelope.classFilename,
    }
end

local function CreateExtraArgs(r, g, b, streamKey)
    local extraArgs = addon.Utils and addon.Utils.PackArgs and addon.Utils.PackArgs(r, g, b) or { r, g, b }
    if type(extraArgs) == "table" then
        extraArgs[1], extraArgs[2], extraArgs[3] = r, g, b
        extraArgs.n = extraArgs.n or 3
        if type(streamKey) == "string" and streamKey ~= "" then
            extraArgs.streamKey = streamKey
        end
    end
    return extraArgs
end

local function CreateContext(frame, envelope, line, opts)
    local renderOptions = {
        preferTimestampConfig = envelope.mode == "replay",
    }
    if type(opts) == "table" then
        for k, v in pairs(opts) do
            renderOptions[k] = v
        end
    end

    local context = {
        frame = frame,
        envelope = envelope,
        line = line,
        renderOptions = renderOptions,
        displayText = nil,
        r = nil,
        g = nil,
        b = nil,
        extraArgs = nil,
    }

    if addon.ValidateContract then
        addon:ValidateContract("DisplayAugmentContext", context)
    end

    return context
end

function Orchestrator:RenderEnvelope(frame, envelope, opts)
    if type(envelope) ~= "table" then
        return nil, "invalid_envelope"
    end
    if addon.ValidateContract then
        addon:ValidateContract("DisplayEnvelope", envelope)
    end

    local line = BuildLine(envelope)
    if type(line) ~= "table" then
        return nil, "invalid_line"
    end

    local context = CreateContext(frame, envelope, line, opts)
    if addon.DisplayAugmentPipeline and addon.DisplayAugmentPipeline.ExecutePhase then
        addon.DisplayAugmentPipeline:ExecutePhase("pre_render", context)
    end

    local displayText, r, g, b = addon.MessageFormatter.BuildDisplayLine(line, context.renderOptions)
    if type(displayText) ~= "string" then
        return nil, "render_failed"
    end

    context.displayText = displayText
    context.r = type(r) == "number" and r or 1
    context.g = type(g) == "number" and g or 1
    context.b = type(b) == "number" and b or 1
    context.extraArgs = CreateExtraArgs(context.r, context.g, context.b, line.streamKey)

    if addon.ValidateContract then
        addon:ValidateContract("DisplayAugmentContext", context)
    end

    if addon.DisplayAugmentPipeline and addon.DisplayAugmentPipeline.ExecutePhase then
        addon.DisplayAugmentPipeline:ExecutePhase("pre_transform", context)
    end

    local targetFrame = frame or ChatFrame1
    local extraArgs = context.extraArgs
    if addon.Gateway and addon.Gateway.Display and addon.Gateway.Display.Transform then
        displayText, r, g, b, extraArgs = addon.Gateway.Display:Transform(
            targetFrame,
            context.displayText,
            context.r,
            context.g,
            context.b,
            extraArgs
        )
    end

    context.displayText = displayText
    context.r = type(r) == "number" and r or 1
    context.g = type(g) == "number" and g or 1
    context.b = type(b) == "number" and b or 1
    context.extraArgs = type(extraArgs) == "table" and extraArgs or CreateExtraArgs(context.r, context.g, context.b, line.streamKey)

    if addon.ValidateContract then
        addon:ValidateContract("DisplayAugmentContext", context)
    end

    if addon.DisplayAugmentPipeline and addon.DisplayAugmentPipeline.ExecutePhase then
        addon.DisplayAugmentPipeline:ExecutePhase("post_render", context)
    end

    local debug = {
        sourceMode = envelope.mode,
        stagesApplied = type(addon.DisplayAugmentPipeline) == "table" and addon.DisplayAugmentPipeline:GetStageNames() or {},
        prefixPatched = context.renderOptions.prefixPatched == true,
        sendInjected = context.renderOptions.sendInjected == true,
        copyInjected = context.renderOptions.copyInjected == true,
        highlightApplied = context.renderOptions.highlightApplied == true,
    }

    return addon.DisplayRenderResult.Create(
        context.displayText,
        context.r,
        context.g,
        context.b,
        context.extraArgs,
        line,
        debug
    ), nil
end

return Orchestrator
