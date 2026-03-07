local addonName, addon = ...

local function FormatChannelLine(line, options, helpers)
    if type(line) ~= "table" or type(line.text) ~= "string" then
        return nil, 1, 1, 1
    end

    local streamTag = helpers.getStreamTag(line)
    local authorTag = helpers.getAuthorTag(line)
    local r, g, b = helpers.getLineColor(line)
    local msgColor = { r = r, g = g, b = b }
    local preferConfig = options and options.preferTimestampConfig == true

    local timestamp = helpers.getTimestamp(line.time, msgColor, preferConfig)
    local displayLine = string.format("%s%s%s%s", timestamp, streamTag, authorTag, line.text)
    return displayLine, r, g, b
end

if addon.MessageFormatter and addon.MessageFormatter.RegisterKindFormatter then
    addon.MessageFormatter.RegisterKindFormatter("channel", FormatChannelLine)
end
