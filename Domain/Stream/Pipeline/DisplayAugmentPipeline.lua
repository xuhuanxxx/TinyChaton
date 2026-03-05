local addonName, addon = ...

addon.DisplayAugmentPipeline = addon.DisplayAugmentPipeline or {}
local Pipeline = addon.DisplayAugmentPipeline

Pipeline.stageRegistry = Pipeline.stageRegistry or {}
Pipeline.stageOrdered = Pipeline.stageOrdered or {}
Pipeline.defaultsRegistered = Pipeline.defaultsRegistered or false

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

local function RunStages(self, phase, context)
    for _, stage in ipairs(self.stageOrdered) do
        if stage.phase == phase and type(stage.fn) == "function" then
            local ok, err = pcall(stage.fn, self, context)
            if not ok and addon.Warn then
                addon:Warn("DisplayAugment stage %s failed: %s", tostring(stage.name), tostring(err))
            end
        end
    end
end

local function RebuildOrdered(self)
    local ordered = {}
    for _, stage in pairs(self.stageRegistry) do
        ordered[#ordered + 1] = stage
    end
    table.sort(ordered, function(a, b)
        if a.priority ~= b.priority then
            return a.priority < b.priority
        end
        return tostring(a.name) < tostring(b.name)
    end)
    self.stageOrdered = ordered
end

function Pipeline:RegisterStage(name, priority, phase, fn)
    if type(name) ~= "string" or name == "" then
        return false, "invalid_name"
    end
    if type(priority) ~= "number" then
        return false, "invalid_priority"
    end
    if phase ~= "pre_render" and phase ~= "post_render" then
        return false, "invalid_phase"
    end
    if type(fn) ~= "function" then
        return false, "invalid_fn"
    end

    self.stageRegistry[name] = {
        name = name,
        priority = priority,
        phase = phase,
        fn = fn,
    }
    RebuildOrdered(self)
    return true
end

function Pipeline:UnregisterStage(name)
    if type(name) ~= "string" or name == "" or not self.stageRegistry[name] then
        return false
    end
    self.stageRegistry[name] = nil
    RebuildOrdered(self)
    return true
end

local function EnsureDefaultStages(self)
    if self.defaultsRegistered then
        return
    end

    self:RegisterStage("patch_prefix", 10, "pre_render", function(_, ctx)
        local env = ctx.envelope
        if type(env) ~= "table" or env.wowChatType ~= "CHANNEL" then
            return
        end
        local policy = addon.DisplayPolicyService
        if not policy or type(policy.ResolveChannelPrefix) ~= "function" then
            return
        end
        local hint = policy:ResolveChannelPrefix(env.streamKey, env.channelMeta)
        if type(hint) == "string" and hint ~= "" then
            ctx.renderOptions.channelPrefixHint = hint
        end
    end)

    self:RegisterStage("inject_send_link", 20, "pre_render", function(_, ctx)
        local policy = addon.DisplayPolicyService
        local streamKey = ctx.envelope and ctx.envelope.streamKey or nil
        ctx.renderOptions.enableSendLink = policy and policy.CanInjectSend and policy:CanInjectSend(streamKey) or false
    end)

    self:RegisterStage("inject_copy_timestamp", 30, "pre_render", function(_, ctx)
        local policy = addon.DisplayPolicyService
        local streamKey = ctx.envelope and ctx.envelope.streamKey or nil
        ctx.renderOptions.enableCopyLink = policy and policy.CanInjectCopy and policy:CanInjectCopy(streamKey) or false
    end)

    self:RegisterStage("apply_highlight", 40, "post_render", function(_, ctx)
        if type(ctx.displayText) ~= "string" or ctx.displayText == "" then
            return
        end
        if not addon.StreamHighlighter or type(addon.StreamHighlighter.ApplyDisplayText) ~= "function" then
            return
        end
        ctx.displayText = addon.StreamHighlighter:ApplyDisplayText(ctx.displayText, ctx.envelope and ctx.envelope.streamKey or nil)
    end)

    self:RegisterStage("apply_legacy_clean", 50, "post_render", function(_, ctx)
        if addon.CleanMessage and type(addon.CleanMessage.Process) == "function" then
            local nextText, nr, ng, nb, ne = addon.CleanMessage.Process(ctx.frame, ctx.displayText, ctx.r, ctx.g, ctx.b, ctx.extraArgs)
            ctx.displayText, ctx.r, ctx.g, ctx.b, ctx.extraArgs = nextText, nr, ng, nb, ne
        end
        if addon.StripPrefix and type(addon.StripPrefix.Apply) == "function" then
            ctx.displayText = addon.StripPrefix.Apply(ctx.displayText)
        end
    end)

    self.defaultsRegistered = true
end

function Pipeline:ClearStages()
    self.stageRegistry = {}
    self.stageOrdered = {}
    self.defaultsRegistered = false
end

function Pipeline:EnsureDefaultStages()
    EnsureDefaultStages(self)
end

function Pipeline:ListStages()
    EnsureDefaultStages(self)
    local out = {}
    for _, stage in ipairs(self.stageOrdered) do
        out[#out + 1] = {
            name = stage.name,
            priority = stage.priority,
            phase = stage.phase,
        }
    end
    return out
end

function Pipeline:Render(frame, envelope, opts)
    if type(envelope) ~= "table" then
        return nil, "invalid_envelope"
    end

    EnsureDefaultStages(self)

    local line = BuildLine(envelope)
    if type(line) ~= "table" then
        return nil, "invalid_line"
    end

    local context = {
        frame = frame,
        envelope = envelope,
        line = line,
        renderOptions = {
        preferTimestampConfig = envelope.mode == "replay",
            enableSendLink = false,
            enableCopyLink = false,
        },
        displayText = nil,
        r = nil,
        g = nil,
        b = nil,
        extraArgs = nil,
    }
    if type(opts) == "table" then
        for k, v in pairs(opts) do
            context.renderOptions[k] = v
        end
    end

    RunStages(self, "pre_render", context)

    local displayText, r, g, b, extraArgs = addon:RenderChatLine(line, frame, context.renderOptions)
    if type(displayText) ~= "string" then
        return nil, "render_failed"
    end
    context.displayText = displayText
    context.r = r
    context.g = g
    context.b = b
    context.extraArgs = extraArgs

    RunStages(self, "post_render", context)

    return {
        displayText = context.displayText,
        r = context.r,
        g = context.g,
        b = context.b,
        extraArgs = context.extraArgs,
        line = line,
    }
end

return Pipeline
