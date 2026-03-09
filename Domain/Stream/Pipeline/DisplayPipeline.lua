local addonName, addon = ...

addon.DisplayPipeline = addon.DisplayPipeline or {}
local Pipeline = addon.DisplayPipeline

local PREFIX_TOKEN = addon.MessageFormatter and addon.MessageFormatter.PREFIX_TOKEN or "<<TC_PREFIX>>"

local function EscapePattern(s)
    return (tostring(s):gsub("([%%%(%)%.%+%-%*%?%[%]%^%$])", "%%%1"))
end

local function ExtractTimestampPrefix(displayText)
    if type(displayText) ~= "string" or displayText == "" then
        return nil, nil
    end

    local ts, finish = displayText:match("^(|c%x%x%x%x%x%x%x%x.-%s|r)()")
    if type(ts) == "string" and ts ~= "" then
        return ts, finish
    end

    local plainTs, plainFinish = displayText:match("^(%b[]%s)()")
    if type(plainTs) == "string" and plainTs ~= "" then
        return plainTs, plainFinish
    end

    return nil, nil
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

local function CreateContext(frame, message, opts)
    local renderOptions = {
        preferTimestampConfig = message.sourceMode == "replay",
    }
    if type(opts) == "table" then
        for key, value in pairs(opts) do
            renderOptions[key] = value
        end
    end

    local context = {
        frame = frame,
        message = message,
        renderOptions = renderOptions,
        displayText = nil,
        r = nil,
        g = nil,
        b = nil,
        extraArgs = nil,
    }

    if addon.ValidateContract then
        addon:ValidateContract("DisplayPipelineContext", context)
    end

    return context
end

local function ResolvePrefixDisplay(message)
    if type(message) ~= "table" then
        return ""
    end

    local streamKey = message.streamKey
    if type(streamKey) ~= "string" or streamKey == "" then
        return ""
    end

    local normalizedName = message.channelNameObserved
    if type(normalizedName) == "string" and normalizedName ~= "" and addon.Utils and addon.Utils.NormalizeChannelBaseName then
        normalizedName = addon.Utils.NormalizeChannelBaseName(normalizedName)
    end

    local displayText = addon.Utils.ResolveChannelDisplay({
        wowChatType = message.wowChatType,
        streamMeta = {
            channelId = message.channelId,
            channelBaseName = normalizedName,
        },
        streamKey = streamKey,
    })

    local policy = addon.DisplayPolicyService
    if policy and type(policy.ResolveChannelPrefix) == "function" then
        local hint = policy:ResolveChannelPrefix(message)
        if type(hint) == "string" and hint ~= "" then
            displayText = "[" .. hint .. "] "
        end
    end

    local chatTypeForColor = message.wowChatType
    if message.wowChatType == "CHANNEL" and message.channelId then
        chatTypeForColor = "CHANNEL" .. tostring(message.channelId)
    end
    if ChatTypeInfo and chatTypeForColor and ChatTypeInfo[chatTypeForColor] then
        local info = ChatTypeInfo[chatTypeForColor]
        displayText = string.format("|cff%02x%02x%02x%s|r",
            (info.r or 1) * 255,
            (info.g or 1) * 255,
            (info.b or 1) * 255,
            displayText)
    end

    return displayText
end

local function ApplyPrefixInteraction(context)
    if type(context.displayText) ~= "string" or context.displayText == "" then
        return
    end
    if not context.displayText:find(PREFIX_TOKEN, 1, true) then
        return
    end

    local prefix = ResolvePrefixDisplay(context.message)
    if prefix == "" then
        context.displayText = context.displayText:gsub(EscapePattern(PREFIX_TOKEN), "", 1)
        context.renderOptions.prefixState = "elided"
        return
    end

    local policy = addon.DisplayPolicyService
    local prefixInteraction = policy and policy.ResolvePrefixInteraction and policy:ResolvePrefixInteraction(context.frame, context.message) or nil
    if type(prefixInteraction) == "table"
        and type(prefixInteraction.interactionId) == "string"
        and prefixInteraction.interactionId ~= ""
        and addon.ChatLinkAdapter
        and type(addon.ChatLinkAdapter.BuildLink) == "function" then
        prefix = addon.ChatLinkAdapter:BuildLink(prefixInteraction.interactionId, prefix)
    end

    context.displayText = context.displayText:gsub(EscapePattern(PREFIX_TOKEN), prefix, 1)
    context.renderOptions.prefixState = "linked"
    context.renderOptions.sendInjected = type(prefixInteraction) == "table"
        and type(prefixInteraction.leftActionKey) == "string"
        and prefixInteraction.leftActionKey ~= ""
end

local function InjectTimestampCopy(context)
    if type(context.displayText) ~= "string" or context.displayText == "" then
        context.renderOptions.timestampCopyState = "empty"
        return
    end
    if context.displayText:find("|Htinychat:copy:", 1, true) then
        context.renderOptions.timestampCopyState = "already_injected"
        return
    end

    local policy = addon.DisplayPolicyService
    local streamKey = context.message and context.message.streamKey or nil
    local copyEnabled = policy and policy.CanInjectCopy and policy:CanInjectCopy(streamKey) or false
    if not copyEnabled then
        context.renderOptions.timestampCopyState = "disabled"
        return
    end

    local ts, finish = ExtractTimestampPrefix(context.displayText)
    if type(ts) ~= "string" or type(finish) ~= "number" then
        context.renderOptions.timestampCopyState = "timestamp_not_found"
        return
    end

    local plainTs = ts:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    local trimmedTs = plainTs:gsub("%s+$", "")
    if trimmedTs == "" then
        context.renderOptions.timestampCopyState = "timestamp_empty"
        return
    end

    local rest = context.displayText:sub(finish)
    local service = addon.TimestampCopyService
    if not service or type(service.BuildLink) ~= "function" then
        context.renderOptions.timestampCopyState = "service_missing"
        return
    end

    local colorHex = addon.MessageFormatter.ResolveTimestampColor({ r = context.r, g = context.g, b = context.b },
        context.renderOptions.preferTimestampConfig == true)
    local payload = trimmedTs
    if rest ~= "" then
        payload = payload .. " " .. rest
    end
    local linkified = service:BuildLink(trimmedTs, payload, colorHex)
    if type(linkified) ~= "string" or linkified == "" then
        context.renderOptions.timestampCopyState = "placeholder"
        return
    end

    context.displayText = linkified .. rest
    context.renderOptions.timestampCopyState = "injected"
    context.renderOptions.copyInjected = true
end

local function ApplyHighlight(context)
    if type(context.displayText) ~= "string" or context.displayText == "" then
        return
    end
    if not addon.StreamHighlighter or type(addon.StreamHighlighter.ApplyDisplayText) ~= "function" then
        return
    end

    local nextText = addon.StreamHighlighter:ApplyDisplayText(context.displayText, context.message and context.message.streamKey or nil)
    if type(nextText) == "string" and nextText ~= context.displayText then
        context.displayText = nextText
        context.renderOptions.highlightApplied = true
    end
end

local function ApplyEmotes(context)
    if type(context.displayText) ~= "string" or context.displayText == "" then
        return
    end
    if not addon.ChatLineEmoteAdapter or type(addon.ChatLineEmoteAdapter.Apply) ~= "function" then
        return
    end

    local nextText, nr, ng, nb, ne = addon.ChatLineEmoteAdapter:Apply(
        context.displayText,
        context.r,
        context.g,
        context.b,
        context.extraArgs
    )
    context.displayText = nextText
    context.r = type(nr) == "number" and nr or context.r
    context.g = type(ng) == "number" and ng or context.g
    context.b = type(nb) == "number" and nb or context.b
    context.extraArgs = type(ne) == "table" and ne or context.extraArgs
end

local function ApplyCleanup(context)
    if addon.CleanMessage and type(addon.CleanMessage.Process) == "function" then
        local nextText, nr, ng, nb, ne = addon.CleanMessage.Process(
            context.frame,
            context.displayText,
            context.r,
            context.g,
            context.b,
            context.extraArgs
        )
        context.displayText = nextText
        context.r = type(nr) == "number" and nr or context.r
        context.g = type(ng) == "number" and ng or context.g
        context.b = type(nb) == "number" and nb or context.b
        context.extraArgs = type(ne) == "table" and ne or context.extraArgs
    end
    if addon.StripPrefix and type(addon.StripPrefix.Apply) == "function" then
        context.displayText = addon.StripPrefix.Apply(context.displayText)
    end
end

function Pipeline:Render(frame, message, opts)
    if addon.Profiler and addon.Profiler.Start then
        addon.Profiler:Start("DisplayPipeline.Render")
    end
    if type(message) ~= "table" then
        if addon.Profiler and addon.Profiler.Stop then
            addon.Profiler:Stop("DisplayPipeline.Render")
        end
        return nil, "invalid_display_message"
    end
    if addon.ValidateContract then
        addon:ValidateContract("DisplayMessage", message)
    end

    local context = CreateContext(frame, message, opts)
    local displayText, r, g, b = addon.MessageFormatter.BuildDisplayLine(message, context.renderOptions)
    if type(displayText) ~= "string" then
        if addon.Profiler and addon.Profiler.Stop then
            addon.Profiler:Stop("DisplayPipeline.Render")
        end
        return nil, "render_failed"
    end

    context.displayText = displayText
    context.r = type(r) == "number" and r or 1
    context.g = type(g) == "number" and g or 1
    context.b = type(b) == "number" and b or 1
    context.extraArgs = CreateExtraArgs(context.r, context.g, context.b, message.streamKey)

    ApplyPrefixInteraction(context)
    InjectTimestampCopy(context)
    ApplyHighlight(context)
    ApplyEmotes(context)
    ApplyCleanup(context)

    local debug = {
        sourceMode = message.sourceMode,
        prefixState = context.renderOptions.prefixState or "none",
        sendInjected = context.renderOptions.sendInjected == true,
        copyInjected = context.renderOptions.copyInjected == true,
        timestampCopyState = context.renderOptions.timestampCopyState or "skipped",
        highlightApplied = context.renderOptions.highlightApplied == true,
    }

    local result = addon.DisplayRenderResult.Create(
        context.displayText,
        context.r,
        context.g,
        context.b,
        context.extraArgs,
        message,
        debug
    )

    if addon.Profiler and addon.Profiler.Stop then
        addon.Profiler:Stop("DisplayPipeline.Render")
    end

    return result, nil
end

return Pipeline
