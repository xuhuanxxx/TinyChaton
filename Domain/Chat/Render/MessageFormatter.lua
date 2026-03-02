local addonName, addon = ...
local CVarAPI = _G["C_" .. "CVar"]

-- =========================================================================
-- MessageFormatter
-- Component: Domain/Chat/Render/MessageFormatter.lua
-- Description: Stateless formatter for message components (Timestamp, Channel, Author)
--              Serves as the Single Source of Truth for rendering logic.
-- =========================================================================

addon.MessageFormatter = {}

-- Constants
local DEFAULT_TIMESTAMP_COLOR = "FF888888"

-- =========================================================================
-- Timestamp Formatting
-- =========================================================================

--- Get plain text timestamp (e.g., "[12:30] ")
--- @param timeVal number Unix timestamp
--- @return string Timestamp string (with trailing space) or empty string
function addon.MessageFormatter.GetTimestampText(timeVal)
    if not timeVal then return "" end
    
    local showTimestamp = CVarAPI.GetCVar("showTimestamps")
    if not showTimestamp or showTimestamp == "none" then return "" end

    local ts = BetterDate(TIMESTAMP_FORMAT or showTimestamp, timeVal)
    -- Ensure trailing space for separation
    if ts:sub(-1) ~= " " then ts = ts .. " " end
    
    return ts
end

--- Resolve timestamp color based on context
--- @param msgColor table|nil {r, g, b} from original message (optional)
--- @param preferConfig boolean|nil If true, prioritize configured color over msgColor (for Snapshot)
--- @return string Hex color string
function addon.MessageFormatter.ResolveTimestampColor(msgColor, preferConfig)
    local setting = addon.db and addon.db.profile.chat and addon.db.profile.chat.interaction and addon.db.profile.chat.interaction.timestampColor
    local hasConfig = (setting and setting ~= "")

    -- Rule 1: Configured Override (Backlog/Snapshot prioritization)
    if preferConfig and hasConfig then
        -- Normalize to ARGB (8 digits) if user manually input RGB (6 digits)
        if #setting == 6 then
            return "FF" .. setting
        end
        return setting
    end

    -- Rule 2: Real-time/Dynamic Color (or Snapshot fallback)
    -- If msgColor is provided (R, G, B), we use it to match the message.
    if msgColor and msgColor.r and msgColor.g and msgColor.b then
        return addon.Utils.FormatColorHex(msgColor.r, msgColor.g, msgColor.b)
    end
    
    -- Rule 3: Fallback (Default Gray)
    return DEFAULT_TIMESTAMP_COLOR
end

--- Get fully formatted timestamp string
--- @param timeVal number Unix timestamp
--- @param msgColor table|nil {r, g, b} Optional message color
--- @param preferConfig boolean|nil If true, prioritize configured color
--- @return string Formatted timestamp string with color code
function addon.MessageFormatter.GetTimestamp(timeVal, msgColor, preferConfig)
    local text = addon.MessageFormatter.GetTimestampText(timeVal)
    if text == "" then return "" end

    local color = addon.MessageFormatter.ResolveTimestampColor(msgColor, preferConfig)
    return string.format("|c%s%s|r", color, text)
end

local function ResolveColorChatType(line)
    if not line then
        return nil
    end
    if line.chatType == "CHANNEL" and line.channelId then
        return "CHANNEL" .. tostring(line.channelId)
    end
    return line.chatType
end

--- Resolve display color for a line.
--- @param line table
--- @return number, number, number
function addon.MessageFormatter.GetLineColor(line)
    local chatTypeForColor = ResolveColorChatType(line)
    if ChatTypeInfo and chatTypeForColor and ChatTypeInfo[chatTypeForColor] then
        local info = ChatTypeInfo[chatTypeForColor]
        return info.r or 1, info.g or 1, info.b or 1
    end
    return 1, 1, 1
end

-- Channel Tag Formatting

--- Format channel tag with color and link
--- @param line table
--- @return string
function addon.MessageFormatter.GetChannelTag(line)
    if not line then return "" end

    local normalizedName = line.channelBaseNameNormalized
    if (not normalizedName or normalizedName == "") and line.channelBaseName and addon.Utils and addon.Utils.NormalizeChannelBaseName then
        normalizedName = addon.Utils.NormalizeChannelBaseName(line.channelBaseName)
    end

    local channelNameDisplay = addon.Utils.ResolveChannelDisplay({
        chatType = line.chatType,
        channelId = line.channelId,
        channelName = normalizedName,
        registryKey = line.registryKey or line.channelKey,
    })

    local channelTag = channelNameDisplay
    local chatTypeForColor = ResolveColorChatType(line)

    if ChatTypeInfo and ChatTypeInfo[chatTypeForColor] then
        local info = ChatTypeInfo[chatTypeForColor]
        local r, g, b = info.r or 1, info.g or 1, info.b or 1
        channelTag = string.format("|cff%02x%02x%02x%s|r", r * 255, g * 255, b * 255, channelNameDisplay)
    end

    local linkType = "channel"
    local linkArg = line.channelId or line.chatType
    
    if line.chatType == "CHANNEL" then
        linkArg = line.channelId
    elseif line.chatType == "INSTANCE_CHAT" then
        linkArg = "INSTANCE"
    end
    
    return string.format("|Hchannel:%s|h%s|h", linkArg, channelTag)
end

-- Author Tag Formatting

--- Format author tag with class color and link
--- @param line table
--- @return string
function addon.MessageFormatter.GetAuthorTag(line)
    if not line.author or line.author == "" then return "" end
    
    local authorName = line.author
    if line.classFilename and RAID_CLASS_COLORS and RAID_CLASS_COLORS[line.classFilename] then
        local classColor = RAID_CLASS_COLORS[line.classFilename]
        authorName = string.format("|cff%02x%02x%02x%s|r",
            classColor.r * 255, classColor.g * 255, classColor.b * 255, line.author)
    end
    
    return string.format("|Hplayer:%s|h[%s]|h%s", line.author, authorName, addon.L["CHAT_MESSAGE_SEPARATOR"] or ":")
end

--- Build a normalized line model from realtime ChatData.
--- @param chatData table
--- @return table|nil
function addon.MessageFormatter.BuildRealtimeLineFromChatData(chatData)
    if type(chatData) ~= "table" or type(chatData.text) ~= "string" then
        return nil, "invalid_chat_data"
    end

    local args = chatData.args
    local event = chatData.event
    local chatType = addon.GetChatTypeByEvent and addon:GetChatTypeByEvent(event) or nil
    if event == "CHAT_MSG_CHANNEL" then
        chatType = "CHANNEL"
    end
    if type(chatType) ~= "string" then
        return nil, "unmapped_event:" .. tostring(event)
    end

    local channelBaseName = (chatType == "CHANNEL") and chatData.channelName or nil
    local channelBaseNameNormalized = channelBaseName
    if channelBaseNameNormalized and addon.Utils and addon.Utils.NormalizeChannelBaseName then
        channelBaseNameNormalized = addon.Utils.NormalizeChannelBaseName(channelBaseNameNormalized)
    end

    local registryKey
    if addon.GetChannelKey and type(args) == "table" and addon.Utils and addon.Utils.UnpackArgs then
        registryKey = addon:GetChannelKey(event, addon.Utils.UnpackArgs(args))
    end

    local classFilename
    if type(args) == "table" then
        local guid = args[12]
        if guid then
            _, classFilename = GetPlayerInfoByGUID(guid)
        end
    end

    return {
        text = chatData.text,
        author = chatData.author,
        chatType = chatType,
        channelId = (chatType == "CHANNEL") and chatData.channelNumber or nil,
        channelBaseName = channelBaseName,
        channelBaseNameNormalized = channelBaseNameNormalized,
        registryKey = registryKey,
        time = time(),
        classFilename = classFilename,
    }, nil
end

--- Build the rendered message text for a line.
--- @param line table
--- @param options table|nil
--- @return string|nil, number, number, number
function addon.MessageFormatter.BuildDisplayLine(line, options)
    if type(line) ~= "table" or type(line.text) ~= "string" then
        return nil, 1, 1, 1
    end

    local channelTag = addon.MessageFormatter.GetChannelTag(line)
    local authorTag = addon.MessageFormatter.GetAuthorTag(line)
    local contentForCopy = string.format("%s%s%s", channelTag, authorTag, line.text)
    local r, g, b = addon.MessageFormatter.GetLineColor(line)
    local msgColor = { r = r, g = g, b = b }
    local preferConfig = options and options.preferTimestampConfig == true

    local timestamp = addon.MessageFormatter.GetTimestamp(line.time, msgColor, preferConfig)
    if timestamp ~= ""
        and addon.db
        and addon.db.profile
        and addon.db.profile.chat
        and addon.db.profile.chat.interaction
        and addon.db.profile.chat.interaction.clickToCopy ~= false then
        local colorHex = addon.MessageFormatter.ResolveTimestampColor(msgColor, preferConfig)
        local plainText = addon.MessageFormatter.GetTimestampText(line.time)
        timestamp = addon:CreateClickableTimestamp(plainText, contentForCopy, colorHex)
    end

    local displayLine = string.format("%s%s", timestamp, contentForCopy)
    return displayLine, r, g, b
end

--- Unified rendering pipeline for chat line display.
--- @param line table
--- @param frame table|nil
--- @param options table|nil
--- @return string|nil, number, number, number, table
function addon:RenderChatLine(line, frame, options)
    local displayLine, r, g, b = addon.MessageFormatter.BuildDisplayLine(line, options)
    if type(displayLine) ~= "string" then
        return nil, 1, 1, 1, addon.Utils.PackArgs(1, 1, 1)
    end

    local targetFrame = frame or ChatFrame1
    local extraArgs = addon.Utils.PackArgs(r, g, b)
    if addon.Gateway and addon.Gateway.Display and addon.Gateway.Display.Transform then
        displayLine, r, g, b, extraArgs = addon.Gateway.Display:Transform(targetFrame, displayLine, r, g, b, extraArgs)
    end

    if type(extraArgs) ~= "table" then
        extraArgs = addon.Utils.PackArgs(r, g, b)
    elseif extraArgs.n == nil then
        extraArgs.n = #extraArgs
    end
    extraArgs[1], extraArgs[2], extraArgs[3] = r, g, b

    return displayLine, r, g, b, extraArgs
end

--- Render and emit a chat line to a frame.
--- @param line table
--- @param frame table|nil
--- @param options table|nil
--- @return boolean
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
