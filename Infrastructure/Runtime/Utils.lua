local addonName, addon = ...
addon.Utils = {}

local type = type
local pairs = pairs
local ipairs = ipairs
local next = next
local setmetatable = setmetatable
local getmetatable = getmetatable
local tonumber = tonumber
local string = string
local math = math

--- Deep Copy (handles cycles)
--- @generic T
--- @param orig T
--- @param copies? table
--- @return T
function addon.Utils.DeepCopy(orig, copies)
    copies = copies or {}
    local origType = type(orig)
    local copy
    if origType == 'table' then
        if copies[orig] then
            copy = copies[orig]
        else
            copy = {}
            copies[orig] = copy
            for origKey, origValue in next, orig, nil do
                copy[addon.Utils.DeepCopy(origKey, copies)] = addon.Utils.DeepCopy(origValue, copies)
            end
            setmetatable(copy, addon.Utils.DeepCopy(getmetatable(orig), copies))
        end
    else
        copy = orig
    end
    return copy
end

--- Merge Tables (recursive)
--- @param dst table
--- @param src table
--- @return table
function addon.Utils.MergeTables(dst, src)
    if type(dst) ~= "table" then dst = {} end
    if type(src) ~= "table" then return dst end
    for k, v in pairs(src) do
        if type(v) == "table" then
            dst[k] = addon.Utils.MergeTables(dst[k], v)
        elseif dst[k] == nil then
            dst[k] = v
        end
    end
    return dst
end

--- Parse Color Hex
--- @param hex string
--- @return number r, number g, number b, number a
function addon.Utils.ParseColorHex(hex)
    -- Validate input: must be string with at least 6 hex chars (RGB) or 8 (ARGB)
    if not hex or type(hex) ~= "string" then return 1, 1, 1, 1 end
    -- Remove leading # if present
    hex = hex:gsub("^#", "")
    -- Validate hex format
    if not hex:match("^%x+$") then return 1, 1, 1, 1 end

    local len = #hex
    if len == 6 then
        -- RGB format (no alpha)
        local r = tonumber(hex:sub(1, 2), 16) or 255
        local g = tonumber(hex:sub(3, 4), 16) or 255
        local b = tonumber(hex:sub(5, 6), 16) or 255
        return r / 255, g / 255, b / 255, 1
    elseif len >= 8 then
        -- ARGB format
        local a = tonumber(hex:sub(1, 2), 16) or 255
        local r = tonumber(hex:sub(3, 4), 16) or 255
        local g = tonumber(hex:sub(5, 6), 16) or 255
        local b = tonumber(hex:sub(7, 8), 16) or 255
        return r / 255, g / 255, b / 255, a / 255
    end
    return 1, 1, 1, 1
end

--- Format Color to Hex
--- @param r number
--- @param g number
--- @param b number
--- @param a? number
--- @return string "AARRGGBB"
function addon.Utils.FormatColorHex(r, g, b, a)
    return string.format("%02X%02X%02X%02X",
        math.floor((a or 1) * 255),
        math.floor((r or 1) * 255),
        math.floor((g or 1) * 255),
        math.floor((b or 1) * 255))
end

-- Table Path Helpers
function addon.Utils.GetByPath(t, path)
    if not t or type(path) ~= "string" or path == "" then return nil end
    for part in path:gmatch("[^%.]+") do
        t = t and type(t) == "table" and t[part] or nil
    end
    return t
end

function addon.Utils.SetByPath(t, path, value)
    if not t or type(path) ~= "string" or path == "" then return end
    local parts = {}
    for part in path:gmatch("[^%.]+") do parts[#parts + 1] = part end
    if #parts == 0 then return end
    for i = 1, #parts - 1 do
        local key = parts[i]
        if not t[key] or type(t[key]) ~= "table" then
            t[key] = {}
        end
        t = t[key]
    end
    t[parts[#parts]] = value
end

--- Resolve {token} placeholders in a dot path with runtime context values.
--- Missing tokens are replaced with an empty string.
--- @param path string
--- @param context? table
--- @return string|nil
function addon.Utils.ResolveTemplatePath(path, context)
    if type(path) ~= "string" or path == "" then
        return nil
    end
    local ctx = type(context) == "table" and context or {}
    local resolved = path:gsub("{([%a_][%w_]*)}", function(token)
        local value = ctx[token]
        if value == nil then
            return ""
        end
        return tostring(value)
    end)
    return resolved
end

--- Validate dot path syntax used by GetByPath/SetByPath.
--- Returns false and reason when invalid.
--- @param path string
--- @return boolean, string?
function addon.Utils.ValidatePath(path)
    if type(path) ~= "string" then
        return false, "path must be string"
    end
    if path == "" then
        return false, "path cannot be empty"
    end
    if path:find("..", 1, true) then
        return false, "path contains empty segment"
    end
    if path:sub(1, 1) == "." or path:sub(-1) == "." then
        return false, "path cannot start or end with dot"
    end
    local scrubbed = path:gsub("{([%a_][%w_]*)}", "")
    if scrubbed:find("{", 1, true) or scrubbed:find("}", 1, true) then
        return false, "path contains invalid token"
    end
    return true
end

--- Resolve normalized priority value for sortable records.
--- @param item table
--- @return number
function addon.Utils.GetPriority(item)
    if type(item) ~= "table" then
        return math.huge
    end
    if type(item.priority) ~= "number" then
        return math.huge
    end
    return item.priority
end

--- Stable comparator for priority-ordered lists.
--- Ordering:
--- 1) priority ascending
--- 2) domain rank (optional)
--- 3) group rank (optional)
--- 4) key/name lexical ascending
--- @param a table
--- @param b table
--- @param opts table|nil
--- @return boolean
function addon.Utils.CompareByPriority(a, b, opts)
    opts = type(opts) == "table" and opts or {}

    local aPriority = addon.Utils.GetPriority(a)
    local bPriority = addon.Utils.GetPriority(b)
    if aPriority ~= bPriority then
        return aPriority < bPriority
    end

    local domainRanks = opts.domainRankByValue
    if type(domainRanks) == "table" then
        local domainField = opts.domainField or "domain"
        local aDomain = domainRanks[a and a[domainField] or nil] or math.huge
        local bDomain = domainRanks[b and b[domainField] or nil] or math.huge
        if aDomain ~= bDomain then
            return aDomain < bDomain
        end
    end

    local groupRanks = opts.groupRankByValue
    if type(groupRanks) == "table" then
        local groupField = opts.groupField or "group"
        local aGroup = groupRanks[a and a[groupField] or nil] or math.huge
        local bGroup = groupRanks[b and b[groupField] or nil] or math.huge
        if aGroup ~= bGroup then
            return aGroup < bGroup
        end
    end

    local keyField = opts.keyField or "key"
    local aKey = tostring(a and a[keyField] or "")
    local bKey = tostring(b and b[keyField] or "")
    if aKey ~= bKey then
        return aKey < bKey
    end
    return false
end

--- Pack varargs preserving nil holes (Lua 5.1 compatible)
--- @return table packed { n = argc, ... }
function addon.Utils.PackArgs(...)
    return { n = select("#", ...), ... }
end

--- Unpack packed varargs preserving nil holes (Lua 5.1 compatible)
--- @param packed table
--- @return ...
function addon.Utils.UnpackArgs(packed)
    if type(packed) ~= "table" then
        return
    end
    return unpack(packed, 1, packed.n or #packed)
end

--- Normalize channel base name (strip server suffix like "World - ServerName" -> "World")
--- @param name string
--- @return string
function addon.Utils.NormalizeChannelBaseName(name)
    if type(name) ~= "string" then return name end
    local resolver = addon.ChannelSemanticResolver
    local canonical = resolver and resolver.Canonicalize and resolver.Canonicalize(name) or nil
    if canonical then
        return name:match("^%s*(.-)%s*%-%s*.+$") or name
    end
    if name == "" then return name end
    return name:match("^%s*(.-)%s*%-%s*.+$") or name
end

function addon.Utils.FindChannelByKey(key)
    if type(key) ~= "string" or key == "" then return nil end

    local direct = addon.GetStreamByKey and addon:GetStreamByKey(key) or nil
    if direct then
        return direct
    end

    local resolver = addon.ChannelSemanticResolver
    if resolver and type(resolver.ResolveStreamKey) == "function" then
        local streamKey = resolver.ResolveStreamKey({
            chatType = "CHANNEL",
            channelName = key,
        })
        if streamKey and streamKey ~= "unknown_dynamic" and addon.GetStreamByKey then
            return addon:GetStreamByKey(streamKey)
        end
    end
    return nil
end

function addon.Utils.GetJoinedChannelNameById(id)
    if not id then return nil end
    local _, channelName = GetChannelName(id)
    if channelName and channelName ~= "" then
        return addon.Utils.NormalizeChannelBaseName(channelName)
    end

    local resolver = addon.ChannelSemanticResolver
    if resolver and type(resolver.GetJoinedDynamicChannels) == "function" then
        local joined = resolver.GetJoinedDynamicChannels()
        if joined and type(joined.byStreamKey) == "table" then
            for _, item in pairs(joined.byStreamKey) do
                if item and item.channelId == tonumber(id) then
                    return item.channelName
                end
            end
        end
    end
    return nil
end

function addon.Utils.FindDynamicStreamByChannelId(channelId)
    if not channelId then return nil end
    local resolver = addon.ChannelSemanticResolver
    if not resolver or type(resolver.ResolveStreamKey) ~= "function" then
        return nil
    end
    local streamKey = resolver.ResolveStreamKey({
        chatType = "CHANNEL",
        channelId = channelId,
    })
    if type(streamKey) ~= "string" or streamKey == "" or streamKey == "unknown_dynamic" then
        return nil
    end
    return addon.GetStreamByKey and addon:GetStreamByKey(streamKey) or nil
end

-- Find registry item by various inputs
local function FindRegistryItem(input)
    if not input then return nil end
    -- input can be: { chatType, channelId, channelName, registryKey }
    local registryKey = input.registryKey

    -- 1. Try by registryKey (most reliable)
    if registryKey then
        local stream = addon:GetStreamByKey(registryKey)
        if stream then return stream end
    end

    local chatType = input.chatType
    local channelId = input.channelId
    local channelName = input.channelName

    if chatType == "CHANNEL" then
        local resolver = addon.ChannelSemanticResolver
        if resolver and type(resolver.ResolveStreamKey) == "function" then
            local streamKey = resolver.ResolveStreamKey({
                chatType = "CHANNEL",
                channelId = channelId,
                channelName = channelName,
            })
            if streamKey and streamKey ~= "unknown_dynamic" then
                return addon.GetStreamByKey and addon:GetStreamByKey(streamKey) or nil
            end
        end
        return nil
    end

    for _, stream in addon:IterateAllStreams() do
        if chatType and chatType ~= "CHANNEL" and stream.chatType == chatType then
            return stream
        end
    end

    return nil
end

-- Unified channel display resolver
-- input: { chatType, channelId, channelName, registryKey }
-- Returns: displayText, registryItem
function addon.Utils.ResolveChannelDisplay(input)
    if not input then return "", nil end

    local reg = FindRegistryItem(input)

    if reg then
        local label = addon:FormatDisplayText(reg, "channel", "chat", {
            channelId = input.channelId,
            channelName = input.channelName,
            registryKey = input.registryKey,
        })
        return "[" .. label .. "] ", reg
    end

    -- Fallback for unrecognized channels
    if input.channelName and input.channelName ~= "" then
        local normalized = addon.Utils.NormalizeChannelBaseName(input.channelName)
        local text = normalized:match("[%z\1-\127\194-\244][\128-\191]*") or normalized:sub(1, 1)
        if input.channelId then
            return "[" .. tostring(input.channelId) .. "." .. text .. "] ", nil
        end
        return "[" .. text .. "] ", nil
    end

    return "", nil
end

--- Shorten channel string using current short style rules.
--- @param str string
--- @return string
function addon.Utils.ShortenChannelString(str)
    if not str or type(str) ~= "string" or str == "" then return str end

    -- Parse numeric ID and name (e.g., "1. General" -> num="1", name="General")
    -- Also handle "1." format (number with trailing dot but no name)
    local num, name = str:match("^(%d+)%.%s*(.*)")
    if not num then
        -- Try matching just "1." or just "1" (number with optional dot, no name)
        num = str:match("^(%d+)%.?$")
        if num then
            name = ""
        else
            name = str
        end
    end

    local id = tonumber(num)
    if id and (not name or name == "" or name:match("^%d+$")) then
        local _, resolvedName = GetChannelName(id)
        if not resolvedName or resolvedName == "" then
            resolvedName = addon.Utils.GetJoinedChannelNameById(id)
        end
        if resolvedName and resolvedName ~= "" then
            name = addon.Utils.NormalizeChannelBaseName(resolvedName)
            num = num or tostring(id)
        end
    end

    local item
    if id then
        item = addon.Utils.FindDynamicStreamByChannelId(id)
    end
    if not item and name and name ~= "" then
        item = addon.Utils.FindChannelByKey(addon.Utils.NormalizeChannelBaseName(name))
    end

    if item then
        return addon:FormatDisplayText(item, "channel", "chat", {
            channelId = num and tonumber(num) or nil,
            channelName = name,
        })
    end

    -- Fallback for unrecognized channels
    local fallbackName = (name and name ~= "") and name or (num or str)
    local short = fallbackName:match("[%z\1-\127\194-\244][\128-\191]*") or fallbackName
    if num then
        return tostring(num) .. "." .. short
    end
    return short

end
