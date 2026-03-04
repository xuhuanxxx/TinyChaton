local addonName, addon = ...
local CVarAPI = _G["C_" .. "CVar"]

addon.MessageFormatter = addon.MessageFormatter or {}
local Formatter = addon.MessageFormatter

local DEFAULT_TIMESTAMP_COLOR = "FF888888"
local function ResolveKindFromContext(context)
    local streamKey = type(context) == "table" and context.streamKey or nil
    if type(streamKey) ~= "string" or streamKey == "" then
        return nil
    end
    return addon.GetStreamKind and addon:GetStreamKind(streamKey) or nil
end

local function EnsureKindPlugins()
    if addon._tinyCoreStreamKindPlugins then
        return addon._tinyCoreStreamKindPlugins
    end
    if not addon.TinyCoreStreamKindPlugins or type(addon.TinyCoreStreamKindPlugins.New) ~= "function" then
        error("TinyCore Stream KindPlugins is not initialized")
    end
    addon._tinyCoreStreamKindPlugins = addon.TinyCoreStreamKindPlugins:New({
        resolveKind = ResolveKindFromContext,
    })
    return addon._tinyCoreStreamKindPlugins
end

local function EnsureRenderEngine()
    if addon._tinyCoreStreamRenderEngine then
        return addon._tinyCoreStreamRenderEngine
    end
    if not addon.TinyCoreStreamRenderEngine or type(addon.TinyCoreStreamRenderEngine.New) ~= "function" then
        error("TinyCore Stream RenderEngine is not initialized")
    end
    addon._tinyCoreStreamRenderEngine = addon.TinyCoreStreamRenderEngine:New({
        resolveKind = function(line)
            local streamKey = type(line) == "table" and line.streamKey or nil
            if (type(streamKey) ~= "string" or streamKey == "") or not addon.GetStreamKind then
                return nil
            end
            return addon:GetStreamKind(streamKey)
        end,
        getFormatter = function(kind)
            return EnsureKindPlugins():GetFormatter(kind)
        end,
        fallbackRenderer = function(line)
            local r, g, b = Formatter.GetLineColor(line)
            return line.text, r, g, b
        end,
    })
    return addon._tinyCoreStreamRenderEngine
end

local KIND_FORMATTERS = EnsureKindPlugins().formatters
Formatter.kindFormatters = KIND_FORMATTERS

local function ResolveColorChatType(line)
    if not line then
        return nil
    end
    local streamMeta = type(line.streamMeta) == "table" and line.streamMeta or nil
    if line.wowChatType == "CHANNEL" and streamMeta and streamMeta.channelId then
        return "CHANNEL" .. tostring(streamMeta.channelId)
    end
    return line.wowChatType
end

local function IsClickToCopyEnabledForLine(line)
    local interaction = addon.db and addon.db.profile and addon.db.profile.chat and addon.db.profile.chat.interaction
    if not interaction or interaction.clickToCopy == false then
        return false
    end

    local streamKey = line and line.streamKey or nil
    if type(streamKey) ~= "string" or streamKey == "" then
        return true
    end

    local copyStreams = interaction.copyStreams
    if addon.ResolveStreamToggle then
        return addon:ResolveStreamToggle(streamKey, copyStreams, "copyDefault", true)
    end
    return true
end

function Formatter.RegisterKindFormatter(kind, formatterFn)
    return EnsureKindPlugins():RegisterFormatter(kind, formatterFn)
end

function Formatter.GetTimestampText(timeVal)
    if not timeVal then return "" end

    local showTimestamp = CVarAPI.GetCVar("showTimestamps")
    if not showTimestamp or showTimestamp == "none" then return "" end

    local ts = BetterDate(TIMESTAMP_FORMAT or showTimestamp, timeVal)
    if ts:sub(-1) ~= " " then ts = ts .. " " end
    return ts
end

function Formatter.ResolveTimestampColor(msgColor, preferConfig)
    local setting = addon.db and addon.db.profile.chat and addon.db.profile.chat.interaction and addon.db.profile.chat.interaction.timestampColor
    local hasConfig = (setting and setting ~= "")

    if preferConfig and hasConfig then
        if #setting == 6 then
            return "FF" .. setting
        end
        return setting
    end

    if msgColor and msgColor.r and msgColor.g and msgColor.b then
        return addon.Utils.FormatColorHex(msgColor.r, msgColor.g, msgColor.b)
    end

    return DEFAULT_TIMESTAMP_COLOR
end

function Formatter.GetTimestamp(timeVal, msgColor, preferConfig)
    local text = Formatter.GetTimestampText(timeVal)
    if text == "" then return "" end

    local color = Formatter.ResolveTimestampColor(msgColor, preferConfig)
    return string.format("|c%s%s|r", color, text)
end

function Formatter.GetLineColor(line)
    local chatTypeForColor = ResolveColorChatType(line)
    if ChatTypeInfo and chatTypeForColor and ChatTypeInfo[chatTypeForColor] then
        local info = ChatTypeInfo[chatTypeForColor]
        return info.r or 1, info.g or 1, info.b or 1
    end
    return 1, 1, 1
end

function Formatter.GetStreamTag(line)
    if type(line) ~= "table" then
        return ""
    end

    local streamKey = line.streamKey
    if type(streamKey) ~= "string" or streamKey == "" then
        return ""
    end

    if not addon.GetStreamKind or addon:GetStreamKind(streamKey) == "notice" then
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

    local streamTag = displayText
    local chatTypeForColor = ResolveColorChatType(line)
    if ChatTypeInfo and chatTypeForColor and ChatTypeInfo[chatTypeForColor] then
        local info = ChatTypeInfo[chatTypeForColor]
        streamTag = string.format("|cff%02x%02x%02x%s|r", (info.r or 1) * 255, (info.g or 1) * 255, (info.b or 1) * 255, displayText)
    end

    local caps = addon.GetStreamCapabilities and addon:GetStreamCapabilities(streamKey) or nil
    if type(caps) == "table" and caps.outbound == true then
        return string.format("|Htinychat:send:%s|h%s|h", streamKey, streamTag)
    end

    return streamTag
end

function Formatter.GetAuthorTag(line)
    if not line.author or line.author == "" then return "" end

    local authorName = line.author
    if line.classFilename and RAID_CLASS_COLORS and RAID_CLASS_COLORS[line.classFilename] then
        local classColor = RAID_CLASS_COLORS[line.classFilename]
        authorName = string.format("|cff%02x%02x%02x%s|r", classColor.r * 255, classColor.g * 255, classColor.b * 255, line.author)
    end

    return string.format("|Hplayer:%s|h[%s]|h%s", line.author, authorName, addon.L["CHAT_MESSAGE_SEPARATOR"] or ":")
end

function Formatter.BuildRealtimeLineFromContext(streamContext)
    if type(streamContext) ~= "table" or type(streamContext.text) ~= "string" then
        return nil, "invalid_stream_context"
    end

    local args = streamContext.args
    local event = streamContext.event
    local wowChatType = streamContext.wowChatType
    if type(wowChatType) ~= "string" or wowChatType == "" then
        wowChatType = addon:GetWowChatTypeByEvent(event)
    end
    if type(wowChatType) ~= "string" then
        return nil, "unmapped_event:" .. tostring(event)
    end

    local streamKey = streamContext.streamKey
    if (type(streamKey) ~= "string" or streamKey == "") and addon.ResolveStreamKey and type(args) == "table" and addon.Utils and addon.Utils.UnpackArgs then
        streamKey = addon:ResolveStreamKey(event, addon.Utils.UnpackArgs(args))
    end

    local streamMeta = nil
    if wowChatType == "CHANNEL" then
        local resolver = addon.ChannelSemanticResolver
        local channelBaseName = (resolver and type(resolver.ResolveEventChannelName) == "function")
            and resolver.ResolveEventChannelName(streamContext.channelName, streamContext.channelString, streamContext.channelNumber)
            or streamContext.channelName
        local normalized = channelBaseName
        if normalized and addon.Utils and addon.Utils.NormalizeChannelBaseName then
            normalized = addon.Utils.NormalizeChannelBaseName(normalized)
        end
        streamMeta = {
            channelId = streamContext.channelNumber,
            channelBaseName = channelBaseName,
            channelBaseNameNormalized = normalized,
        }
    end

    local classFilename
    if type(args) == "table" then
        local guid = args[12]
        if guid then
            _, classFilename = GetPlayerInfoByGUID(guid)
        end
    end

    local kind = (type(streamKey) == "string" and addon.GetStreamKind) and addon:GetStreamKind(streamKey) or nil
    local group = (type(streamKey) == "string" and addon.GetStreamGroup) and addon:GetStreamGroup(streamKey) or nil

    return {
        text = streamContext.text,
        author = streamContext.author,
        wowChatType = wowChatType,
        streamKey = streamKey,
        kind = kind,
        group = group,
        streamMeta = streamMeta,
        time = time(),
        classFilename = classFilename,
    }, nil
end

function Formatter.BuildDisplayLine(line, options)
    return EnsureRenderEngine():BuildDisplayLine(line, options, {
        getLineColor = Formatter.GetLineColor,
        getTimestamp = Formatter.GetTimestamp,
        getTimestampText = Formatter.GetTimestampText,
        resolveTimestampColor = Formatter.ResolveTimestampColor,
        getStreamTag = Formatter.GetStreamTag,
        getAuthorTag = Formatter.GetAuthorTag,
        isClickToCopyEnabledForLine = IsClickToCopyEnabledForLine,
    })
end

function addon:RenderChatLine(line, frame, options)
    local displayLine, r, g, b = Formatter.BuildDisplayLine(line, options)
    if type(displayLine) ~= "string" then
        return nil, 1, 1, 1, addon.Utils.PackArgs(1, 1, 1)
    end

    local targetFrame = frame or ChatFrame1
    local streamKey = type(line) == "table" and line.streamKey or nil
    local extraArgs = addon.Utils.PackArgs(r, g, b)
    if type(streamKey) == "string" and streamKey ~= "" then
        extraArgs.streamKey = streamKey
    end
    if addon.Gateway and addon.Gateway.Display and addon.Gateway.Display.Transform then
        displayLine, r, g, b, extraArgs = addon.Gateway.Display:Transform(targetFrame, displayLine, r, g, b, extraArgs)
    end

    if type(extraArgs) ~= "table" then
        extraArgs = addon.Utils.PackArgs(r, g, b)
    elseif extraArgs.n == nil then
        extraArgs.n = #extraArgs
    end

    extraArgs[1], extraArgs[2], extraArgs[3] = r, g, b
    if type(streamKey) == "string" and streamKey ~= "" and (type(extraArgs.streamKey) ~= "string" or extraArgs.streamKey == "") then
        extraArgs.streamKey = streamKey
    end

    return displayLine, r, g, b, extraArgs
end

function addon:EmitRenderedChatLine(line, frame, options)
    local targetFrame = frame or ChatFrame1
    if not targetFrame or type(targetFrame.AddMessage) ~= "function" then
        return false
    end

    local displayLine, _, _, _, extraArgs = self:RenderChatLine(line, targetFrame, options)
    if type(displayLine) ~= "string" then
        return false
    end

    local addMessageFn = targetFrame._TinyChatonOrigAddMessage or targetFrame.AddMessage
    addMessageFn(targetFrame, displayLine, addon.Utils.UnpackArgs(extraArgs))
    return true
end
