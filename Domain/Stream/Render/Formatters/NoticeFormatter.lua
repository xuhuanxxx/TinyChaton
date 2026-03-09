local addonName, addon = ...

local function FormatNoticeLine(message, options, helpers)
    local rawText = type(message) == "table" and (message.rawText or message.text) or nil
    if type(message) ~= "table" or type(rawText) ~= "string" then
        return nil, 1, 1, 1
    end
    local r, g, b = helpers.getLineColor(message)
    return rawText, r, g, b
end

if addon.MessageFormatter and addon.MessageFormatter.RegisterKindFormatter then
    addon.MessageFormatter.RegisterKindFormatter("notice", FormatNoticeLine)
end
