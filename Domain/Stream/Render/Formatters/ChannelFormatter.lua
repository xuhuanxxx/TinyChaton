local addonName, addon = ...

local function FormatChannelLine(line, options, helpers)
    if type(line) ~= "table" or type(line.text) ~= "string" then
        return nil, 1, 1, 1
    end

    local streamTag = helpers.getStreamTag(line, options)
    local authorTag = helpers.getAuthorTag(line)
    local contentForCopy = string.format("%s%s%s", streamTag, authorTag, line.text)
    local r, g, b = helpers.getLineColor(line)
    local msgColor = { r = r, g = g, b = b }
    local preferConfig = options and options.preferTimestampConfig == true

    local timestamp = helpers.getTimestamp(line.time, msgColor, preferConfig)
    if timestamp ~= "" and helpers.isClickToCopyEnabledForLine(line, options) then
        local colorHex = helpers.resolveTimestampColor(msgColor, preferConfig)
        local plainText = helpers.getTimestampText(line.time)
        timestamp = addon:CreateClickableTimestamp(plainText, contentForCopy, colorHex)
    end

    local displayLine = string.format("%s%s", timestamp, contentForCopy)
    return displayLine, r, g, b
end

if addon.MessageFormatter and addon.MessageFormatter.RegisterKindFormatter then
    addon.MessageFormatter.RegisterKindFormatter("channel", FormatChannelLine)
end
