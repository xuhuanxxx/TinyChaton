local addonName, addon = ...
local L = addon.L

addon.FONT_PATHS = {
    Default = nil,
}

local function ApplyChatFontSettings()
    if not addon.db then return end
    
    -- Use registry value for managed toggle
    if not addon:GetSettingValue("fontManaged") then return end
    
    local font = addon.db.plugin.chat.font.font
    local size = addon:GetSettingValue("fontSize")
    local outline = addon:GetSettingValue("fontOutline")
    
    if font == "Default" then font = nil end
    if font and addon.FONT_PATHS[font] then font = addon.FONT_PATHS[font] end
    
    -- We should only apply if there's something to apply
    if not font and not size and not outline then return end

    for i = 1, NUM_CHAT_WINDOWS do
        local cf = _G["ChatFrame"..i]
        if cf then
            local currentFont, currentSize, currentOutline = cf:GetFont()
            local newFont = font or currentFont
            local newSize = size or currentSize
            local newOutline = (outline == "NONE") and "" or (outline or currentOutline)
            if newFont ~= currentFont or newSize ~= currentSize or newOutline ~= currentOutline then
                cf:SetFont(newFont, newSize, newOutline)
            end
        end
    end
end
addon.ApplyChatFontSettings = ApplyChatFontSettings

local function UpdateSticky()
    if not addon.db or not addon.db.plugin.chat or not addon.db.plugin.chat.interaction then return end
    local enabled = addon.db.plugin.chat.interaction.sticky
    local types = { "SAY", "YELL", "EMOTE", "PARTY", "RAID", "GUILD", "OFFICER", "CHANNEL" }
    for _, t in ipairs(types) do
        if ChatTypeInfo[t] then
            ChatTypeInfo[t].sticky = enabled and 1 or 0
        end
    end
end

local stickyEditBoxHooked
local function HookEditBoxForSticky()
    if stickyEditBoxHooked then return end
    stickyEditBoxHooked = true
    local function hookEditBox(editBox)
        if not editBox or editBox._TinyChatonStickyHooked then return end
        editBox._TinyChatonStickyHooked = true
        editBox:HookScript("OnShow", function()
            if addon.db and addon.db.plugin.chat and addon.db.plugin.chat.interaction and addon.db.plugin.chat.interaction.sticky then
                UpdateSticky()
            end
        end)
    end
    if ChatFrame1EditBox then hookEditBox(ChatFrame1EditBox) end
    for i = 1, NUM_CHAT_WINDOWS do
        local cf = _G["ChatFrame"..i]
        if cf and cf.editBox then hookEditBox(cf.editBox) end
        local eb = _G["ChatFrame"..i.."EditBox"]
        if eb then hookEditBox(eb) end
    end
end

local function ApplyChatVisualSettings()
    UpdateSticky()
    if addon.ApplyChannelNameHooks then
        addon:ApplyChannelNameHooks()
    end
end
addon.ApplyChatVisualSettings = ApplyChatVisualSettings

-- Use addon.Utils.NormalizeChannelBaseName for normalization

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

local CHAT_TYPE_TO_LKEY = {
    CHAT_GUILD_GET = "CHANNEL_GUILD_SHORT", CHAT_OFFICER_GET = "CHANNEL_OFFICER_SHORT",
    CHAT_PARTY_GET = "CHANNEL_PARTY_SHORT", CHAT_PARTY_LEADER_GET = "CHANNEL_PARTY_SHORT", CHAT_MONSTER_PARTY_GET = "CHANNEL_PARTY_SHORT", CHAT_PARTY_GUIDE_GET = "CHANNEL_INSTANCE_SHORT",
    CHAT_RAID_GET = "CHANNEL_RAID_SHORT", CHAT_RAID_LEADER_GET = "CHANNEL_RAID_SHORT", CHAT_RAID_WARNING_GET = "CHANNEL_RAID_SHORT",
    CHAT_INSTANCE_CHAT_GET = "CHANNEL_INSTANCE_SHORT", CHAT_INSTANCE_CHAT_LEADER_GET = "CHANNEL_INSTANCE_SHORT",
    CHAT_SAY_GET = "CHANNEL_SAY_SHORT", CHAT_MONSTER_SAY_GET = "CHANNEL_SAY_SHORT",
    CHAT_YELL_GET = "CHANNEL_YELL_SHORT", CHAT_MONSTER_YELL_GET = "CHANNEL_YELL_SHORT",
    CHAT_WHISPER_GET = "CHANNEL_WHISPER_SHORT", CHAT_WHISPER_INFORM_GET = "CHANNEL_WHISPER_SHORT", CHAT_MONSTER_WHISPER_GET = "CHANNEL_WHISPER_SHORT",
    CHAT_BN_WHISPER_GET = "CHANNEL_WHISPER_SHORT", CHAT_BN_WHISPER_INFORM_GET = "CHANNEL_WHISPER_SHORT",
}

local function ApplyShortChannelGlobals()
    local format = addon.db and addon.db.enabled and addon.db.plugin.chat and addon.db.plugin.chat.visual and addon.db.plugin.chat.visual.channelNameFormat or "SHORT"
    if not addon.db or not addon.db.enabled or format == "NONE" then
        if addon.ChatTypeFormatBackup then
            for key, _ in pairs(CHAT_TYPE_TO_LKEY) do
                if addon.ChatTypeFormatBackup[key] ~= nil then
                    _G[key] = addon.ChatTypeFormatBackup[key]
                end
            end
        end
        return
    end
    addon.ChatTypeFormatBackup = addon.ChatTypeFormatBackup or {}
    for key, lkey in pairs(CHAT_TYPE_TO_LKEY) do
        if addon.ChatTypeFormatBackup[key] == nil and type(_G[key]) == "string" then
            addon.ChatTypeFormatBackup[key] = _G[key]
        end
        local base = addon.ChatTypeFormatBackup[key]
        local shortTag = L[lkey] or "G"
        if type(base) == "string" and base:match("%[([^%]]+)%]") then
            _G[key] = base:gsub("()%[([^%]]+)%]", function(_, _inner) return "[" .. shortTag .. "]" end, 1)
        end
    end
end

local function ShortenChannelString(str, fmt)
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
            resolvedName = GetJoinedChannelNameById(id)
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
        for _, reg in ipairs(addon.CHANNEL_REGISTRY or {}) do
            if reg.mappingKey and reg.isDynamic then
                local realName = L[reg.mappingKey]
                if realName then
                    local chanId = GetChannelName(realName)
                    if chanId == id then
                        item = reg
                        break
                    end
                end
            end
        end
    end

    -- If reverse lookup failed and we have a name, try name matching
    if not item and name and name ~= "" then
        local normalizedName = addon.Utils.NormalizeChannelBaseName(name)
        for _, reg in ipairs(addon.CHANNEL_REGISTRY or {}) do
            -- Match by label
            if reg.label == normalizedName then
                item = reg
                break
            end
            -- Match by real channel name (for dynamic channels)
            if reg.mappingKey then
                local realName = L[reg.mappingKey]
                if realName == normalizedName then
                    item = reg
                    break
                end
                -- Also try partial match
                if realName and normalizedName:find(realName, 1, true) == 1 then
                    item = reg
                    break
                end
                if realName and realName:find(normalizedName, 1, true) == 1 then
                    item = reg
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

local function ShortenChannelInLine(msg)
    if not msg or type(msg) ~= "string" or msg == "" then return msg end
    if not addon.db or not addon.db.enabled then return msg end
    local fmt = addon.db.plugin.chat and addon.db.plugin.chat.visual and addon.db.plugin.chat.visual.channelNameFormat or "SHORT"
    if fmt == "NONE" then return msg end
    -- Skip if message contains any hyperlink to avoid corrupting links
    -- Hyperlinks look like |Hplayer:...|h or |Hitem:...|h etc.
    if msg:find("|H", 1, true) then return msg end
    -- Skip timestamp-like patterns [HH:MM] or [HH:MM:SS] to avoid corrupting Blizzard timestamps
    if msg:match("^%[%d+:%d+") then return msg end
    return (msg:gsub("^()%[([^%]]+)%]", function(_, inner)
        local short = ShortenChannelString(inner, fmt)
        return "[" .. (short and short ~= inner and short or inner) .. "]"
    end, 1))
end

local function ShortChannelFilter(self, event, msg, ...)
    if not addon.db or not addon.db.enabled then return false, msg, ... end
    local format = addon.db.plugin.chat and addon.db.plugin.chat.visual and addon.db.plugin.chat.visual.channelNameFormat or "SHORT"
    if format == "NONE" then return false, msg, ... end

    local args = { ... }
    if args[2] and type(args[2]) == "string" and #args[2] > 0 then
        local newVal = ShortenChannelString(args[2], format)
        if newVal ~= args[2] then
            args[2] = newVal
            return false, msg, unpack(args)
        end
    end
    return false, msg, ...
end

local CHANNEL_EVENTS = {
    "CHAT_MSG_CHANNEL", "CHAT_MSG_GUILD", "CHAT_MSG_OFFICER", "CHAT_MSG_PARTY",
    "CHAT_MSG_PARTY_LEADER", "CHAT_MSG_RAID", "CHAT_MSG_RAID_LEADER",
    "CHAT_MSG_SAY", "CHAT_MSG_YELL", "CHAT_MSG_WHISPER", "CHAT_MSG_WHISPER_INFORM"
}

function addon:InitVisual()
    addon:RegisterChatFrameTransformer("visual", function(frame, msg, ...)
        if type(msg) == "string" and msg ~= "" and addon.db and addon.db.enabled and addon.db.plugin.chat and addon.db.plugin.chat.visual then
            local newMsg = ShortenChannelInLine(msg)
            if newMsg then return newMsg end
        end
        return msg
    end)

    for _, event in ipairs(CHANNEL_EVENTS) do
        ChatFrame_AddMessageEventFilter(event, ShortChannelFilter)
    end

    addon:ApplyChatVisualSettings()
    addon:ApplyChatFontSettings()
end

-- Hook management for channel name functions
function addon:ApplyChannelNameHooks()
    local format = addon.db and addon.db.enabled and addon.db.plugin.chat and addon.db.plugin.chat.visual and addon.db.plugin.chat.visual.channelNameFormat or "SHORT"
    
    if not addon.db or not addon.db.enabled or format == "NONE" then
        -- Restore original functions if hooked
        if addon.OriginalResolveChannelName and addon._ResolveChannelNameHooked then
            ChatFrame_ResolveChannelName = addon.OriginalResolveChannelName
            addon._ResolveChannelNameHooked = false
        end
        if addon.OriginalResolvePrefixed and addon._ResolvePrefixedHooked then
            if ChatFrameUtil and ChatFrameUtil.ResolvePrefixedChannelName then
                ChatFrameUtil.ResolvePrefixedChannelName = addon.OriginalResolvePrefixed
            elseif ChatFrame_ResolvePrefixedChannelName then
                ChatFrame_ResolvePrefixedChannelName = addon.OriginalResolvePrefixed
            end
            addon._ResolvePrefixedHooked = false
        end
        return
    end
    
    -- Hook ChatFrame_ResolveChannelName (only once)
    if not addon._ResolveChannelNameHooked then
        if not addon.OriginalResolveChannelName then
            addon.OriginalResolveChannelName = ChatFrame_ResolveChannelName
        end
        ChatFrame_ResolveChannelName = function(name)
            local fmt = addon.db and addon.db.plugin.chat and addon.db.plugin.chat.visual and addon.db.plugin.chat.visual.channelNameFormat or "SHORT"
            if fmt ~= "NONE" and name then
                for _, reg in ipairs(addon.CHANNEL_REGISTRY or {}) do
                    if reg.label == name then
                        return addon:GetChannelLabel(reg, nil)
                    end
                    if reg.mappingKey then
                        local realName = L[reg.mappingKey]
                        if realName == name then
                            return addon:GetChannelLabel(reg, nil)
                        end
                        if realName and name:find(realName, 1, true) == 1 then
                            return addon:GetChannelLabel(reg, nil)
                        end
                        if realName and realName:find(name, 1, true) == 1 then
                            return addon:GetChannelLabel(reg, nil)
                        end
                    end
                end
            end
            return addon.OriginalResolveChannelName(name)
        end
        addon._ResolveChannelNameHooked = true
    end
    
    -- Hook ResolvePrefixedChannelName (only once)
    if not addon._ResolvePrefixedHooked then
        if ChatFrameUtil and ChatFrameUtil.ResolvePrefixedChannelName then
            if not addon.OriginalResolvePrefixed then
                addon.OriginalResolvePrefixed = ChatFrameUtil.ResolvePrefixedChannelName
            end
            ChatFrameUtil.ResolvePrefixedChannelName = function(communityChannel)
                return addon:ResolveShortPrefixed(communityChannel)
            end
            addon._ResolvePrefixedHooked = true
        elseif ChatFrame_ResolvePrefixedChannelName then
            if not addon.OriginalResolvePrefixed then
                addon.OriginalResolvePrefixed = ChatFrame_ResolvePrefixedChannelName
            end
            ChatFrame_ResolvePrefixedChannelName = function(communityChannel)
                return addon:ResolveShortPrefixed(communityChannel)
            end
            addon._ResolvePrefixedHooked = true
        end
    end
end

function addon:ResolveShortPrefixed(communityChannel)
    local format = addon.db and addon.db.plugin.chat and addon.db.plugin.chat.visual and addon.db.plugin.chat.visual.channelNameFormat or "SHORT"
    local prefix, rest = string.match(communityChannel, "^(%d+)%.%s*(.*)")
    if not prefix then
        prefix = string.match(communityChannel, "^(%d+)%.")
        rest = ""
    end
    
    if format == "NUMBER" then
        if prefix then return prefix end
        return communityChannel
    elseif format == "SHORT" then
        -- Get the channel name part and resolve to short name
        local channelPart = (rest and #rest > 0) and rest or nil
        if channelPart then
            local short = ChatFrame_ResolveChannelName(channelPart)
            if short and short ~= channelPart then
                return short
            end
        end
        -- If no name part but we have prefix, try to resolve by channel ID
        if prefix then
            local id = tonumber(prefix)
            if id then
                local name = GetJoinedChannelNameById(id)
                if name then
                    local normalized = addon.Utils.NormalizeChannelBaseName(name)
                    local short = ChatFrame_ResolveChannelName(normalized)
                    if short and short ~= normalized then
                        return short
                    end
                end
                for _, reg in ipairs(addon.CHANNEL_REGISTRY or {}) do
                    if reg.mappingKey and reg.isDynamic then
                        local realName = L[reg.mappingKey]
                        if realName then
                            local chanId = GetChannelName(realName)
                            if chanId == id then
                                return addon:GetChannelLabel(reg, nil)
                            end
                        end
                    end
                end
            end
        end
    elseif format == "NUMBER_SHORT" then
        local channelPart = (rest and #rest > 0) and rest or nil
        if channelPart then
            local short = ChatFrame_ResolveChannelName(channelPart)
            if short and short ~= channelPart then
                return prefix .. "." .. short
            end
        end
        if prefix then return prefix end
    elseif format == "FULL" then
        return rest or communityChannel
    end
    
    if addon.OriginalResolvePrefixed then
        return addon.OriginalResolvePrefixed(communityChannel)
    end
    return communityChannel
end

function addon:ApplyChatVisualSettings()
    ApplyShortChannelGlobals()
    addon:ApplyChannelNameHooks()
    UpdateSticky()
    HookEditBoxForSticky()
    if addon.db and addon.db.plugin.chat and addon.db.plugin.chat.interaction and addon.db.plugin.chat.interaction.sticky and C_Timer and C_Timer.After then
        C_Timer.After(2, function()
            if addon.db and addon.db.plugin.chat and addon.db.plugin.chat.interaction and addon.db.plugin.chat.interaction.sticky then
                UpdateSticky()
            end
        end)
    end
end

function addon:ApplyVisualSettings()
    addon:ApplyChatVisualSettings()
    addon:ApplyChatFontSettings()
end
