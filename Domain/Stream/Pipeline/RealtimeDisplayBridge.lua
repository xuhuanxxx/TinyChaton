local addonName, addon = ...

addon.RealtimeDisplayBridge = addon.RealtimeDisplayBridge or {}
local Bridge = addon.RealtimeDisplayBridge

local TTL_SECONDS = 2
local MAX_PENDING_PER_FRAME = 128

local pendingByFrame = {}

local function GetNow()
    return GetTime and GetTime() or time()
end

local function GetFrameKey(frame)
    if type(frame) ~= "table" then
        return nil
    end
    if addon.FrameResolver and type(addon.FrameResolver.GetFrameName) == "function" then
        local name = addon.FrameResolver:GetFrameName(frame)
        if type(name) == "string" and name ~= "" then
            return name
        end
    end
    return tostring(frame)
end

local function EnsureBucket(frame)
    local key = GetFrameKey(frame)
    if not key then
        return nil
    end

    local bucket = pendingByFrame[key]
    if type(bucket) ~= "table" then
        bucket = {
            items = {},
            byLineId = {},
        }
        pendingByFrame[key] = bucket
    end
    return bucket
end

local function Prune(bucket)
    local now = GetNow()
    local kept = {}
    local byLineId = {}

    for _, item in ipairs(bucket.items) do
        if (now - (item.createdAt or 0)) <= TTL_SECONDS then
            kept[#kept + 1] = item
            if item.lineId ~= nil then
                byLineId[tostring(item.lineId)] = item
            end
        end
    end

    while #kept > MAX_PENDING_PER_FRAME do
        table.remove(kept, 1)
    end

    for _, item in ipairs(kept) do
        if item.lineId ~= nil then
            byLineId[tostring(item.lineId)] = item
        end
    end

    bucket.items = kept
    bucket.byLineId = byLineId
end

local function RemoveItem(bucket, item)
    if not bucket or not item then
        return
    end

    for i = #bucket.items, 1, -1 do
        if bucket.items[i] == item then
            table.remove(bucket.items, i)
            break
        end
    end

    if item.lineId ~= nil then
        bucket.byLineId[tostring(item.lineId)] = nil
    end
end

local function TryFindByLineId(bucket, lineId)
    if lineId == nil then
        return nil
    end
    return bucket.byLineId[tostring(lineId)]
end

local function TryExtractAuthorAndBody(msg)
    if type(msg) ~= "string" or msg == "" then
        return nil, nil
    end

    local startPos, endPos, author = msg:find("|Hplayer:([^|]+)|h%[[^%]]+%]|h")
    if not startPos then
        return nil, nil
    end

    local separator = addon.L and addon.L["CHAT_MESSAGE_SEPARATOR"] or ":"
    local bodyStart = endPos + 1
    if msg:sub(bodyStart, bodyStart + #separator - 1) == separator then
        bodyStart = bodyStart + #separator
    end
    if msg:sub(bodyStart, bodyStart) == " " then
        bodyStart = bodyStart + 1
    end

    return author, msg:sub(bodyStart)
end

local function TryFindByAuthorAndText(bucket, msg)
    local author, body = TryExtractAuthorAndBody(msg)
    if type(author) ~= "string" or type(body) ~= "string" then
        return nil
    end

    for _, item in ipairs(bucket.items) do
        local envelope = item.envelope
        if type(envelope) == "table"
            and envelope.author == author
            and envelope.rawText == body then
            return item
        end
    end

    return nil
end

function Bridge:Push(frame, envelope)
    if type(envelope) ~= "table" then
        return false
    end

    local bucket = EnsureBucket(frame)
    if not bucket then
        return false
    end

    Prune(bucket)

    local item = {
        createdAt = GetNow(),
        lineId = envelope.lineId,
        envelope = envelope,
    }
    bucket.items[#bucket.items + 1] = item

    if envelope.lineId ~= nil then
        bucket.byLineId[tostring(envelope.lineId)] = item
    end

    Prune(bucket)
    return true
end

function Bridge:Consume(frame, msg, lineId)
    local bucket = EnsureBucket(frame)
    if not bucket then
        return nil
    end

    Prune(bucket)

    local item = TryFindByLineId(bucket, lineId)
    if not item then
        item = TryFindByAuthorAndText(bucket, msg)
    end

    if not item and #bucket.items > 0 then
        item = bucket.items[1]
    end

    if not item then
        return nil
    end

    RemoveItem(bucket, item)
    return item.envelope
end

return Bridge
