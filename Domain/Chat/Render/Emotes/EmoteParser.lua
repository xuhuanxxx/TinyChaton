local addonName, addon = ...

addon.EmoteParser = addon.EmoteParser or {}
local Parser = addon.EmoteParser

local function CopyReplacement(replacement)
    return {
        token = replacement.token,
        startIndex = replacement.startIndex,
        endIndex = replacement.endIndex,
        texturePath = replacement.texturePath,
        replacementText = replacement.replacementText,
    }
end

local function BuildResult(sourceText, renderedParts, replacements)
    local result = {
        sourceText = sourceText,
        renderedText = sourceText,
        matched = false,
        replacements = {},
        matchCount = 0,
    }

    if #replacements == 0 then
        return result
    end

    local copied = {}
    for index, replacement in ipairs(replacements) do
        copied[index] = CopyReplacement(replacement)
    end

    result.renderedText = table.concat(renderedParts)
    result.matched = true
    result.replacements = copied
    result.matchCount = #copied
    return result
end

function Parser:GetCatalog()
    if addon.EmoteCatalog and type(addon.EmoteCatalog.GetCatalog) == "function" then
        return addon.EmoteCatalog:GetCatalog()
    end
    return {}
end

function Parser:Parse(text)
    if type(text) ~= "string" then
        return {
            sourceText = text,
            renderedText = text,
            matched = false,
            replacements = {},
            matchCount = 0,
        }
    end

    if text == "" then
        return BuildResult(text, { text }, {})
    end

    local tokenIndex = addon.EmoteCatalog and addon.EmoteCatalog.GetTokenIndex and addon.EmoteCatalog:GetTokenIndex() or {}
    local cursor = 1
    local renderedParts = {}
    local replacements = {}

    while cursor <= #text do
        local openPos = text:find("{", cursor, true)
        if not openPos then
            renderedParts[#renderedParts + 1] = text:sub(cursor)
            break
        end

        if openPos > cursor then
            renderedParts[#renderedParts + 1] = text:sub(cursor, openPos - 1)
        end

        local closePos = text:find("}", openPos + 1, true)
        if not closePos then
            renderedParts[#renderedParts + 1] = text:sub(openPos)
            break
        end

        local token = text:sub(openPos, closePos)
        local entry = tokenIndex[token]
        if entry then
            replacements[#replacements + 1] = {
                token = token,
                startIndex = openPos,
                endIndex = closePos,
                texturePath = entry.texturePath,
                replacementText = entry.replacementText,
            }
            renderedParts[#renderedParts + 1] = entry.replacementText
        else
            renderedParts[#renderedParts + 1] = token
        end
        cursor = closePos + 1
    end

    if #renderedParts == 0 then
        renderedParts[1] = text
    end

    return BuildResult(text, renderedParts, replacements)
end

return Parser
