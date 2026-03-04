local addonName, addon = ...

local function escapePattern(s)
    if not s or type(s) ~= "string" then return "" end
    return (s:gsub("([%%%(%)%.%+%-%*%?%[%]%^%$])", "%%%1"))
end

local function ParseDisplayLine(text)
    if type(text) ~= "string" or text == "" then
        return "", text, nil
    end

    local startPos, endPos, author = text:find("|Hplayer:([^|]+)|h%[[^%]]+%]|h")
    if not startPos then
        return "", text, nil
    end

    local separator = addon.L["CHAT_MESSAGE_SEPARATOR"] or ":"
    local bodyStart = endPos + 1
    if text:sub(bodyStart, bodyStart + #separator - 1) == separator then
        bodyStart = bodyStart + #separator
    end
    if text:sub(bodyStart, bodyStart) == " " then
        bodyStart = bodyStart + 1
    end

    return text:sub(1, bodyStart - 1), text:sub(bodyStart), author
end

local function ProcessChannelContext(context)
    if not addon.db or not addon.db.enabled then
        return context
    end

    local config = addon.db.profile and addon.db.profile.filter and addon.db.profile.filter.highlight
    if not config or not config.enabled then
        return context
    end

    local text = context and context.text
    if type(text) ~= "string" then
        return context
    end

    local prefix, body, author = ParseDisplayLine(text)
    local pureName = author and author:match("([^%-]+)") or author
    local authorLower = pureName and string.lower(pureName) or ""
    local modified = false
    local colorCode = config.color or "FF00FF00"

    if config.names and #config.names > 0 and pureName and pureName ~= "" then
        for _, name in pairs(config.names) do
            if name and name ~= "" and authorLower == string.lower(name) then
                body = "|c" .. colorCode .. body .. "|r"
                modified = true
                break
            end
        end
    end

    if not modified and config.keywords and #config.keywords > 0 then
        for _, word in pairs(config.keywords) do
            if word and word ~= "" then
                local escaped = escapePattern(word)
                local useFrontier = string.match(word, "^[%w_]+$")

                local newBody, count
                if useFrontier then
                    newBody, count = string.gsub(body, "(%f[%a]" .. escaped .. "%f[%A])", "|c" .. colorCode .. "%1|r")
                end
                if not count or count == 0 then
                    newBody, count = string.gsub(body, "(" .. escaped .. ")", "|c" .. colorCode .. "%1|r")
                end
                if count and count > 0 then
                    body = newBody
                    modified = true
                end
            end
        end
    end

    if modified then
        context.text = prefix .. body
    end

    return context
end

if addon.StreamHighlighter and addon.StreamHighlighter.RegisterKindHighlighter then
    addon.StreamHighlighter:RegisterKindHighlighter("channel", ProcessChannelContext)
end
