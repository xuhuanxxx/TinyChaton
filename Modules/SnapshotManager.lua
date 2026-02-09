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

-- Incremental Eviction System (MC-002)
local cleanupTicker
local CLEANUP_BATCH_SIZE = 50

local function StopCleanup()
    if cleanupTicker then
        cleanupTicker:Cancel()
        cleanupTicker = nil
    end
end

local function PerformEvictionBatch()
    if not addon.db or not addon.db.global or not addon.db.global.chatSnapshot then
        StopCleanup()
        return
    end

    local maxTotal = addon.db.global.chatSnapshotMaxTotal
    if type(maxTotal) ~= "number" or maxTotal <= 0 then
        StopCleanup()
        return
    end

    -- Recalculate count
    local currentCount = GetLineCount()
    if currentCount <= maxTotal then
        StopCleanup()
        return
    end

    -- Eviction Logic
    -- Heuristic: Remove from current character first (as in original logic),
    -- then others. Ideally we should find the oldest messages globally,
    -- but sorting everything is too expensive.
    -- We'll just iterate and prune.

    local content = addon.db.global.chatSnapshot
    local removedCount = 0

    for charKey, perChannel in pairs(content) do
        if removedCount >= CLEANUP_BATCH_SIZE then break end

        if type(perChannel) == "table" then
            for chKey, lines in pairs(perChannel) do
                if removedCount >= CLEANUP_BATCH_SIZE then break end

                if type(lines) == "table" and #lines > 0 then
                    local canRemove = math.min(#lines, CLEANUP_BATCH_SIZE - removedCount)
                    -- Don't empty the channel completely unless necessary?
                    -- Actually, we just want to reduce total count.

                    for i = 1, canRemove do
                        table.remove(lines, 1) -- Remove oldest in channel
                    end
                    removedCount = removedCount + canRemove
                end
            end
        end
    end

    -- Update count
    addon.db.global.chatSnapshotLineCount = math.max(0, currentCount - removedCount)

    -- Validation checks
    if removedCount == 0 then
        -- Could not remove anything but count > maxTotal?
        -- This implies inconsistency or empty tables. Force stop to avoid infinite loop.
        StopCleanup()
        -- Force recalc next time
        addon.db.global.chatSnapshotLineCount = CountTotalStoredLines()
    end
end

-- Public trigger
function addon:TriggerEviction()
    if cleanupTicker then return end -- Already running

    local current = GetLineCount()
    local max = addon.db.global.chatSnapshotMaxTotal or 5000

    if current > max then
        cleanupTicker = C_Timer.NewTicker(0.05, PerformEvictionBatch) -- 20 times per second
    end
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

-- Helper: Get channel tag with color and link
local function FormatChannelTag(line)
    local channelNameDisplay, registryItem = addon.Utils.ResolveChannelDisplay({
        chatType = line.chatType,
        channelId = line.channelId,
        channelName = line.channelBaseNameNormalized,
        registryKey = line.registryKey,
    })

    local channelTag = channelNameDisplay
    local chatTypeForColor = line.chatType
    if line.chatType == "CHANNEL" and line.channelId then
        chatTypeForColor = "CHANNEL" .. line.channelId
    end

    if ChatTypeInfo and ChatTypeInfo[chatTypeForColor] then
        local info = ChatTypeInfo[chatTypeForColor]
        local r, g, b = info.r or 1, info.g or 1, info.b or 1
        channelTag = string.format("|cff%02x%02x%02x%s|r", r * 255, g * 255, b * 255, channelNameDisplay)
    end

    local linkType = "channel"
    local linkArg = line.channelId or line.chatType
    
    if line.chatType == "CHANNEL" then
        linkArg = line.channelId
    elseif line.chatType == "INSTANCE_CHAT" then
        linkArg = "INSTANCE"
    end
    
    return string.format("|Hchannel:%s|h%s|h", linkArg, channelTag)
end

-- Helper: Get author tag with class color and link
local function FormatAuthorTag(line)
    if not line.author or line.author == "" then return "" end
    
    local authorName = line.author
    if line.classFilename and RAID_CLASS_COLORS and RAID_CLASS_COLORS[line.classFilename] then
        local classColor = RAID_CLASS_COLORS[line.classFilename]
        authorName = string.format("|cff%02x%02x%02x%s|r",
            classColor.r * 255, classColor.g * 255, classColor.b * 255, line.author)
    end
    
    return string.format("|Hplayer:%s|h[%s]|h:", line.author, authorName)
end

-- Helper: Get formatted timestamp with copy link
local function FormatTimestamp(line)
    if not line.time then return "" end
    local showTimestamp = C_CVar.GetCVar("showTimestamps")
    if not showTimestamp or showTimestamp == "none" then return "" end

    local ts = BetterDate(TIMESTAMP_FORMAT or showTimestamp, line.time)
    if ts:sub(-1) ~= " " then ts = ts .. " " end

    local tsColor = (addon.db.plugin.chat.interaction and addon.db.plugin.chat.interaction.timestampColor) or DEFAULT_SNAPSHOT_TIMESTAMP_COLOR
    local clickEnabled = (addon.db.plugin.chat.interaction and addon.db.plugin.chat.interaction.clickToCopy ~= false)

    if addon.CreateClickableTimestamp then
        -- Pass placeholder msg because we don't need full msg here for display
        return addon:CreateClickableTimestamp(ts, "", tsColor)
    elseif clickEnabled then
        local copyId = tostring(line.time) .. "_" .. tostring(math.random(10000, 99999))
        -- Cache mechanism would need full message which we construct later
        -- For simplicity in fallback mode, we skip copy cache or assume external handling
        return string.format("|c%s|Htinychat:copy:%s|h%s|h|r ", tsColor, copyId, ts)
    else
        return string.format("|c%s%s|r ", tsColor, ts)
    end
end

function addon:InitSnapshotManager()
    local L = addon.L
    local restored

    local function RestoreChannelContent()
        if restored then return end
        if not addon.db or not addon.db.enabled then return end
        
        local snapshotEnabled = addon:GetConfig("plugin.chat.content.snapshotEnabled", true)
        if not snapshotEnabled then return end

        if not addon.db.global or not addon.db.global.chatSnapshot or type(addon.db.global.chatSnapshot) ~= "table" then return end
        local charKey = GetCharKey()
        local perChannel = addon.db.global.chatSnapshot[charKey]
        if not perChannel or type(perChannel) ~= "table" then return end

        -- Collect all lines
        local allLines = {}
        for chKey, lines in pairs(perChannel) do
            if type(lines) == "table" then
                for _, line in ipairs(lines) do
                    table.insert(allLines, line)
                end
            end
        end

        table.sort(allLines, function(a, b)
            return (a.time or 0) < (b.time or 0)
        end)

        for _, line in ipairs(allLines) do
            if line and type(line) == "table" and line.text then
                local frame = line.frameName and _G[line.frameName] or ChatFrame1
                if frame and frame.AddMessage then
                    local channelTag = FormatChannelTag(line)
                    local authorTag = FormatAuthorTag(line)
                    local timestamp = FormatTimestamp(line)
                    
                    local finalText = line.text
                    if addon.Emotes and addon.Emotes.Parse then
                        finalText = addon.Emotes.Parse(finalText)
                    end
                    
                    -- Update timestamp copy content if needed (tricky due to decoupling)
                    -- Ideally CreateClickableTimestamp handles the ID generation and we cache the full message then
                    -- But here we just simplified. For robust Copy, we might need to re-cache based on ID if using fallback.
                    
                    local displayLine = string.format("%s%s%s%s", timestamp, channelTag, authorTag, finalText)
                    
                    -- Determine color
                    local chatTypeForColor = line.chatType
                    if line.chatType == "CHANNEL" and line.channelId then
                        chatTypeForColor = "CHANNEL" .. line.channelId
                    end
                    
                    local r, g, b = 1, 1, 1
                    if ChatTypeInfo and ChatTypeInfo[chatTypeForColor] then
                        local info = ChatTypeInfo[chatTypeForColor]
                        r, g, b = info.r or 1, info.g or 1, info.b or 1
                    end

                    local addMessageFn = frame._TinyChatonOrigAddMessage or frame.AddMessage
                    addMessageFn(frame, displayLine, r, g, b)
                end
            end
        end

        restored = true
    end

    if IsLoggedIn() then
        RestoreChannelContent()
    end

    if addon.RegisterEvent then
        addon:RegisterEvent("PLAYER_ENTERING_WORLD", function()
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

    -- Trigger cleanup in case limits changed
    addon:TriggerEviction()
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

-- P0: Register Module
addon:RegisterModule("SnapshotManager", addon.InitSnapshotManager)
