local addonName, addon = ...

local function escapePattern(s)
    if not s or type(s) ~= "string" then return "" end
    return (s:gsub("([%%%(%)%.%+%-%*%?%[%]%^%$])", "%%%1"))
end

local function HighlightFunc(self, event, msg, author, ...)
    if not addon.db or not addon.db.enabled or not addon.db.plugin.filter.enabled then
        return false, msg, author, ...
    end
    
    local highlightConfig = addon.db.plugin.filter.highlight
    if not highlightConfig or not highlightConfig.enabled then
        return false, msg, author, ...
    end

    local body = msg
    local modified = false

    local highlightList = highlightConfig.keywords
    if not highlightList or #highlightList == 0 then
        return false, msg, author, ...
    end

    local colorCode = highlightConfig.color or "FF00FF00"
    for _, word in pairs(highlightList) do
        if word and word ~= "" then
            local escaped = escapePattern(word)
            local newBody, count = string.gsub(body, "(%f[%a]"..escaped.."%f[%a])", "|c"..colorCode.."%1|r")
            if count == 0 then
                newBody, count = string.gsub(body, "("..escaped..")", "|c"..colorCode.."%1|r")
            end

            if count > 0 then
                body = newBody
                modified = true
            end
        end
    end

    if modified then
        return false, body, author, ...
    else
        return false, msg, author, ...
    end
end

function addon:InitHighlight()
    local events = addon.CHAT_EVENTS or {}
    for _, event in ipairs(events) do
        ChatFrame_AddMessageEventFilter(event, HighlightFunc)
    end
end
