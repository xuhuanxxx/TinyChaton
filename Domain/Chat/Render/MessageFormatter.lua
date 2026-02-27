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
    local setting = addon.db and addon.db.plugin.chat and addon.db.plugin.chat.interaction and addon.db.plugin.chat.interaction.timestampColor
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

-- =========================================================================
-- Channel Tag Formatting (Migrated from SnapshotManager)
-- =========================================================================

--- Format channel tag with color and link
--- @param line table Snapshot line data containing chatType, channelId, etc.
--- @return string Formatted channel tag string
function addon.MessageFormatter.GetChannelTag(line)
    if not line then return "" end

    local channelNameDisplay, registryItem = addon.Utils.ResolveChannelDisplay({
        chatType = line.chatType,
        channelId = line.channelId,
        channelName = line.channelBaseNameNormalized,
        registryKey = line.registryKey,
    })

    local channelTag = channelNameDisplay
    local chatTypeForColor = line.chatType
    if line.chatType == "CHANNEL" and line.channelId then
        chatTypeForColor = "CHANNEL" .. line.channelId
    end

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

-- =========================================================================
-- Author Tag Formatting (Migrated from SnapshotManager)
-- =========================================================================

--- Format author tag with class color and link
--- @param line table Snapshot line data containing author, classFilename
--- @return string Formatted author tag string
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
