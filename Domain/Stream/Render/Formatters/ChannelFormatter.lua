local addonName, addon = ...

local function FormatChannelLine(message, options, helpers)
    if type(message) ~= "table" or type(message.rawText) ~= "string" then
        return nil, 1, 1, 1
    end

    local streamTag = helpers.getStreamTag(message)
    local authorTag = helpers.getAuthorTag(message)
    local r, g, b = helpers.getLineColor(message)
    local msgColor = { r = r, g = g, b = b }
    local preferConfig = options and options.preferTimestampConfig == true

    local timestamp = helpers.getTimestamp(message.timestamp, msgColor, preferConfig)
    local displayLine = string.format("%s%s%s%s", timestamp, streamTag, authorTag, message.rawText)
    return displayLine, r, g, b
end

if addon.MessageFormatter and addon.MessageFormatter.RegisterKindFormatter then
    addon.MessageFormatter.RegisterKindFormatter("channel", FormatChannelLine)
end
