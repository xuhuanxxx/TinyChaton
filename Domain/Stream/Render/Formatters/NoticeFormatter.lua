local addonName, addon = ...

local function FormatNoticeLine(line, options, helpers)
    if type(line) ~= "table" or type(line.text) ~= "string" then
        return nil, 1, 1, 1
    end
    local r, g, b = helpers.getLineColor(line)
    return line.text, r, g, b
end

if addon.MessageFormatter and addon.MessageFormatter.RegisterKindFormatter then
    addon.MessageFormatter.RegisterKindFormatter("notice", FormatNoticeLine)
end
