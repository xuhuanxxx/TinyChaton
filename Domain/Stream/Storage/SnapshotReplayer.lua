local addonName, addon = ...
local L = addon.L

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
    for _, streamBuffer in pairs(storage) do
        if IsRingBuffer(streamBuffer) then
            total = total + streamBuffer.size
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

    for streamKey, streamBuffer in pairs(content) do
        if removedCount >= CLEANUP_BATCH_SIZE then break end
        if IsRingBuffer(streamBuffer) and streamBuffer.size > 0 then
            local canRemove = math.min(streamBuffer.size, CLEANUP_BATCH_SIZE - removedCount)
            local removed = PopOldest(streamBuffer, canRemove)
            removedCount = removedCount + removed
        elseif type(streamBuffer) == "table" then
            -- Corrupted entry: drop it to keep eviction loop healthy.
            content[streamKey] = nil
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

    for streamKey, streamBuffer in pairs(storage) do
        if IsRingBuffer(streamBuffer) and streamBuffer.size > 0 then
            local first = streamBuffer.items[streamBuffer.head]
            HeapPush({
                streamKey = streamKey,
                buffer = streamBuffer,
                time = first and first.time or 0,
            })
        elseif type(streamBuffer) == "table" then
            storage[streamKey] = nil
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

function addon:InitSnapshotManager()
    local L = addon.L
    local restored
    local restoring

    local function RestoreStreamContent()
        if restored or restoring then return end
        if not addon.db or not addon.db.enabled then return end
        if addon.Can and not addon:Can(addon.CAPABILITIES.PERSIST_CHAT_DATA) then
            return
        end
        
        local snapshotEnabled = addon:GetConfig("profile.chat.content.snapshotEnabled", true)
        if not snapshotEnabled then return end

        local perStream = addon.GetSnapshotStorage and addon:GetSnapshotStorage()
        if type(perStream) ~= "table" then return end
        local startTime = debugprofilestop and debugprofilestop() or nil
        local replayLimit = addon.GetEffectiveSnapshotReplayLimit and addon:GetEffectiveSnapshotReplayLimit() or GetLineCount()
        local states = {}
        local totalLines = 0
        for _, streamBuffer in pairs(perStream) do
            if IsRingBuffer(streamBuffer) and streamBuffer.size > 0 then
                totalLines = totalLines + streamBuffer.size
                states[#states + 1] = {
                    items = streamBuffer.items,
                    index = streamBuffer.head,
                    tail = streamBuffer.tail,
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
            if addon.StreamVisibilityService and addon.StreamVisibilityService.IsVisibleSnapshotLine then
                local ok, result = pcall(addon.StreamVisibilityService.IsVisibleSnapshotLine, addon.StreamVisibilityService, line, frame)
                if ok and result == false then
                    visible = false
                end
            end
            if not visible then
                return
            end

            addon:EmitRenderedChatLine(line, frame, { preferTimestampConfig = true })
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
                RestoreStreamContent()
            end)
        end)
    end
end

-- ============================================
-- Snapshot Configuration Helpers
-- ============================================

local function IsStreamInFilter(stream, filter)
    if type(stream) ~= "table" then
        return false
    end
    local group = addon:GetStreamGroup(stream.key)
    local kind = addon:GetStreamKind(stream.key)
    if filter == "private" then
        return group == "private"
    end
    if filter == "system" then
        return kind == "channel" and group == "system"
    end
    if filter == "dynamic" then
        return kind == "channel" and group == "dynamic"
    end
    if filter == "notice" then
        return kind == "notice"
    end
    return (filter == nil)
end

local function BuildStreamItems(filter, includePredicate)
    local items = {}
    for _, stream in addon:IterateCompiledStreams() do
        if includePredicate(stream) and IsStreamInFilter(stream, filter) then
            local identity = addon.ResolveStreamIdentity and addon:ResolveStreamIdentity(stream, {}) or nil
            table.insert(items, {
                key = stream.key,
                label = (identity and identity.label) or stream.key,
                value = stream.key,  -- for MultiDropdown compatibility
                text = (identity and identity.label) or stream.key,
            })
        end
    end

    return items
end

function addon:GetSnapshotStreamsItems(filter)
    -- filter: "private" | "system" | "dynamic" | "notice" | nil(全部)
    return BuildStreamItems(filter, function(stream)
        return not stream.isNotStorable
    end)
end

function addon:GetSnapshotStreamSelection(filter)
    local sc = self.db
        and self.db.profile
        and self.db.profile.chat
        and self.db.profile.chat.content
        and self.db.profile.chat.content.snapshotStreams
    local items = self:GetSnapshotStreamsItems(filter)
    local selection = {}
    for _, item in ipairs(items) do
        selection[item.key] = addon:ResolveStreamToggle(item.key, sc, "snapshotDefault", true)
    end
    return selection
end

function addon:SetSnapshotStreamSelection(filter, selection, opts)
    if not self.db or not self.db.profile.chat or not self.db.profile.chat.content then
        return
    end
    if not self.db.profile.chat.content.snapshotStreams then
        self.db.profile.chat.content.snapshotStreams = {}
    end
    local sc = self.db.profile.chat.content.snapshotStreams
    local items = self:GetSnapshotStreamsItems(filter)

    for _, item in ipairs(items) do
        sc[item.key] = selection[item.key] and true or false
    end

    if not (opts and opts.skipApply) and addon.ApplyAllSettings then
        addon:ApplyAllSettings()
    end

    -- Trigger cleanup in case limits changed
    addon:TriggerEviction()
end

function addon:GetSnapshotStreamsSummary()
    if not self.db or not self.db.profile.chat or not self.db.profile.chat.content.snapshotStreams then
        return L["LABEL_SNAPSHOT_CHANNELS_ALL"]
    end
    local sc = self.db.profile.chat.content.snapshotStreams
    local items = self:GetSnapshotStreamsItems()
    local selected = {}
    for _, item in ipairs(items) do
        if sc[item.key] ~= false then table.insert(selected, item.label) end
    end
    if #selected >= #items then return L["LABEL_SNAPSHOT_CHANNELS_ALL"] end
    if #selected == 0 then return L["LABEL_SNAPSHOT_CHANNELS_NONE"] end
    return table.concat(selected, "、")
end

function addon:GetCopyStreamsItems(filter)
    -- filter: "private" | "system" | "dynamic" | "notice" | nil(全部)
    return BuildStreamItems(filter, function(stream)
        return addon:GetStreamCapabilities(stream.key) ~= nil
    end)
end

function addon:GetCopyStreamSelection(filter)
    local interaction = self.db and self.db.profile and self.db.profile.chat and self.db.profile.chat.interaction
    local configured = interaction and interaction.copyStreams or nil
    local items = self:GetCopyStreamsItems(filter)
    local selection = {}
    for _, item in ipairs(items) do
        selection[item.key] = addon:ResolveStreamToggle(item.key, configured, "copyDefault", true)
    end
    return selection
end

function addon:SetCopyStreamSelection(filter, selection, opts)
    if not self.db or not self.db.profile or not self.db.profile.chat or not self.db.profile.chat.interaction then
        return
    end

    local interaction = self.db.profile.chat.interaction
    if type(interaction.copyStreams) ~= "table" then
        interaction.copyStreams = {}
    end

    local copyStreams = interaction.copyStreams
    local items = self:GetCopyStreamsItems(filter)
    for _, item in ipairs(items) do
        copyStreams[item.key] = selection[item.key] and true or false
    end

    if not (opts and opts.skipApply) and addon.ApplyAllSettings then
        addon:ApplyAllSettings()
    end
end

function addon:GetCopyStreamsSummary()
    local interaction = self.db and self.db.profile and self.db.profile.chat and self.db.profile.chat.interaction
    if not interaction then
        return L["LABEL_SNAPSHOT_CHANNELS_ALL"]
    end

    local configured = interaction.copyStreams
    local items = self:GetCopyStreamsItems()
    local selected = {}
    for _, item in ipairs(items) do
        local enabled = addon:ResolveStreamToggle(item.key, configured, "copyDefault", true)
        if enabled then
            table.insert(selected, item.label)
        end
    end

    if #selected >= #items then return L["LABEL_SNAPSHOT_CHANNELS_ALL"] end
    if #selected == 0 then return L["LABEL_SNAPSHOT_CHANNELS_NONE"] end
    return table.concat(selected, "、")
end

addon:RegisterModule("SnapshotManager", addon.InitSnapshotManager)
