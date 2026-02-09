local addonName, addon = ...

local EVENT_TO_CHANNEL_KEY = {
    ["CHAT_MSG_GUILD"] = "GUILD",
    ["CHAT_MSG_OFFICER"] = "OFFICER",
    ["CHAT_MSG_SAY"] = "SAY",
    ["CHAT_MSG_YELL"] = "YELL",
    ["CHAT_MSG_PARTY"] = "PARTY",
    ["CHAT_MSG_PARTY_LEADER"] = "PARTY",
    ["CHAT_MSG_RAID"] = "RAID",
    ["CHAT_MSG_RAID_LEADER"] = "RAID",
    ["CHAT_MSG_INSTANCE_CHAT"] = "INSTANCE_CHAT",
    ["CHAT_MSG_INSTANCE_CHAT_LEADER"] = "INSTANCE_CHAT",
    ["CHAT_MSG_WHISPER"] = "WHISPER",
    ["CHAT_MSG_WHISPER_INFORM"] = "WHISPER",
    ["CHAT_MSG_EMOTE"] = "EMOTE",
    ["CHAT_MSG_TEXT_EMOTE"] = "EMOTE",
    ["CHAT_MSG_SYSTEM"] = "SYSTEM",
    ["CHAT_MSG_RAID_WARNING"] = "RAID_WARNING",
}

-- Default timestamp color for restored messages (gray)
local DEFAULT_SNAPSHOT_TIMESTAMP_COLOR = "FF888888"

local function GetCharKey()
    local name = UnitName("player")
    local realm = GetRealmName()
    -- Ensure we have valid data, otherwise fallback to "Default" to avoid "?" keys
    if not name or name == "" or not realm or realm == "" or realm == "?" then
        return "Default"
    end
    return name .. "-" .. realm
end

-- Find registry key by channel ID (for dynamic channels)
-- Uses addon.Utils.NormalizeChannelBaseName for normalization

-- Cache for channel name lookups to avoid repeated linear searches
local channelNameCache = {}

local function FindRegistryKeyByChannelBaseName(baseName)
    if not baseName then return nil end
    
    -- Check cache first
    if channelNameCache[baseName] ~= nil then
        return channelNameCache[baseName]
    end
    
    local L = addon.L
    local normalized = addon.Utils.NormalizeChannelBaseName(baseName)
    
    for _, stream, catKey, subKey in addon:IterateAllStreams() do
        if subKey == "DYNAMIC" and stream.mappingKey then
            local realName = L[stream.mappingKey]
            if realName then
                if realName == normalized or normalized:find(realName, 1, true) == 1 or realName:find(normalized, 1, true) == 1 then
                    channelNameCache[baseName] = stream.key
                    return stream.key
                end
            end
        end
    end
    
    -- Cache negative result to avoid repeated lookups for unknown channels
    channelNameCache[baseName] = false
    return nil
end

local function GetChannelKey(event, ...)
    local key = EVENT_TO_CHANNEL_KEY[event]
    if key then 
        if key == "INSTANCE_CHAT" then return "instance" end
        return string.lower(key) 
    end
    if event == "CHAT_MSG_CHANNEL" then
        local channelBaseName = select(7, ...)
        local registryKey = FindRegistryKeyByChannelBaseName(channelBaseName)
        if registryKey then return registryKey end
        return "channel_" .. (channelBaseName and string.lower(tostring(channelBaseName)) or "?")
    end
    return string.lower(event or "?")
end

local function CountTotalStoredLines()
    if not addon.db or not addon.db.global or type(addon.db.global.chatSnapshot) ~= "table" then return 0 end
    local total = 0
    for _, perChannel in pairs(addon.db.global.chatSnapshot) do
        if type(perChannel) == "table" then
            for _, lines in pairs(perChannel) do
                if type(lines) == "table" then total = total + #lines end
            end
        end
    end
    return total
end

local function GetLineCount()
    if addon.db.global.chatSnapshotLineCount == nil then
        addon.db.global.chatSnapshotLineCount = CountTotalStoredLines()
    end
    return addon.db.global.chatSnapshotLineCount
end

-- Eviction buffer: only trigger cleanup when exceeding maxTotal + buffer
local EVICT_BUFFER = 100

local function EvictOldestUntilUnderMax()
    if not addon.db or not addon.db.global or not addon.db.global.chatSnapshot then return end
    
    local maxTotal = addon.db.global.chatSnapshotMaxTotal
    if type(maxTotal) ~= "number" or maxTotal <= 0 then return end
    
    local currentCount = GetLineCount()
    -- Only trigger cleanup when exceeding threshold (maxTotal + buffer)
    if currentCount <= maxTotal + EVICT_BUFFER then return end
    
    local currentChar = GetCharKey()
    local content = addon.db.global.chatSnapshot
    local chars = {}
    for c in pairs(content) do chars[#chars + 1] = c end
    table.sort(chars, function(a, b)
        if a == currentChar then return true end
        if b == currentChar then return false end
        return a < b
    end)
    
    -- Batch removal: remove multiple entries at once to reach target
    local toRemove = currentCount - maxTotal
    local removed = 0
    
    for _, charKey in ipairs(chars) do
        if removed >= toRemove then break end
        local perChannel = content[charKey]
        if type(perChannel) == "table" then
            for chKey, lines in pairs(perChannel) do
                if removed >= toRemove then break end
                if type(lines) == "table" then
                    local canRemove = math.min(#lines, toRemove - removed)
                    if canRemove > 0 then
                        -- Batch remove from front
                        for i = 1, canRemove do
                            table.remove(lines, 1)
                        end
                        removed = removed + canRemove
                    end
                end
            end
        end
    end
    
    addon.db.global.chatSnapshotLineCount = math.max(0, (addon.db.global.chatSnapshotLineCount or 0) - removed)
end


function addon:ClearHistory()
    local L = addon.L
    if not addon.db or not addon.db.global.chatSnapshot then return end
    local charKey = GetCharKey()
    local perChannel = addon.db.global.chatSnapshot[charKey]
    if perChannel and type(perChannel) == "table" then
        local n = 0
        for _, lines in pairs(perChannel) do
            if type(lines) == "table" then n = n + #lines end
        end
        addon.db.global.chatSnapshotLineCount = math.max(0, (addon.db.global.chatSnapshotLineCount or 0) - n)
    end
    addon.db.global.chatSnapshot[charKey] = {}
    print("|cff00ff00" .. L["LABEL_ADDON_NAME"] .. "|r: " .. L["MSG_HISTORY_CLEARED"])
end

function addon:InitSnapshotManager()
    local L = addon.L

    local restored
    
    -- Get color for chat type
    local function RestoreChannelContent()
        if restored then return end
        
        -- 1. Global & Module Switch Check
        if not addon.db or not addon.db.enabled then return end
        
        local chatSettings = addon.db.plugin and addon.db.plugin.chat
        if not chatSettings or not chatSettings.content or chatSettings.content.snapshotEnabled == false then
            return
        end
        
        if not addon.db.global or not addon.db.global.chatSnapshot or type(addon.db.global.chatSnapshot) ~= "table" then return end
        local charKey = GetCharKey()
        local perChannel = addon.db.global.chatSnapshot[charKey]
        if not perChannel or type(perChannel) ~= "table" then return end
        
        local function addStoredLine(line)
            if not line or type(line) ~= "table" or not line.text then return end
            
            -- Get target frame (use recorded frame or fallback to ChatFrame1)
            local frame = line.frameName and _G[line.frameName]
            if not frame or not frame.AddMessage then
                frame = ChatFrame1
            end
            if not frame or not frame.AddMessage then return end
            
            -- 2. Channel tag: use unified resolver
            local channelNameDisplay, registryItem = addon.Utils.ResolveChannelDisplay({
                chatType = line.chatType,
                channelId = line.channelId,
                channelName = line.channelBaseNameNormalized,
                registryKey = line.registryKey,
            })
            
            -- Apply channel color from current system ChatTypeInfo (same as message body)
            local channelTag = channelNameDisplay
            -- Get color from ChatTypeInfo to match message body color
            local chatTypeForColor = line.chatType
            if line.chatType == "CHANNEL" and line.channelId then
                chatTypeForColor = "CHANNEL" .. line.channelId
            end
            
            if ChatTypeInfo and ChatTypeInfo[chatTypeForColor] then
                local info = ChatTypeInfo[chatTypeForColor]
                local r, g, b = info.r or 1, info.g or 1, info.b or 1
                channelTag = string.format("|cff%02x%02x%02x%s|r", r * 255, g * 255, b * 255, channelNameDisplay)
            end
            
            -- Wrap in |Hchannel:CHANNEL:id|h...|h link if valid channel ID exists
            -- Format: |Hchannel:CHANNEL:channelId|h to ensure proper chatType resolution
            if line.chatType == "CHANNEL" and line.channelId then
                channelTag = string.format("|Hchannel:CHANNEL:%s|h%s|h", line.channelId, channelTag)
            end
            
            -- 3. Author with class color
            local authorTag = ""
            if line.author and line.author ~= "" then
                local authorName = line.author
                -- Apply class color if available
                if line.classFilename and RAID_CLASS_COLORS and RAID_CLASS_COLORS[line.classFilename] then
                    local classColor = RAID_CLASS_COLORS[line.classFilename]
                    authorName = string.format("|cff%02x%02x%02x%s|r", 
                        classColor.r * 255, classColor.g * 255, classColor.b * 255, line.author)
                end
                -- Wrap in player link for interaction
                -- Removed trailing space after colon to match standard/locale behavior better (especially CN)
                authorTag = string.format("|Hplayer:%s|h[%s]|h:", line.author, authorName)
            end
            
            -- 4. Build message and Timestamp
            local finalText = line.text
            if addon.Emotes and addon.Emotes.Parse then
                finalText = addon.Emotes.Parse(finalText)
            end

            -- Construct the full copyable string (Channel + Author + Text)
            local copyableMsg = channelTag .. " " .. authorTag .. finalText
            
            -- 1. Timestamp generation using System Settings (Phase 3)
            local timestamp = ""
            if line.time then
                local showTimestamp = C_CVar.GetCVar("showTimestamps")
                
                if showTimestamp and showTimestamp ~= "none" then
                    -- Use system API to format date identically to chat frame
                    -- TIMESTAMP_FORMAT global might be nil early on, fallback to local CVar value
                    local ts = BetterDate(TIMESTAMP_FORMAT or showTimestamp, line.time)
                    
                    -- Linkify if needed (Click to copy)
                    local clickEnabled = (addon.db.plugin.chat.interaction and addon.db.plugin.chat.interaction.clickToCopy ~= false)
                    
                    -- Note: System timestamp color is usually handled by ChatFrame, but here we reconstruct it.
                    local tsColor = (addon.db.plugin.chat.interaction and addon.db.plugin.chat.interaction.timestampColor) or DEFAULT_SNAPSHOT_TIMESTAMP_COLOR
                    
                         -- Smart Spacing for History:
                         -- If the formatted time 'ts' doesn't end with a space, add one.
                         local hNeedsSpace = (ts:sub(-1) ~= " ")
                         
                         if clickEnabled then
                              local copyId = tostring(line.time) .. "_" .. tostring(math.random(10000, 99999))
                              
                              -- Prepend timestamp to copyable message
                              local fullCopyMsg = string.format("%s%s", ts, copyableMsg)
                              
                              if addon.messageCache then
                                 addon.messageCache[copyId] = { msg = fullCopyMsg, time = GetTime() }
                              end
                              
                              -- Format: Color -> Link -> Time -> Space
                              timestamp = string.format("|c%s|Htinychat:copy:%s|h%s|h%s|r", tsColor, copyId, ts, hNeedsSpace and " " or "")
                         else
                              timestamp = string.format("|c%s%s%s|r", tsColor, ts, hNeedsSpace and " " or "")
                         end
                end
            end
            local displayLine = timestamp .. channelTag .. authorTag .. finalText
            
            -- 5. Add to frame using original AddMessage (bypass transformers to avoid double timestamp)
            local addMessageFn = frame._TinyChatonOrigAddMessage or frame.AddMessage
            
            -- Get message color from current system's ChatTypeInfo
            local chatTypeForColor = line.chatType
            -- For CHANNEL messages, WoW uses "CHANNEL" + channelId as the key
            if line.chatType == "CHANNEL" and line.channelId then
                chatTypeForColor = "CHANNEL" .. line.channelId
            end
            
            local r, g, b = 1, 1, 1  -- Default to white
            if ChatTypeInfo and ChatTypeInfo[chatTypeForColor] then
                local info = ChatTypeInfo[chatTypeForColor]
                r, g, b = info.r or 1, info.g or 1, info.b or 1
            end
            
            addMessageFn(frame, displayLine, r, g, b)
        end

        -- Collect all messages from all channels
        local allLines = {}
        for chKey, lines in pairs(perChannel) do
            if type(lines) == "table" then
                for _, line in ipairs(lines) do
                    table.insert(allLines, line)
                end
            end
        end
        
        -- Sort by time
        table.sort(allLines, function(a, b)
            return (a.time or 0) < (b.time or 0)
        end)
        
        -- Restore each line to its recorded frame
        for _, line in ipairs(allLines) do
            addStoredLine(line)
        end
        
        restored = true
    end
    
    -- Trigger immediate backfill if already in game (e.g. ReloadUI)
    if IsLoggedIn() then
        RestoreChannelContent()
    end

    if addon.RegisterEvent then
        addon:RegisterEvent("PLAYER_ENTERING_WORLD", function()
            -- Delay slightly to ensure chat frames are ready
            C_Timer.After(0.1, RestoreChannelContent)
        end)
    end
end

-- ============================================
-- Snapshot Configuration Helpers
-- ============================================

function addon:GetSnapshotChannelsItems(filter)
    -- filter: "private" | "system" | "dynamic" | nil(全部)
    local items = {}
    
    for _, stream, catKey, subKey in addon:IterateAllStreams() do
        -- Skip items that shouldn't be snapshotted (e.g. non-storable)
        if not stream.isNotStorable then
            local match = false
            local isPrivate = (stream.chatType == "WHISPER" or stream.chatType == "BN_WHISPER")
            
            if filter == "private" and isPrivate then 
                match = true
            elseif filter == "system" and subKey == "SYSTEM" then 
                match = true
            elseif filter == "dynamic" and subKey == "DYNAMIC" then 
                match = true
            elseif not filter then 
                match = true
            end
            
            if match then
                table.insert(items, { 
                    key = stream.key, 
                    label = stream.label or stream.key,
                    value = stream.key,  -- for MultiDropdown compatibility
                    text = stream.label or stream.key,
                })
            end
        end
    end
    return items
end

function addon:GetSnapshotChannelSelection(filter)
    if not self.db or not self.db.plugin.chat or not self.db.plugin.chat.content.snapshotChannels then 
        return {}
    end
    local sc = self.db.plugin.chat.content.snapshotChannels
    local items = self:GetSnapshotChannelsItems(filter)
    local selection = {}
    for _, item in ipairs(items) do
        -- 默认为选中状态（除非明确设为 false）
        selection[item.key] = (sc[item.key] ~= false)
    end
    return selection
end

function addon:SetSnapshotChannelSelection(filter, selection)
    if not self.db or not self.db.plugin.chat or not self.db.plugin.chat.content then 
        return
    end
    if not self.db.plugin.chat.content.snapshotChannels then
        self.db.plugin.chat.content.snapshotChannels = {}
    end
    local sc = self.db.plugin.chat.content.snapshotChannels
    local items = self:GetSnapshotChannelsItems(filter)
    
    for _, item in ipairs(items) do
        sc[item.key] = selection[item.key] and true or false
    end
    
    if addon.ApplyAllSettings then addon:ApplyAllSettings() end
end

function addon:GetSnapshotChannelsSummary()
    if not self.db or not self.db.plugin.chat or not self.db.plugin.chat.content.snapshotChannels then 
        return L["LABEL_SNAPSHOT_CHANNELS_ALL"] 
    end
    local sc = self.db.plugin.chat.content.snapshotChannels
    local items = self:GetSnapshotChannelsItems()
    local selected = {}
    for _, item in ipairs(items) do
        if sc[item.key] ~= false then table.insert(selected, item.label) end
    end
    if #selected >= #items then return L["LABEL_SNAPSHOT_CHANNELS_ALL"] end
    if #selected == 0 then return L["LABEL_SNAPSHOT_CHANNELS_NONE"] end
    return table.concat(selected, "、")
end
