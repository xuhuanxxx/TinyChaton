local addonName, addon = ...

local function FormatNoticeLine(message, options, helpers)
    if type(message) ~= "table" or type(message.rawText) ~= "string" then
        return nil, 1, 1, 1
    end
    local r, g, b = helpers.getLineColor(message)
    return message.rawText, r, g, b
end

if addon.MessageFormatter and addon.MessageFormatter.RegisterKindFormatter then
    addon.MessageFormatter.RegisterKindFormatter("notice", FormatNoticeLine)
end
