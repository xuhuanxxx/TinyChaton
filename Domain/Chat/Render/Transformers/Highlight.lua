local addonName, addon = ...

-- Display Module: ChatHighlight
-- Stage: Display Transformer
-- Description: Adds color codes to names and keywords in chat messages

local function escapePattern(s)
    if not s or type(s) ~= "string" then return "" end
    return (s:gsub("([%%%(%)%.%+%-%*%?%[%]%^%$])", "%%%1"))
end

addon.ChatHighlight = addon.ChatHighlight or {}

function addon.ChatHighlight.Process(chatData)
    if not addon.db or not addon.db.enabled then return false end

    local config = addon.db.plugin and addon.db.plugin.filter and addon.db.plugin.filter.highlight
    if not config or not config.enabled then return false end

    local body = chatData.text
    local modified = false
    local colorCode = config.color or "FF00FF00"

    -- 1. Name Highlight
    if config.names and #config.names > 0 then
        -- chatData already has pureName (without realm) and lowercase name
        local myName = chatData.name
        local myNameLower = chatData.authorLower -- Pre-computed lower name

        if myName and myName ~= "" then
            for _, name in pairs(config.names) do
                if name and name ~= "" then
                    if myNameLower == string.lower(name) then
                        body = "|c" .. colorCode .. body .. "|r"
                        modified = true
                        break
                    end
                end
            end
        end
    end

    -- 2. Keyword Highlight (if not already highlighted by name)
    if not modified and config.keywords and #config.keywords > 0 then
        for _, word in pairs(config.keywords) do
            if word and word ~= "" then
                local escaped = escapePattern(word)
                -- Frontier check for alphanumeric words
                local useFrontier = string.match(word, "^[%w_]+$")

                local newBody, count
                if useFrontier then
                    newBody, count = string.gsub(body, "(%f[%a]"..escaped.."%f[%A])", "|c"..colorCode.."%1|r")
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

    if modified then
        chatData.text = body
        return true
    end
    return false
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

function addon.ChatHighlight.ApplyToDisplayText(text)
    local prefix, body, author = ParseDisplayLine(text)
    local pureName = author and author:match("([^%-]+)") or author
    local chatData = {
        text = body,
        name = pureName,
        authorLower = pureName and string.lower(pureName) or "",
    }

    if addon.ChatHighlight.Process(chatData) then
        return prefix .. chatData.text
    end

    return text
end

local function HighlightTransformer(frame, text, ...)
    if not addon.db or not addon.db.enabled then
        return text, ...
    end
    return addon.ChatHighlight.ApplyToDisplayText(text), ...
end

function addon:InitDisplayHighlight()
    local function EnableChatHighlight()
        addon:RegisterChatFrameTransformer("display_highlight", HighlightTransformer)
    end

    local function DisableChatHighlight()
        addon.chatFrameTransformers["display_highlight"] = nil
    end

    if addon.RegisterFeature then
        addon:RegisterFeature("ChatHighlight", {
            requires = { "MUTATE_CHAT_DISPLAY" },
            onEnable = EnableChatHighlight,
            onDisable = DisableChatHighlight,
        })
    else
        EnableChatHighlight()
    end
end

addon:RegisterModule("DisplayHighlight", addon.InitDisplayHighlight)
