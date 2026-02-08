local addonName, addon = ...
addon.Utils = {}

-- Deep Copy (handles cycles)
function addon.Utils.DeepCopy(orig, copies)
    copies = copies or {}
    local orig_type = type(orig)
    local copy
    if orig_type == 'table' then
        if copies[orig] then
            copy = copies[orig]
        else
            copy = {}
            copies[orig] = copy
            for orig_key, orig_value in next, orig, nil do
                copy[addon.Utils.DeepCopy(orig_key, copies)] = addon.Utils.DeepCopy(orig_value, copies)
            end
            setmetatable(copy, addon.Utils.DeepCopy(getmetatable(orig), copies))
        end
    else
        copy = orig
    end
    return copy
end

-- Merge Tables (recursive)
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

-- Color Parsing
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

-- Normalize channel base name (strip server suffix like "World - ServerName" -> "World")
function addon.Utils.NormalizeChannelBaseName(name)
    if not name or name == "" then return name end
    return name:match("^%s*(.-)%s*%-%s*.+$") or name
end

-- Find registry item by various inputs
local function FindRegistryItem(input)
    if not input then return nil end
    local L = addon.L
    
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

    for _, stream, catKey, subKey in addon:IterateAllStreams() do
        -- 2. Try by chatType for system channels
        if chatType and chatType ~= "CHANNEL" and stream.chatType == chatType then
            return stream
        end
        
        -- 3. Try by channelId for dynamic channels (reverse lookup)
        if chatType == "CHANNEL" and channelId and subKey == "DYNAMIC" and stream.mappingKey then
            local realName = L[stream.mappingKey]
            if realName and GetChannelName(realName) == channelId then
                return stream
            end
        end
        
        -- 4. Try by channelName for dynamic channels
        if normalizedName then
            if subKey == "DYNAMIC" and stream.mappingKey then
                local realName = L[stream.mappingKey]
                if realName then
                    if realName == normalizedName or normalizedName:find(realName, 1, true) == 1 or realName:find(normalizedName, 1, true) == 1 then
                        return stream
                    end
                end
            end
            -- Also match by label
            if stream.label == normalizedName then
                return stream
            end
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
    
    local fmt = format or (addon.db and addon.db.plugin.chat and addon.db.plugin.chat.visual and addon.db.plugin.chat.visual.channelNameFormat) or "SHORT"
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
