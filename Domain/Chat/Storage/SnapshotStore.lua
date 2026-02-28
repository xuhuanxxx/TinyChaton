local addonName, addon = ...
local CF = _G["Create" .. "Frame"]

-- =========================================================================
-- Middleware: SnapshotLogger
-- Stage: LOG
-- Priority: 10
-- Description: Records message to history (Snapshot)
-- =========================================================================

-- Runs FIRST in LOG stage to capture text *before* Display timestamps are added

-- Standalone Frame for safe logging (Observer Pattern)
-- Decoupled from EventDispatcher to prevent Taint in combat
local loggerFrame = CF("Frame")
local loggerEnabled = false

local function IsRingBuffer(buffer)
    return type(buffer) == "table"
        and type(buffer.items) == "table"
        and type(buffer.head) == "number"
        and type(buffer.tail) == "number"
        and type(buffer.size) == "number"
end

local function CreateRingBuffer()
    return {
        head = 1,
        tail = 0,
        size = 0,
        items = {},
    }
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

local function PushRingBuffer(buffer, value)
    buffer.tail = buffer.tail + 1
    buffer.items[buffer.tail] = value
    buffer.size = buffer.size + 1
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

local function EnsureCharSnapshotDB()
    if type(TinyChatonCharDB) ~= "table" then
        TinyChatonCharDB = {}
    end
    if type(TinyChatonCharDB.snapshot) ~= "table" then
        TinyChatonCharDB.snapshot = {}
    end
    if type(TinyChatonCharDB.settings) ~= "table" then
        TinyChatonCharDB.settings = {}
    end
    if TinyChatonCharDB.lineCount ~= nil and type(TinyChatonCharDB.lineCount) ~= "number" then
        TinyChatonCharDB.lineCount = nil
    end
    return TinyChatonCharDB
end

local function CountTotalStoredLines(storage)
    local total = 0
    for _, channelBuffer in pairs(storage) do
        if IsRingBuffer(channelBuffer) then
            total = total + channelBuffer.size
        end
    end
    return total
end

function addon:GetSnapshotStorage()
    local db = EnsureCharSnapshotDB()
    return db.snapshot
end

function addon:GetSnapshotLineCount()
    local db = EnsureCharSnapshotDB()
    if db.lineCount == nil then
        db.lineCount = CountTotalStoredLines(db.snapshot)
    end
    return db.lineCount
end

function addon:GetSnapshotLimitsSettings()
    local db = EnsureCharSnapshotDB()
    return db.settings
end

local function ClampLimit(value, minValue, maxValue, fallback)
    local n = tonumber(value) or fallback
    n = math.floor(n + 0.5)
    if n < minValue then n = minValue end
    if n > maxValue then n = maxValue end
    return n
end

function addon:SetSnapshotStorageOverrideEnabled(enabled)
    local settings = self:GetSnapshotLimitsSettings()
    settings.snapshotStorageOverrideEnabled = enabled == true
end

function addon:SetSnapshotStorageOverrideValue(value)
    local settings = self:GetSnapshotLimitsSettings()
    local n = tonumber(value)
    if n == nil then
        settings.snapshotStorageOverrideValue = nil
        return
    end
    local c = self.CONSTANTS
    local minValue = (c and c.SNAPSHOT_STORAGE_MAX_MIN) or 1
    local maxValue = (c and c.SNAPSHOT_STORAGE_MAX_MAX) or 100000
    local fallback = (c and c.SNAPSHOT_STORAGE_MAX_DEFAULT) or 5000
    settings.snapshotStorageOverrideValue = ClampLimit(n, minValue, maxValue, fallback)
end

function addon:SetSnapshotReplayOverrideEnabled(enabled)
    local settings = self:GetSnapshotLimitsSettings()
    settings.snapshotReplayOverrideEnabled = enabled == true
end

function addon:SetSnapshotReplayOverrideValue(value)
    local settings = self:GetSnapshotLimitsSettings()
    local n = tonumber(value)
    if n == nil then
        settings.snapshotReplayOverrideValue = nil
        return
    end
    local c = self.CONSTANTS
    local minValue = (c and c.SNAPSHOT_REPLAY_MAX_MIN) or 1
    local maxValue = (c and c.SNAPSHOT_REPLAY_MAX_MAX) or 100000
    local fallback = (c and c.SNAPSHOT_REPLAY_MAX_DEFAULT) or 1000
    settings.snapshotReplayOverrideValue = ClampLimit(n, minValue, maxValue, fallback)
end

function addon:GetEffectiveSnapshotStorageLimit()
    local c = self.CONSTANTS
    local defaultValue = (c and c.SNAPSHOT_STORAGE_MAX_DEFAULT) or 5000
    local minValue = (c and c.SNAPSHOT_STORAGE_MAX_MIN) or 1
    local maxValue = (c and c.SNAPSHOT_STORAGE_MAX_MAX) or 100000

    local settings = self:GetSnapshotLimitsSettings()
    local useOverride = settings.snapshotStorageOverrideEnabled == true
    local overrideValue = tonumber(settings.snapshotStorageOverrideValue)

    local effective = tonumber(self.db and self.db.account and self.db.account.chatSnapshotStorageDefaultMax) or defaultValue
    if useOverride and overrideValue then
        effective = overrideValue
    end

    effective = ClampLimit(effective, minValue, maxValue, defaultValue)
    return effective
end

function addon:GetEffectiveSnapshotReplayLimit()
    local c = self.CONSTANTS
    local defaultValue = (c and c.SNAPSHOT_REPLAY_MAX_DEFAULT) or 1000
    local minValue = (c and c.SNAPSHOT_REPLAY_MAX_MIN) or 1
    local maxValue = (c and c.SNAPSHOT_REPLAY_MAX_MAX) or 100000

    local settings = self:GetSnapshotLimitsSettings()
    local useOverride = settings.snapshotReplayOverrideEnabled == true
    local overrideValue = tonumber(settings.snapshotReplayOverrideValue)

    local effective = tonumber(self.db and self.db.account and self.db.account.chatSnapshotReplayDefaultMax) or defaultValue
    if useOverride and overrideValue then
        effective = overrideValue
    end

    effective = ClampLimit(effective, minValue, maxValue, defaultValue)
    local storageLimit = self:GetEffectiveSnapshotStorageLimit()
    if effective > storageLimit then
        effective = storageLimit
    end
    return effective
end

function addon:NormalizeSnapshotLimits()
    local replay = self:GetEffectiveSnapshotReplayLimit()
    local storage = self:GetEffectiveSnapshotStorageLimit()
    if replay > storage then
        replay = storage
    end

    local settings = self:GetSnapshotLimitsSettings()
    if settings.snapshotReplayOverrideEnabled == true then
        settings.snapshotReplayOverrideValue = replay
    elseif self.db and self.db.account then
        self.db.account.chatSnapshotReplayDefaultMax = replay
    end
    return storage, replay
end

-- Backward aliases kept temporarily for intra-repo references.
addon.GetSnapshotSettings = addon.GetSnapshotLimitsSettings
addon.GetSnapshotEffectiveMaxTotal = addon.GetEffectiveSnapshotStorageLimit
addon.SetSnapshotOverrideEnabled = addon.SetSnapshotStorageOverrideEnabled
addon.SetSnapshotOverrideValue = addon.SetSnapshotStorageOverrideValue

function addon:SetSnapshotLineCount(value)
    local db = EnsureCharSnapshotDB()
    local n = tonumber(value) or 0
    if n < 0 then n = 0 end
    db.lineCount = math.floor(n)
end

function addon:AdjustSnapshotLineCount(delta)
    local current = self:GetSnapshotLineCount()
    self:SetSnapshotLineCount(current + (tonumber(delta) or 0))
end

local function OnSnapshotEvent(self, event, ...)
    if addon.Can then
        -- Belt-and-suspenders: FeatureRegistry should already unregister this listener
        -- when capabilities are disabled, but keep runtime guard for async/drift safety.
        if not addon:Can(addon.CAPABILITIES.READ_CHAT_EVENT) then
            return
        end
        if not addon:Can(addon.CAPABILITIES.PERSIST_CHAT_DATA) then
            return
        end
    end

    if not addon.db or not addon.db.enabled then return end

    -- Check if snapshot enabled
    local contentSettings = addon.db.profile and addon.db.profile.chat and addon.db.profile.chat.content
    if not contentSettings or contentSettings.snapshotEnabled == false then return end

    -- We can safely reuse ChatData parser since it only reads args
    -- But we must be careful not to modify anything
    local chatData = addon.ChatData and addon.ChatData:New(nil, event, ...)
    if not chatData then return end

    local perChannel = addon:GetSnapshotStorage()

    local args = chatData.args
    local channelKey = addon:GetChannelKey(event, addon.Utils.UnpackArgs(args))

    -- Check specific channel enabled
    local sc = contentSettings.snapshotChannels
    if sc then
        if sc[channelKey] == false then
            addon.ChatData:Release(chatData)
            return
        end
    end

    if not perChannel[channelKey] then
        perChannel[channelKey] = CreateRingBuffer()
    end
    local channelBuffer = perChannel[channelKey]
    if not IsRingBuffer(channelBuffer) then
        addon.ChatData:Release(chatData)
        return
    end

    -- Capture data
    local chatType = addon.EVENT_TO_CHANNEL_KEY[event] or "CHANNEL"
    local channelId, channelBaseName
    if event == "CHAT_MSG_CHANNEL" then
        channelId = chatData.channelNumber
        channelBaseName = chatData.channelName
    end

    -- Extract Class Color info from GUID (arg 12)
    local guid = chatData.args[12]
    local classFilename
    if guid then
        _, classFilename = GetPlayerInfoByGUID(guid)
    end

    local record = {
        text = chatData.text,
        author = chatData.author,
        channelKey = channelKey,
        chatType = chatType,
        channelId = channelId,
        channelBaseName = channelBaseName,
        time = time(),
        classFilename = classFilename,
        -- frameName is less relevant in background logging, nil is fine
        frameName = nil
    }
    if addon.ValidateContract then
        addon:ValidateContract("SnapshotRecord", record)
    end
    PushRingBuffer(channelBuffer, record)

    addon:AdjustSnapshotLineCount(1)

    -- Maintenance (Trimming)
    -- Optimized: Normally remove 1, but if limit changed drastically, remove a small batch per event
    -- This avoids freezing when limit is lowered significantly
    local maxPerChannel = contentSettings.maxPerChannel or 500
    local excess = channelBuffer.size - maxPerChannel

    if excess > 0 then
        local batch = (excess > 5) and 5 or excess
        local removed = PopOldest(channelBuffer, batch)

        addon:AdjustSnapshotLineCount(-removed)
    end

    -- Trigger global eviction if available and needed
    if addon.TriggerEviction and addon:GetSnapshotLineCount() > addon:GetEffectiveSnapshotStorageLimit() then
        addon:TriggerEviction()
    end
    
    addon.ChatData:Release(chatData)
end

loggerFrame:SetScript("OnEvent", OnSnapshotEvent)

local function RegisterSnapshotEvents()
    if loggerEnabled then return end
    for event in pairs(addon.EVENT_TO_CHANNEL_KEY) do
        loggerFrame:RegisterEvent(event)
    end
    loggerFrame:RegisterEvent("CHAT_MSG_CHANNEL")
    loggerEnabled = true
end

local function UnregisterSnapshotEvents()
    if not loggerEnabled then return end
    for event in pairs(addon.EVENT_TO_CHANNEL_KEY) do
        loggerFrame:UnregisterEvent(event)
    end
    loggerFrame:UnregisterEvent("CHAT_MSG_CHANNEL")
    loggerEnabled = false
end

if addon.RegisterFeature then
    addon:RegisterFeature("SnapshotLogger", {
        requires = { "READ_CHAT_EVENT", "PERSIST_CHAT_DATA" },
        onEnable = RegisterSnapshotEvents,
        onDisable = UnregisterSnapshotEvents,
    })
else
    -- Fallback for older load orders
    RegisterSnapshotEvents()
end
