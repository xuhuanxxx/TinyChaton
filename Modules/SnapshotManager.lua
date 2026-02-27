local addonName, addon = ...

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
    local charKey = addon:GetCharacterKey()
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

-- Helper: Get formatted timestamp with copy link
local function FormatTimestamp(line, contentString)
    if not line.time then return "" end

    -- Use Formatter for base text and color
    -- For Snapshot, we usually don't have R/G/B stored in line unless we parse it.
    -- But we want to follow the logic: Configured Color > Message Color > Default.
    -- Here we only have 'line' info.
    
    -- Try to deduce color from chatType if possible, similar to FormatChannelTag?
    local msgColor = nil
    if line.chatType and ChatTypeInfo and ChatTypeInfo[line.chatType] then
         -- This is approximate. Real message color might differ.
         -- But for Snapshot it's acceptable fallback if not using Config.
         local info = ChatTypeInfo[line.chatType]
         msgColor = {r = info.r, g = info.g, b = info.b}
    end

    local tsText = addon.MessageFormatter.GetTimestamp(line.time, msgColor, true)
    if tsText == "" then return "" end

    local clickEnabled = (addon.db.plugin.chat.interaction and addon.db.plugin.chat.interaction.clickToCopy ~= false)
    if clickEnabled then
         local colorHex = addon.MessageFormatter.ResolveTimestampColor(msgColor, true)
         local plainText = addon.MessageFormatter.GetTimestampText(line.time)
         
         -- Use existing API for click-wrapping
         return addon:CreateClickableTimestamp(plainText, contentString or "", colorHex)
    else
         return tsText
    end
end

function addon:InitSnapshotManager()
    local L = addon.L
    local restored

    if addon.RegisterEvent and addon.Utils and addon.Utils.InvalidateChannelCaches then
        addon:RegisterEvent("PLAYER_ENTERING_WORLD", function()
            addon.Utils.InvalidateChannelCaches()
        end)
        addon:RegisterEvent("CHANNEL_UI_UPDATE", function()
            addon.Utils.InvalidateChannelCaches()
        end)
        addon:RegisterEvent("CHAT_MSG_CHANNEL_NOTICE", function()
            addon.Utils.InvalidateChannelCaches()
        end)
    end

    local function RestoreChannelContent()
        if restored then return end
        if not addon.db or not addon.db.enabled then return end
        if addon.Can and not addon:Can(addon.CAPABILITIES.PERSIST_CHAT_DATA) then
            return
        end
        
        local snapshotEnabled = addon:GetConfig("plugin.chat.content.snapshotEnabled", true)
        if not snapshotEnabled then return end

        if not addon.db.global or not addon.db.global.chatSnapshot or type(addon.db.global.chatSnapshot) ~= "table" then return end
        local charKey = addon:GetCharacterKey()
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

        local mockChatData = {}
        for _, line in ipairs(allLines) do
            if line and type(line) == "table" and line.text then
                local frame = line.frameName and _G[line.frameName] or ChatFrame1
                if frame and frame.AddMessage then
                    local channelTag = addon.MessageFormatter.GetChannelTag(line)
                    local authorTag = addon.MessageFormatter.GetAuthorTag(line)
                    -- DELAYED: local timestamp = FormatTimestamp(line)
                    
                    local finalText = line.text

                    -- Apply Filters (Blacklist/Whitelist)
                    -- Reuse mockChatData to reduce GC
                    table.wipe(mockChatData)
                    mockChatData.text = finalText
                    mockChatData.author = line.authorName or "?"
                    mockChatData.name = line.authorName or "?" 
                    mockChatData.authorLower = string.lower(line.authorName or "?")
                    mockChatData.textLower = string.lower(finalText)
                    
                    local isBlocked = false
                    if addon.Filters and addon.Filters.BlacklistProcess then
                         if addon.Filters.BlacklistProcess(mockChatData) then isBlocked = true end
                    end
                    
                    if not isBlocked and addon.Filters and addon.Filters.WhitelistProcess then
                         if addon.Filters.WhitelistProcess(mockChatData) then isBlocked = true end
                    end

                    if not isBlocked then
                        -- Now we have the final content, generate timestamp
                        -- Construct the full message (minus timestamp) for the copy payload
                        local contentForCopy = string.format("%s%s%s", channelTag, authorTag, finalText)
                        local timestamp = FormatTimestamp(line, contentForCopy)
                        
                        local displayLine = string.format("%s%s", timestamp, contentForCopy)

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

                        if addon.Gateway and addon.Gateway.Display and addon.Gateway.Display.Transform then
                            displayLine = addon.Gateway.Display:Transform(frame, displayLine, r, g, b)
                        end

                        local addMessageFn = frame._TinyChatonOrigAddMessage or frame.AddMessage
                        addMessageFn(frame, displayLine, r, g, b)
                    end
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
