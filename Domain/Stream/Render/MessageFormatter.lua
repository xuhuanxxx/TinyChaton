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

    return addon.DisplayAugmentPipeline and addon.DisplayAugmentPipeline.PREFIX_TOKEN or "<<TC_PREFIX>>"
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

function Formatter.BuildDisplayLine(line, options)
    return EnsureRenderEngine():BuildDisplayLine(line, options, {
        getLineColor = Formatter.GetLineColor,
        getTimestamp = Formatter.GetTimestamp,
        getTimestampText = Formatter.GetTimestampText,
        resolveTimestampColor = Formatter.ResolveTimestampColor,
        getStreamTag = Formatter.GetStreamTag,
        getAuthorTag = Formatter.GetAuthorTag,
    })
end
