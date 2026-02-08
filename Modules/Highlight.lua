local addonName, addon = ...

local function escapePattern(s)
    if not s or type(s) ~= "string" then return "" end
    return (s:gsub("([%%%(%)%.%+%-%*%?%[%]%^%$])", "%%%1"))
end

local function HighlightFunc(self, event, msg, author, ...)
    if not addon.db or not addon.db.enabled then
        return false, msg, author, ...
    end
    
    local highlightConfig = addon.db.plugin.filter.highlight
    if not highlightConfig or not highlightConfig.enabled then
        return false, msg, author, ...
    end

    local body = msg
    local modified = false
    local colorCode = highlightConfig.color or "FF00FF00"

    -- 1. Name Highlight (if author matches any name in the list)
    local namesList = highlightConfig.names
    if namesList and #namesList > 0 then
        local authorName = author and string.match(author, "([^%-]+)") -- Get name without realm
        local authorLower = authorName and string.lower(authorName)
        for _, name in pairs(namesList) do
            if name and name ~= "" then
                if authorLower and authorLower == string.lower(name) then
                    body = "|c" .. colorCode .. body .. "|r"
                    modified = true
                    break
                end
            end
        end
    end

    -- 2. Keyword Highlight (if not already highlighted by name)
    if not modified then
        local highlightList = highlightConfig.keywords
        if highlightList and #highlightList > 0 then
            for _, word in pairs(highlightList) do
                if word and word ~= "" then
                    local escaped = escapePattern(word)
                    -- For Chinese characters or mixed text, we use simple matching
                    -- Frontier pattern %f[%a] is only reliable for alphanumeric words
                    local useFrontier = string.match(word, "^[%w_]+$")
                    
                    local newBody, count
                    if useFrontier then
                        newBody, count = string.gsub(body, "(%f[%a]"..escaped.."%f[%a])", "|c"..colorCode.."%1|r")
                    end
                    
                    if not count or count == 0 then
                        newBody, count = string.gsub(body, "("..escaped..")", "|c"..colorCode.."%1|r")
                    end

                    if count > 0 then
                        body = newBody
                        modified = true
                    end
                end
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
    -- Fallback if CHAT_EVENTS is empty
    if #events == 0 and addon.STREAM_REGISTRY then
        for _, category in pairs(addon.STREAM_REGISTRY.CHANNEL or {}) do
            for _, stream in ipairs(category) do
                if stream.events then
                    for _, ev in ipairs(stream.events) do
                        table.insert(events, ev)
                    end
                end
            end
        end
    end
    
    for _, event in ipairs(events) do
        ChatFrame_AddMessageEventFilter(event, HighlightFunc)
    end
end
