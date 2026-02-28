local addonName, addon = ...

local function IsRingBuffer(buffer)
    return type(buffer) == "table"
        and type(buffer.items) == "table"
        and type(buffer.head) == "number"
        and type(buffer.tail) == "number"
        and type(buffer.size) == "number"
end

local function CompactRingBuffer(buffer)
    if not IsRingBuffer(buffer) then return end
    if buffer.size <= 0 then
        buffer.items = {}
        buffer.head = 1
        buffer.tail = 0
        buffer.size = 0
        return
    end
    if buffer.head <= 64 and buffer.head <= (buffer.tail / 2) then
        return
    end
    local newItems = {}
    local idx = 1
    for i = buffer.head, buffer.tail do
        newItems[idx] = buffer.items[i]
        idx = idx + 1
    end
    buffer.items = newItems
    buffer.head = 1
    buffer.tail = idx - 1
end

local function PopOldest(buffer, n)
    if not IsRingBuffer(buffer) or n <= 0 or buffer.size <= 0 then
        return 0
    end
    local removed = math.min(n, buffer.size)
    buffer.head = buffer.head + removed
    buffer.size = buffer.size - removed
    CompactRingBuffer(buffer)
    return removed
end

local function CountTotalStoredLines()
    local storage = addon.GetSnapshotStorage and addon:GetSnapshotStorage()
    if type(storage) ~= "table" then return 0 end
    local total = 0
    for _, channelBuffer in pairs(storage) do
        if IsRingBuffer(channelBuffer) then
            total = total + channelBuffer.size
        end
    end
    return total
end

local function GetLineCount()
    if addon.GetSnapshotLineCount then
        return addon:GetSnapshotLineCount()
    end
    return CountTotalStoredLines()
end

local cleanupTicker
local CLEANUP_BATCH_SIZE = 50

local function StopCleanup()
    if cleanupTicker then
        cleanupTicker:Cancel()
        cleanupTicker = nil
    end
end

local function PerformEvictionBatch()
    local content = addon.GetSnapshotStorage and addon:GetSnapshotStorage()
    if type(content) ~= "table" then
        StopCleanup()
        return
    end

    local maxTotal = addon:GetEffectiveSnapshotStorageLimit()
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

    local removedCount = 0

    for channelKey, channelBuffer in pairs(content) do
        if removedCount >= CLEANUP_BATCH_SIZE then break end
        if IsRingBuffer(channelBuffer) and channelBuffer.size > 0 then
            local canRemove = math.min(channelBuffer.size, CLEANUP_BATCH_SIZE - removedCount)
            local removed = PopOldest(channelBuffer, canRemove)
            removedCount = removedCount + removed
        elseif type(channelBuffer) == "table" then
            -- Corrupted entry: drop it to keep eviction loop healthy.
            content[channelKey] = nil
        end
    end

    addon:SetSnapshotLineCount(math.max(0, currentCount - removedCount))
    if addon.Debug and removedCount > 0 then
        addon:Debug("Snapshot eviction removed=%d remaining=%d max=%d", removedCount, addon:GetSnapshotLineCount(), maxTotal)
    end

    -- Validation checks
    if removedCount == 0 then
        -- Could not remove anything but count > maxTotal?
        -- This implies inconsistency or empty tables. Force stop to avoid infinite loop.
        StopCleanup()
        -- Force recalc next time
        addon:SetSnapshotLineCount(CountTotalStoredLines())
    end
end

-- Public trigger
function addon:TriggerEviction()
    if cleanupTicker then return end -- Already running

    local current = GetLineCount()
    local max = addon:GetEffectiveSnapshotStorageLimit()

    if current > max then
        if addon.Debug then
            addon:Debug("Snapshot eviction scheduled current=%d max=%d", current, max)
        end
        cleanupTicker = C_Timer.NewTicker(0.05, PerformEvictionBatch) -- 20 times per second
    end
end

function addon:SyncTrimSnapshotToLimit(limit)
    local storage = addon.GetSnapshotStorage and addon:GetSnapshotStorage()
    if type(storage) ~= "table" then
        return 0
    end

    local currentCount = GetLineCount()
    local hardLimit = tonumber(limit) or addon:GetEffectiveSnapshotStorageLimit()
    hardLimit = math.max(0, math.floor(hardLimit + 0.5))
    local excess = currentCount - hardLimit
    if excess <= 0 then
        return 0
    end

    local heap = {}
    local function HeapLess(a, b)
        return (a.time or 0) < (b.time or 0)
    end
    local function HeapPush(node)
        heap[#heap + 1] = node
        local i = #heap
        while i > 1 do
            local p = math.floor(i / 2)
            if HeapLess(heap[p], heap[i]) then break end
            heap[i], heap[p] = heap[p], heap[i]
            i = p
        end
    end
    local function HeapPop()
        if #heap == 0 then return nil end
        local root = heap[1]
        heap[1] = heap[#heap]
        heap[#heap] = nil
        local i = 1
        while true do
            local left = i * 2
            local right = left + 1
            local smallest = i
            if left <= #heap and not HeapLess(heap[smallest], heap[left]) then
                smallest = left
            end
            if right <= #heap and not HeapLess(heap[smallest], heap[right]) then
                smallest = right
            end
            if smallest == i then break end
            heap[i], heap[smallest] = heap[smallest], heap[i]
            i = smallest
        end
        return root
    end

    for channelKey, channelBuffer in pairs(storage) do
        if IsRingBuffer(channelBuffer) and channelBuffer.size > 0 then
            local first = channelBuffer.items[channelBuffer.head]
            HeapPush({
                channelKey = channelKey,
                buffer = channelBuffer,
                time = first and first.time or 0,
            })
        elseif type(channelBuffer) == "table" then
            storage[channelKey] = nil
        end
    end

    local removed = 0
    while removed < excess do
        local node = HeapPop()
        if not node then
            break
        end
        local dropped = PopOldest(node.buffer, 1)
        if dropped <= 0 then
            break
        end
        removed = removed + dropped
        if node.buffer.size > 0 then
            local nextHead = node.buffer.items[node.buffer.head]
            node.time = nextHead and nextHead.time or 0
            HeapPush(node)
        end
    end

    if removed > 0 then
        addon:SetSnapshotLineCount(math.max(0, currentCount - removed))
    end

    if addon.Debug then
        addon:Debug("Snapshot sync trim removed=%d remaining=%d limit=%d", removed, addon:GetSnapshotLineCount(), hardLimit)
    end
    return removed
end



function addon:ClearHistory()
    local L = addon.L
    local storage = addon.GetSnapshotStorage and addon:GetSnapshotStorage()
    if type(storage) ~= "table" then return end
    table.wipe(storage)
    addon:SetSnapshotLineCount(0)
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

    local clickEnabled = (addon.db.profile.chat.interaction and addon.db.profile.chat.interaction.clickToCopy ~= false)
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
    local restoring

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
        if restored or restoring then return end
        if not addon.db or not addon.db.enabled then return end
        if addon.Can and not addon:Can(addon.CAPABILITIES.PERSIST_CHAT_DATA) then
            return
        end
        
        local snapshotEnabled = addon:GetConfig("profile.chat.content.snapshotEnabled", true)
        if not snapshotEnabled then return end

        local perChannel = addon.GetSnapshotStorage and addon:GetSnapshotStorage()
        if type(perChannel) ~= "table" then return end
        local startTime = debugprofilestop and debugprofilestop() or nil
        local replayLimit = addon.GetEffectiveSnapshotReplayLimit and addon:GetEffectiveSnapshotReplayLimit() or GetLineCount()
        local states = {}
        local totalLines = 0
        for _, channelBuffer in pairs(perChannel) do
            if IsRingBuffer(channelBuffer) and channelBuffer.size > 0 then
                totalLines = totalLines + channelBuffer.size
                states[#states + 1] = {
                    items = channelBuffer.items,
                    index = channelBuffer.head,
                    tail = channelBuffer.tail,
                }
            end
        end
        if replayLimit <= 0 then
            restored = true
            return
        end
        if #states == 0 then
            restored = true
            if addon.Debug then
                addon:Debug("Snapshot restore skipped: no local snapshot lines")
            end
            return
        end
        local skipCount = math.max(0, totalLines - replayLimit)

        local heap = {}
        local function HeapLess(a, b)
            return ((a.line.time or 0) < (b.line.time or 0))
        end
        local function HeapPush(node)
            heap[#heap + 1] = node
            local i = #heap
            while i > 1 do
                local p = math.floor(i / 2)
                if HeapLess(heap[p], heap[i]) then
                    break
                end
                heap[i], heap[p] = heap[p], heap[i]
                i = p
            end
        end
        local function HeapPop()
            if #heap == 0 then return nil end
            local root = heap[1]
            heap[1] = heap[#heap]
            heap[#heap] = nil
            local i = 1
            while true do
                local left = i * 2
                local right = left + 1
                local smallest = i
                if left <= #heap and not HeapLess(heap[smallest], heap[left]) then
                    smallest = left
                end
                if right <= #heap and not HeapLess(heap[smallest], heap[right]) then
                    smallest = right
                end
                if smallest == i then
                    break
                end
                heap[i], heap[smallest] = heap[smallest], heap[i]
                i = smallest
            end
            return root
        end

        local function EmitLine(line)
            if not line or type(line) ~= "table" or not line.text then
                return
            end

            local frame = line.frameName and _G[line.frameName] or ChatFrame1
            if not frame or not frame.AddMessage then
                return
            end

            local visible = true
            if addon.VisibilityPolicy and addon.VisibilityPolicy.IsVisibleSnapshotLine then
                local ok, result = pcall(addon.VisibilityPolicy.IsVisibleSnapshotLine, addon.VisibilityPolicy, line, frame)
                if ok and result == false then
                    visible = false
                end
            end
            if not visible then
                return
            end

            local channelTag = addon.MessageFormatter.GetChannelTag(line)
            local authorTag = addon.MessageFormatter.GetAuthorTag(line)
            local finalText = line.text
            local contentForCopy = string.format("%s%s%s", channelTag, authorTag, finalText)
            local timestamp = FormatTimestamp(line, contentForCopy)
            local displayLine = string.format("%s%s", timestamp, contentForCopy)

            local chatTypeForColor = line.chatType
            if line.chatType == "CHANNEL" and line.channelId then
                chatTypeForColor = "CHANNEL" .. line.channelId
            end

            local r, g, b = 1, 1, 1
            if ChatTypeInfo and ChatTypeInfo[chatTypeForColor] then
                local info = ChatTypeInfo[chatTypeForColor]
                r, g, b = info.r or 1, info.g or 1, info.b or 1
            end

            local extraArgs = addon.Utils.PackArgs(r, g, b)
            if addon.Gateway and addon.Gateway.Display and addon.Gateway.Display.Transform then
                displayLine, r, g, b, extraArgs = addon.Gateway.Display:Transform(frame, displayLine, r, g, b, extraArgs)
            end
            if type(extraArgs) ~= "table" then
                extraArgs = addon.Utils.PackArgs(r, g, b)
            elseif extraArgs.n == nil then
                extraArgs.n = #extraArgs
            end
            extraArgs[1], extraArgs[2], extraArgs[3] = r, g, b

            local addMessageFn = frame._TinyChatonOrigAddMessage or frame.AddMessage
            addMessageFn(frame, displayLine, addon.Utils.UnpackArgs(extraArgs))
        end

        for _, state in ipairs(states) do
            local firstLine = state.items[state.index]
            if firstLine then
                HeapPush({ state = state, line = firstLine })
            end
        end

        restoring = true
        local BATCH_SIZE = 100
        local totalProcessed = 0
        local totalEmitted = 0
        local function ProcessBatch()
            local ok, err = pcall(function()
                local processed = 0
                while processed < BATCH_SIZE do
                    local node = HeapPop()
                    if not node then
                        restored = true
                        restoring = false
                        if addon.Debug and startTime and debugprofilestop then
                            addon:Debug("Snapshot restored lines=%d scanned=%d cost=%.2fms", totalEmitted, totalProcessed, debugprofilestop() - startTime)
                        end
                        return
                    end

                    if skipCount > 0 then
                        skipCount = skipCount - 1
                    else
                        EmitLine(node.line)
                        totalEmitted = totalEmitted + 1
                    end
                    processed = processed + 1
                    totalProcessed = totalProcessed + 1

                    node.state.index = node.state.index + 1
                    local nextLine = (node.state.index <= node.state.tail) and node.state.items[node.state.index] or nil
                    if nextLine then
                        HeapPush({ state = node.state, line = nextLine })
                    end
                end
                C_Timer.After(0, ProcessBatch)
            end)

            if not ok then
                restoring = false
                if addon.Error then
                    addon:Error("Snapshot restore failed: %s", tostring(err))
                end
            end
        end
        ProcessBatch()
    end

    if addon.RegisterEvent then
        addon:RegisterEvent("PLAYER_ENTERING_WORLD", function()
            C_Timer.After(0.1, function()
                addon:NormalizeSnapshotLimits()
                addon:SyncTrimSnapshotToLimit(addon:GetEffectiveSnapshotStorageLimit())
                RestoreChannelContent()
            end)
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
    if not self.db or not self.db.profile.chat or not self.db.profile.chat.content.snapshotChannels then
        return {}
    end
    local sc = self.db.profile.chat.content.snapshotChannels
    local items = self:GetSnapshotChannelsItems(filter)
    local selection = {}
    for _, item in ipairs(items) do
        -- 默认为选中状态（除非明确设为 false）
        selection[item.key] = (sc[item.key] ~= false)
    end
    return selection
end

function addon:SetSnapshotChannelSelection(filter, selection)
    if not self.db or not self.db.profile.chat or not self.db.profile.chat.content then
        return
    end
    if not self.db.profile.chat.content.snapshotChannels then
        self.db.profile.chat.content.snapshotChannels = {}
    end
    local sc = self.db.profile.chat.content.snapshotChannels
    local items = self:GetSnapshotChannelsItems(filter)

    for _, item in ipairs(items) do
        sc[item.key] = selection[item.key] and true or false
    end

    if addon.ApplyAllSettings then addon:ApplyAllSettings() end

    -- Trigger cleanup in case limits changed
    addon:TriggerEviction()
end

function addon:GetSnapshotChannelsSummary()
    if not self.db or not self.db.profile.chat or not self.db.profile.chat.content.snapshotChannels then
        return L["LABEL_SNAPSHOT_CHANNELS_ALL"]
    end
    local sc = self.db.profile.chat.content.snapshotChannels
    local items = self:GetSnapshotChannelsItems()
    local selected = {}
    for _, item in ipairs(items) do
        if sc[item.key] ~= false then table.insert(selected, item.label) end
    end
    if #selected >= #items then return L["LABEL_SNAPSHOT_CHANNELS_ALL"] end
    if #selected == 0 then return L["LABEL_SNAPSHOT_CHANNELS_NONE"] end
    return table.concat(selected, "、")
end

addon:RegisterModule("SnapshotManager", addon.InitSnapshotManager)
