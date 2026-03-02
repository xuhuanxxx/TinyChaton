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
    if name == "" then return name end
    return name:match("^%s*(.-)%s*%-%s*.+$") or name
end

local function MatchChannelName(stream, normalizedName)
    if not stream or not normalizedName then return false end
    local L = addon.L

    -- 1. Match by label (highest priority?)
    if stream.label == normalizedName then return true end

    -- 2. Match by real channel name (for dynamic channels)
    if stream.mappingKey then
        local realName = L[stream.mappingKey]
        if realName then
            -- Exact match
            if realName == normalizedName then return true end
            -- Partial match (start of string)
            -- Check if normalizedName starts with realName (e.g. "General - City" starts with "General")
            if normalizedName:find(realName, 1, true) == 1 then return true end
            -- Check if realName starts with normalizedName (reverse case?)
            if realName:find(normalizedName, 1, true) == 1 then return true end
        end
    end

    return false
end

-- Channel Index (Performance Optimization)
-- Replaces O(n) iteration with O(1) lookup
addon.ChannelIndex = {}
local isChannelIndexBuilt = false
local dynamicStreamIndexByChannelId = {}
local joinedChannelNameByIdCache = {}
local joinedChannelNameByIdCacheStamp = 0
local JOINED_CHANNEL_NAME_CACHE_TTL = 1

function addon.Utils.InvalidateChannelCaches()
    addon.ChannelIndex = {}
    table.wipe(dynamicStreamIndexByChannelId)
    table.wipe(joinedChannelNameByIdCache)
    joinedChannelNameByIdCacheStamp = 0
    isChannelIndexBuilt = false
    if addon.InvalidateChannelKeyCache then
        addon:InvalidateChannelKeyCache()
    end
end

--- Build the channel reverse index
function addon.Utils.BuildChannelIndex()
    if isChannelIndexBuilt then return end
    
    addon.ChannelIndex = {}
    local index = addon.ChannelIndex
    
    -- Iterate all streams and build index
    for _, stream in addon:IterateAllStreams() do
        -- 1. Index by label
        if stream.label then
            index[stream.label] = stream
        end
        
        -- 2. Index by mapping key (for dynamic channels)
        if stream.mappingKey then
            local realName = addon.L[stream.mappingKey]
            if realName then
                index[realName] = stream
                -- Also cache normalized version if different
                local norm = addon.Utils.NormalizeChannelBaseName(realName)
                if norm ~= realName then
                    index[norm] = stream
                end
            end
        end
        
        -- 3. Index by registry key (unique ID)
        -- This might be redundant if GetStreamByKey is efficient, but good for uniformity
        -- Assuming stream has a key field or we can derive it? 
        -- The registry iteration gives us the stream object directly.
    end
    
    isChannelIndexBuilt = true
end

--- Find a channel stream by key (O(1))
--- @param key string
--- @return table|nil
function addon.Utils.FindChannelByKey(key)
    if not key then return nil end
    if not isChannelIndexBuilt then addon.Utils.BuildChannelIndex() end
    return addon.ChannelIndex[key]
end

function addon.Utils.GetJoinedChannelNameById(id)
    if not id then return nil end
    local now = GetTime and GetTime() or 0
    if (now - joinedChannelNameByIdCacheStamp) > JOINED_CHANNEL_NAME_CACHE_TTL then
        table.wipe(joinedChannelNameByIdCache)
        joinedChannelNameByIdCacheStamp = now
    end
    if joinedChannelNameByIdCache[id] ~= nil then
        return joinedChannelNameByIdCache[id] or nil
    end

    local list = { GetChannelList() }
    for i = 1, #list, 3 do
        local channelId = list[i]
        local channelName = list[i + 1]
        if channelId and channelName then
            joinedChannelNameByIdCache[channelId] = channelName
        end
    end

    if joinedChannelNameByIdCache[id] == nil then
        joinedChannelNameByIdCache[id] = false
    end
    return joinedChannelNameByIdCache[id] or nil
end

function addon.Utils.FindDynamicStreamByChannelId(channelId)
    if not channelId then return nil end
    if dynamicStreamIndexByChannelId[channelId] ~= nil then
        return dynamicStreamIndexByChannelId[channelId] or nil
    end

    local foundStream = nil
    for _, stream, _, subKey in addon:IterateAllStreams() do
        if subKey == "DYNAMIC" and stream.mappingKey then
            local realName = addon.L[stream.mappingKey]
            if realName and GetChannelName(realName) == channelId then
                foundStream = stream
                break
            end
        end
    end

    dynamicStreamIndexByChannelId[channelId] = foundStream or false
    return foundStream
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

    -- Fallback: Iterate all streams for more complex matching
    local chatType = input.chatType
    local channelId = input.channelId
    local channelName = input.channelName
    local normalizedName = channelName and addon.Utils.NormalizeChannelBaseName(channelName) or nil

    -- 2. Fast Lookup via Index for Channel Name (O(1))
    if normalizedName then
        local cached = addon.Utils.FindChannelByKey(normalizedName)
        if cached then return cached end
    end
    if chatType == "CHANNEL" and channelId then
        local dynamicStream = addon.Utils.FindDynamicStreamByChannelId(channelId)
        if dynamicStream then
            return dynamicStream
        end
    end

    for _, stream, catKey, subKey in addon:IterateAllStreams() do
        -- 3. Try by chatType for system channels
        if chatType and chatType ~= "CHANNEL" and stream.chatType == chatType then
            return stream
        end

        -- 4. Try by channelName for dynamic channels (partial matches missed by cache)
        if normalizedName and MatchChannelName(stream, normalizedName) then
             -- Add to index for future O(1) lookup
             if not isChannelIndexBuilt then addon.Utils.BuildChannelIndex() end
             addon.ChannelIndex[normalizedName] = stream
             return stream
        end
    end

    return nil
end

-- Unified channel display resolver
-- input: { chatType, channelId, channelName, registryKey }
-- format: "SHORT" (default), "FULL", "NUMBER", "NUMBER_SHORT"
-- Returns: displayText, registryItem
function addon.Utils.ResolveChannelDisplay(input, format)
    if not input then return "", nil end

    local fmt = format or (addon.db and addon.db.profile.chat and addon.db.profile.chat.visual and addon.db.profile.chat.visual.channelNameFormat) or "SHORT"
    local reg = FindRegistryItem(input)

    if reg then
        local label = addon:GetChannelLabel(reg, input.channelId, fmt)
        return "[" .. label .. "] ", reg
    end

    -- Fallback for unrecognized channels
    if input.channelName and input.channelName ~= "" then
        local normalized = addon.Utils.NormalizeChannelBaseName(input.channelName)
        if fmt == "NUMBER" and input.channelId then
            return "[" .. input.channelId .. "] ", nil
        elseif fmt == "NUMBER_SHORT" and input.channelId then
            local short = normalized:match("[%z\1-\127\194-\244][\128-\191]*") or normalized:sub(1, 3)
            return "[" .. input.channelId .. "." .. short .. "] ", nil
        elseif fmt == "SHORT" then
            local short = normalized:match("[%z\1-\127\194-\244][\128-\191]*") or normalized:sub(1, 3)
            return "[" .. short .. "] ", nil
        else
            return "[" .. normalized .. "] ", nil
        end
    end

    return "", nil
end

--- Shorten channel string based on format
--- @param str string
--- @param fmt string
--- @return string
function addon.Utils.ShortenChannelString(str, fmt)
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

    -- For dynamic channels, always try reverse lookup by channel ID first
    -- This is the most reliable method when we only have a number
    local item
    if id then
        item = addon.Utils.FindDynamicStreamByChannelId(id)
    end

    -- If reverse lookup failed and we have a name, try name matching
    if not item and name and name ~= "" then
        local normalizedName = addon.Utils.NormalizeChannelBaseName(name)
        item = addon.Utils.FindChannelByKey(normalizedName)
        if not item then
            for _, stream in addon:IterateAllStreams() do
                if MatchChannelName(stream, normalizedName) then
                    item = stream
                    addon.ChannelIndex[normalizedName] = stream
                    break
                end
            end
        end
    end

    if item then
        return addon:GetChannelLabel(item, num)
    end

    -- Fallback for unrecognized channels
    local fallbackName = (name and name ~= "") and name or (num or str)
    if fmt == "NUMBER" then
        return num or fallbackName
    elseif fmt == "SHORT" then
        if fallbackName and fallbackName ~= "" then
            return fallbackName:match("[%z\1-\127\194-\244][\128-\191]*") or fallbackName:sub(1,3)
        end
        return str
    elseif fmt == "NUMBER_SHORT" then
        local short = fallbackName:match("[%z\1-\127\194-\244][\128-\191]*") or fallbackName:sub(1,3)
        return num and (num .. "." .. short) or short
    elseif fmt == "FULL" then
        return fallbackName
    end

    return str
end
