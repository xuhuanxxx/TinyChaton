local addonName, addon = ...

addon.DisplayAugmentPipeline = addon.DisplayAugmentPipeline or {}
local Pipeline = addon.DisplayAugmentPipeline

Pipeline.stageRegistry = Pipeline.stageRegistry or {}
Pipeline.stageOrdered = Pipeline.stageOrdered or {}
Pipeline.defaultsRegistered = Pipeline.defaultsRegistered or false

local PREFIX_TOKEN = "<<TC_PREFIX>>"
Pipeline.PREFIX_TOKEN = PREFIX_TOKEN

local function EscapePattern(s)
    return (tostring(s):gsub("([%%%(%)%.%+%-%*%?%[%]%^%$])", "%%%1"))
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

local function ResolvePrefixDisplay(context)
    local line = context.line
    if type(line) ~= "table" then
        return ""
    end

    local streamKey = line.streamKey
    if type(streamKey) ~= "string" or streamKey == "" then
        return ""
    end

    local streamMeta = type(line.streamMeta) == "table" and line.streamMeta or nil
    local normalizedName = streamMeta and streamMeta.channelBaseNameNormalized or nil
    if (not normalizedName or normalizedName == "") and streamMeta and streamMeta.channelBaseName and addon.Utils and addon.Utils.NormalizeChannelBaseName then
        normalizedName = addon.Utils.NormalizeChannelBaseName(streamMeta.channelBaseName)
    end

    local displayText = addon.Utils.ResolveChannelDisplay({
        wowChatType = line.wowChatType,
        streamMeta = {
            channelId = streamMeta and streamMeta.channelId or nil,
            channelBaseName = normalizedName,
        },
        streamKey = streamKey,
    })

    local policy = addon.DisplayPolicyService
    local envelope = context.envelope
    if policy and type(policy.ResolveChannelPrefix) == "function" and type(envelope) == "table" then
        local hint = policy:ResolveChannelPrefix(envelope.streamKey, envelope.channelMeta)
        if type(hint) == "string" and hint ~= "" then
            displayText = "[" .. hint .. "] "
        end
    end

    local chatTypeForColor = line.wowChatType
    if line.wowChatType == "CHANNEL" and streamMeta and streamMeta.channelId then
        chatTypeForColor = "CHANNEL" .. tostring(streamMeta.channelId)
    end
    if ChatTypeInfo and chatTypeForColor and ChatTypeInfo[chatTypeForColor] then
        local info = ChatTypeInfo[chatTypeForColor]
        displayText = string.format("|cff%02x%02x%02x%s|r", (info.r or 1) * 255, (info.g or 1) * 255, (info.b or 1) * 255, displayText)
    end

    return displayText
end

local function EnsureDefaultStages(self)
    if self.defaultsRegistered then
        return
    end

    self:RegisterStage("patch_prefix", 10, "post_render", function(_, context)
        if type(context.displayText) ~= "string" or context.displayText == "" then
            return
        end

        local token = PREFIX_TOKEN
        if not context.displayText:find(token, 1, true) then
            return
        end

        local prefix = ResolvePrefixDisplay(context)
        if prefix == "" then
            context.displayText = context.displayText:gsub(EscapePattern(token), "", 1)
            return
        end

        if context.renderOptions.sendEnabled == true then
            local streamKey = context.envelope and context.envelope.streamKey or nil
            prefix = string.format("|Htinychat:send:%s|h%s|h", tostring(streamKey), prefix)
        end

        context.displayText = context.displayText:gsub(EscapePattern(token), prefix, 1)
        context.renderOptions.prefixPatched = true
        context.renderOptions.sendInjected = context.renderOptions.sendEnabled == true
    end)

    self:RegisterStage("inject_send_link", 20, "pre_render", function(_, context)
        local policy = addon.DisplayPolicyService
        local streamKey = context.envelope and context.envelope.streamKey or nil
        context.renderOptions.sendEnabled = policy and policy.CanInjectSend and policy:CanInjectSend(streamKey) or false
    end)

    self:RegisterStage("inject_copy_timestamp", 30, "post_render", function(_, context)
        if type(context.displayText) ~= "string" or context.displayText == "" then
            return
        end
        if context.displayText:find("|Htinychat:copy:", 1, true) then
            return
        end

        local policy = addon.DisplayPolicyService
        local streamKey = context.envelope and context.envelope.streamKey or nil
        local copyEnabled = policy and policy.CanInjectCopy and policy:CanInjectCopy(streamKey) or false
        if not copyEnabled then
            return
        end

        local startPos, finish, ts = context.displayText:find("^(|c%x%x%x%x%x%x%x%x.-|r%s)")
        if not startPos or type(ts) ~= "string" then
            return
        end

        local plainTs = ts:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
        if plainTs == "" then
            return
        end

        local rest = context.displayText:sub(finish + 1)
        local colorHex = addon.MessageFormatter.ResolveTimestampColor({ r = context.r, g = context.g, b = context.b },
            context.renderOptions.preferTimestampConfig == true)
        local linkified = addon:CreateClickableTimestamp(plainTs, plainTs .. rest, colorHex)
        context.displayText = linkified .. rest
        context.renderOptions.copyInjected = true
    end)

    self:RegisterStage("apply_highlight", 40, "post_render", function(_, context)
        if type(context.displayText) ~= "string" or context.displayText == "" then
            return
        end
        if not addon.StreamHighlighter or type(addon.StreamHighlighter.ApplyDisplayText) ~= "function" then
            return
        end
        local nextText = addon.StreamHighlighter:ApplyDisplayText(context.displayText,
            context.envelope and context.envelope.streamKey or nil)
        if type(nextText) == "string" and nextText ~= context.displayText then
            context.displayText = nextText
            context.renderOptions.highlightApplied = true
        end
    end)

    self:RegisterStage("apply_legacy_clean", 50, "post_render", function(_, context)
        if addon.CleanMessage and type(addon.CleanMessage.Process) == "function" then
            local nextText, nr, ng, nb, ne = addon.CleanMessage.Process(
                context.frame,
                context.displayText,
                context.r,
                context.g,
                context.b,
                context.extraArgs
            )
            context.displayText, context.r, context.g, context.b, context.extraArgs = nextText, nr, ng, nb, ne
        end
        if addon.StripPrefix and type(addon.StripPrefix.Apply) == "function" then
            context.displayText = addon.StripPrefix.Apply(context.displayText)
        end
    end)

    self.defaultsRegistered = true
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

function Pipeline:GetStageNames()
    EnsureDefaultStages(self)
    local out = {}
    for _, stage in ipairs(self.stageOrdered) do
        out[#out + 1] = stage.name
    end
    return out
end

function Pipeline:ExecutePhase(phase, context)
    EnsureDefaultStages(self)

    if addon.ValidateContract then
        addon:ValidateContract("DisplayAugmentContext", context)
    end

    for _, stage in ipairs(self.stageOrdered) do
        if stage.phase == phase and type(stage.fn) == "function" then
            local ok, err = pcall(stage.fn, self, context)
            if not ok and addon.Warn then
                addon:Warn("DisplayAugment stage %s failed: %s", tostring(stage.name), tostring(err))
            end
        end
    end

    if addon.ValidateContract then
        addon:ValidateContract("DisplayAugmentContext", context)
    end
end

return Pipeline
