local addonName, addon = ...
local L = addon.L

-- =========================================================================
-- Module: ChannelFormatter (was ContentChannel/ChannelAbbreviation)
-- Handles all channel name shortening and formatting logic
-- Decoupled from Visual.lua to prevent conflicts and recursion issues
-- =========================================================================

addon.ChannelFormatter = {}
local CF = addon.ChannelFormatter

-- -------------------------------------------------------------------------
-- Constants & Configuration
-- -------------------------------------------------------------------------

local CHAT_TYPE_TO_LKEY = {
    CHAT_GUILD_GET = "STREAM_GUILD_SHORT", CHAT_OFFICER_GET = "STREAM_OFFICER_SHORT",
    CHAT_PARTY_GET = "STREAM_PARTY_SHORT", CHAT_PARTY_LEADER_GET = "STREAM_PARTY_SHORT", CHAT_MONSTER_PARTY_GET = "STREAM_PARTY_SHORT", CHAT_PARTY_GUIDE_GET = "STREAM_INSTANCE_SHORT",
    CHAT_RAID_GET = "STREAM_RAID_SHORT", CHAT_RAID_LEADER_GET = "STREAM_RAID_SHORT", CHAT_RAID_WARNING_GET = "STREAM_RAID_SHORT",
    CHAT_INSTANCE_CHAT_GET = "STREAM_INSTANCE_SHORT", CHAT_INSTANCE_CHAT_LEADER_GET = "STREAM_INSTANCE_SHORT",
    CHAT_SAY_GET = "STREAM_SAY_SHORT", CHAT_MONSTER_SAY_GET = "STREAM_SAY_SHORT",
    CHAT_YELL_GET = "STREAM_YELL_SHORT", CHAT_MONSTER_YELL_GET = "STREAM_YELL_SHORT",
    CHAT_WHISPER_GET = "STREAM_WHISPER_SHORT", CHAT_WHISPER_INFORM_GET = "STREAM_WHISPER_SHORT", CHAT_MONSTER_WHISPER_GET = "STREAM_WHISPER_SHORT",
    CHAT_BN_WHISPER_GET = "STREAM_WHISPER_SHORT", CHAT_BN_WHISPER_INFORM_GET = "STREAM_WHISPER_SHORT",
}

-- Combat-protected events that may contain secret values
-- We must NEVER modify these global variables
local COMBAT_PROTECTED_CHAT_TYPES = {
    ["CHAT_MONSTER_YELL_GET"] = true,
    ["CHAT_MONSTER_SAY_GET"] = true,
    ["CHAT_MONSTER_WHISPER_GET"] = true,
    ["CHAT_MONSTER_PARTY_GET"] = true,
}

-- -------------------------------------------------------------------------
-- Helper Functions
-- -------------------------------------------------------------------------

local function GetJoinedChannelNameById(id)
    if not id then return nil end
    local list = { GetChannelList() }
    for i = 1, #list, 3 do
        if list[i] == id then
            return list[i + 1]
        end
    end
    return nil
end

-- Resolve channel name to short label using our registry
local function GetChannelShortLabel(name)
    if not name then return nil end

    for _, stream, catKey, subKey in addon:IterateAllStreams() do
        if stream.label == name then
            return addon:GetChannelLabel(stream, nil)
        end
        if stream.mappingKey then
            local realName = L[stream.mappingKey]
            if realName == name or (realName and (name:find(realName, 1, true) == 1 or realName:find(name, 1, true) == 1)) then
                return addon:GetChannelLabel(stream, nil)
            end
        end
    end

    return nil
end

-- -------------------------------------------------------------------------
-- Core Logic
-- -------------------------------------------------------------------------

-- 1. Modify Global Strings (e.g. CHAT_GUILD_GET)
function CF:ApplyShortChannelGlobals()
    -- Restore original values first (if previously modified)
    -- But skip protected globals to avoid crashes
    if addon.ChatTypeFormatBackup then
        for key, _ in pairs(CHAT_TYPE_TO_LKEY) do
            if not COMBAT_PROTECTED_CHAT_TYPES[key] and addon.ChatTypeFormatBackup[key] ~= nil then
                _G[key] = addon.ChatTypeFormatBackup[key]
            end
        end
    end

    local format = addon.db and addon.db.enabled and addon.db.plugin.chat and addon.db.plugin.chat.visual and addon.db.plugin.chat.visual.channelNameFormat or "SHORT"
    if not addon.db or not addon.db.enabled or format == "NONE" then
        return
    end

    addon.ChatTypeFormatBackup = addon.ChatTypeFormatBackup or {}
    for key, lkey in pairs(CHAT_TYPE_TO_LKEY) do
        if not COMBAT_PROTECTED_CHAT_TYPES[key] then
            if addon.ChatTypeFormatBackup[key] == nil and type(_G[key]) == "string" then
                addon.ChatTypeFormatBackup[key] = _G[key]
            end
            local base = addon.ChatTypeFormatBackup[key]
            local shortTag = L[lkey]
            if type(base) == "string" and base:match("%[([^%]]+)%]") then
                _G[key] = base:gsub("()%[([^%]]+)%]", function(_, _inner) return "[" .. shortTag .. "]" end, 1)
            end
        end
    end
end

-- 2. Resolve Prefixed Channel Names (e.g. "1. General")
-- Helper to sanitize result and prevent "6.6. 世"
local function SanitizeResult(p, s)
    if not s then return p end
    -- Check if s already starts with "p." or "p "
    if s:match("^" .. p .. "%.") or s:match("^" .. p .. "%s") then
        return s
    end
    return p .. "." .. s
end

function CF:ResolveShortPrefixed(communityChannel)
    local format = addon.db and addon.db.plugin.chat and addon.db.plugin.chat.visual and addon.db.plugin.chat.visual.channelNameFormat or "SHORT"

    -- Extract parts: "1. General" -> prefix="1", rest="General"
    local prefix, rest = string.match(communityChannel, "^(%d+)%.%s*(.*)")
    if not prefix then
        prefix = string.match(communityChannel, "^(%d+)%.")
        rest = ""
    end

    -- Safety check for duplication in input (e.g., "6. 6. General")
    -- This handles cases where Blizzard might have already prefixed it once
    if prefix and rest then
        local p2, r2 = string.match(rest, "^(%d+)%.%s*(.*)")
        if p2 == prefix then
            rest = r2 -- StripDuplicate prefix
        end
    end

    if format == "NUMBER" then
        if prefix then return prefix end
        return communityChannel

    elseif format == "SHORT" then
        -- Try resolving by name first
        if rest and rest ~= "" then
            local short = GetChannelShortLabel(rest)
            if short then return short end
        end

        -- Try ID-based resolution
        if prefix then
            local id = tonumber(prefix)
            if id then
                local name = GetJoinedChannelNameById(id)
                if name then
                    local normalized = addon.Utils.NormalizeChannelBaseName(name)
                    local short = GetChannelShortLabel(normalized)
                    if short then return short end
                end

                -- Reverse lookup in streams
                for _, stream, catKey, subKey in addon:IterateAllStreams() do
                    if subKey == "DYNAMIC" and stream.mappingKey then
                        local realName = L[stream.mappingKey]
                        if realName then
                            local chanId = GetChannelName(realName)
                            if chanId == id then
                                return addon:GetChannelLabel(stream, nil)
                            end
                        end
                    end
                end
            end
        end

    elseif format == "NUMBER_SHORT" then
        -- NUMBER_SHORT: "6.世"

        if prefix and rest and rest ~= "" then
            local short = GetChannelShortLabel(rest)
            if short then
                return SanitizeResult(prefix, short)
            end
        end

        if prefix then
            local id = tonumber(prefix)
            if id then
                local name = GetJoinedChannelNameById(id)
                if name then
                    local normalized = addon.Utils.NormalizeChannelBaseName(name)
                    local short = GetChannelShortLabel(normalized)
                    if short then
                        return SanitizeResult(prefix, short)
                    end
                end
            end
            -- Fallback
            return prefix
        end

    elseif format == "FULL" then
        return rest or communityChannel
    end

    -- If no format matched or no resolution found, call original if exists
    if addon.OriginalResolvePrefixed then
        return addon.OriginalResolvePrefixed(communityChannel)
    end
    return communityChannel
end

-- 3. Transformer Implementation (Visual Layer - Safe)
local function ChannelFormatterTransformer(frame, text, ...)
    if not text or type(text) ~= "string" then return text, ... end

    local format = addon.db and addon.db.enabled and addon.db.plugin.chat and addon.db.plugin.chat.visual and addon.db.plugin.chat.visual.channelNameFormat or "SHORT"
    if format == "NONE" then return text, ... end

    -- Channel links look like: |Hchannel:CHANNEL_ID|h[CHANNEL_NAME]|h
    -- We want to replace CHANNEL_NAME with its abbreviation

    -- Pattern explain:
    -- (|Hchannel:[^|]+|h)%[([^%]]+)%]
    -- Group 1: Prefix up to the name bracket e.g. "|Hchannel:20|h"
    -- Group 2: The content inside brackets e.g. "1. General"

    local newText = text:gsub("(|Hchannel:[^|]+|h)%[([^%]]+)%]", function(prefix, channelName)
        -- CF:ResolveShortPrefixed handles all logic:
        -- 1. Splits "1. Gen"
        -- 2. Checks config (SHORT/NUMBER/FULL/etc)
        -- 3. Resolves short name
        local abbr = CF:ResolveShortPrefixed(channelName)
        return prefix .. "[" .. abbr .. "]"
    end)

    return newText, ...
end

-- Initialize
function CF:Init()
    -- Apply global strings modification (e.g. CHAT_GUILD_GET = "[G]")
    -- This is generally safe as it just changes string constants
    CF:ApplyShortChannelGlobals()

    -- Register as a ChatFrame Transformer (Visual Layer)
    addon:RegisterChatFrameTransformer("channel_formatter", ChannelFormatterTransformer)

    -- Transformer order is now centralized in Core.lua
end

function addon:InitChannelFormatter()
    CF:Init()
end

-- P0: Register Module
addon:RegisterModule("ChannelFormatter", addon.InitChannelFormatter)
