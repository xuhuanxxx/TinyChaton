local addonName, addon = ...

-- =========================================================================
-- Module: ChatHighlight
-- Moved from Core/Middleware/Highlight
-- Stage: ENRICH (via EventDispatcher)
-- Priority: 40
-- Description: Adds color codes to names and keywords in chat messages
-- =========================================================================

local function escapePattern(s)
    if not s or type(s) ~= "string" then return "" end
    return (s:gsub("([%%%(%)%.%+%-%*%?%[%]%^%$])", "%%%1"))
end

local function HighlightMiddleware(chatData)
    if not addon.db or not addon.db.enabled then return end
    
    local config = addon.db.plugin and addon.db.plugin.filter and addon.db.plugin.filter.highlight
    if not config or not config.enabled then return end
    
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
    end
end

function addon:InitChatHighlight()
    -- Register as middleware in ENRICH stage
    if addon.EventDispatcher then
        addon.EventDispatcher:RegisterMiddleware("ENRICH", 40, "ChatHighlight", HighlightMiddleware)
    end
end
