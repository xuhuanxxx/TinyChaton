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
    local contentSettings = addon.db.plugin and addon.db.plugin.chat and addon.db.plugin.chat.content
    if not contentSettings or contentSettings.snapshotEnabled == false then return end

    local charKey = addon:GetCharacterKey()
    if charKey == "Default" then return end

    -- We can safely reuse ChatData parser since it only reads args
    -- But we must be careful not to modify anything
    local chatData = addon.ChatData and addon.ChatData:New(nil, event, ...)
    if not chatData then return end

    -- Ensure global DB exists
    if not addon.db.global.chatSnapshot then addon.db.global.chatSnapshot = {} end
    if not addon.db.global.chatSnapshot[charKey] then addon.db.global.chatSnapshot[charKey] = {} end

    local channelKey = addon:GetChannelKey(event, unpack(chatData.args))

    -- Check specific channel enabled
    local sc = contentSettings.snapshotChannels
    if sc then
        if sc[channelKey] == false then
            addon.ChatData:Release(chatData)
            return
        end
    end

    local perChannel = addon.db.global.chatSnapshot[charKey]
    if not perChannel[channelKey] then perChannel[channelKey] = {} end

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

    table.insert(perChannel[channelKey], {
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
    })

    -- Update global line count if tracked
    if addon.db.global.chatSnapshotLineCount then
        addon.db.global.chatSnapshotLineCount = addon.db.global.chatSnapshotLineCount + 1
    end

    -- Maintenance (Trimming)
    -- Optimized: Normally remove 1, but if limit changed drastically, remove a small batch per event
    -- This avoids freezing when limit is lowered significantly
    local maxPerChannel = contentSettings.maxPerChannel or 500
    local excess = #perChannel[channelKey] - maxPerChannel

    if excess > 0 then
        -- Remove at most 5 items per event to gradually reach the limit without stalling
        local batch = (excess > 5) and 5 or excess
        for i = 1, batch do
            table.remove(perChannel[channelKey], 1)
        end

        -- Update global count
        if addon.db.global.chatSnapshotLineCount then
            addon.db.global.chatSnapshotLineCount = math.max(0, addon.db.global.chatSnapshotLineCount - batch)
        end
    end

    -- Trigger global eviction if available and needed
    if addon.TriggerEviction and (addon.db.global.chatSnapshotLineCount or 0) > (addon.db.global.chatSnapshotMaxTotal or 5000) then
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
