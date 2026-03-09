local addonName, addon = ...
local CVarAPI = _G["C_" .. "CVar"]

addon.MessageFormatter = addon.MessageFormatter or {}
local Formatter = addon.MessageFormatter

local DEFAULT_TIMESTAMP_COLOR = "FF888888"
Formatter.PREFIX_TOKEN = Formatter.PREFIX_TOKEN or "<<TC_PREFIX>>"

local function ResolveKindFromMessage(message)
    local streamKey = type(message) == "table" and message.streamKey or nil
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
        resolveKind = ResolveKindFromMessage,
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
        resolveKind = ResolveKindFromMessage,
        getFormatter = function(kind)
            return EnsureKindPlugins():GetFormatter(kind)
        end,
        fallbackRenderer = function(message)
            local r, g, b = Formatter.GetLineColor(message)
            return message.rawText, r, g, b
        end,
    })
    return addon._tinyCoreStreamRenderEngine
end

Formatter.kindFormatters = EnsureKindPlugins().formatters

local function ResolveColorChatType(message)
    if type(message) ~= "table" then
        return nil
    end
    if message.wowChatType == "CHANNEL" and message.channelId then
        return "CHANNEL" .. tostring(message.channelId)
    end
    return message.wowChatType
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
    local setting = addon.db and addon.db.profile and addon.db.profile.chat and addon.db.profile.chat.interaction and addon.db.profile.chat.interaction.timestampColor
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

function Formatter.GetLineColor(message)
    local chatTypeForColor = ResolveColorChatType(message)
    if ChatTypeInfo and chatTypeForColor and ChatTypeInfo[chatTypeForColor] then
        local info = ChatTypeInfo[chatTypeForColor]
        return info.r or 1, info.g or 1, info.b or 1
    end
    return 1, 1, 1
end

function Formatter.GetStreamTag(message)
    if type(message) ~= "table" then
        return ""
    end

    local streamKey = message.streamKey
    if type(streamKey) ~= "string" or streamKey == "" then
        return ""
    end

    if not addon.GetStreamKind or addon:GetStreamKind(streamKey) == "notice" then
        return ""
    end

    return Formatter.PREFIX_TOKEN
end

function Formatter.GetAuthorTag(message)
    if type(message) ~= "table" or not message.author or message.author == "" then
        return ""
    end

    local authorName = message.author
    if message.classFilename and RAID_CLASS_COLORS and RAID_CLASS_COLORS[message.classFilename] then
        local classColor = RAID_CLASS_COLORS[message.classFilename]
        authorName = string.format("|cff%02x%02x%02x%s|r",
            classColor.r * 255,
            classColor.g * 255,
            classColor.b * 255,
            message.author)
    end

    return string.format("|Hplayer:%s|h[%s]|h%s", message.author, authorName, addon.L["CHAT_MESSAGE_SEPARATOR"] or ":")
end

function Formatter.BuildDisplayLine(message, options)
    return EnsureRenderEngine():BuildDisplayLine(message, options, {
        getLineColor = Formatter.GetLineColor,
        getTimestamp = Formatter.GetTimestamp,
        getTimestampText = Formatter.GetTimestampText,
        resolveTimestampColor = Formatter.ResolveTimestampColor,
        getStreamTag = Formatter.GetStreamTag,
        getAuthorTag = Formatter.GetAuthorTag,
    })
end
