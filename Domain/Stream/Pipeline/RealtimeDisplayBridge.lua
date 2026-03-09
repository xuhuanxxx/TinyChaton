local addonName, addon = ...

addon.RealtimeDisplayBridge = addon.RealtimeDisplayBridge or {}
local Bridge = addon.RealtimeDisplayBridge

local TTL_SECONDS = 2
local MAX_PENDING_PER_FRAME = 128

Bridge.pendingByFrame = Bridge.pendingByFrame or {}
Bridge.hookedFrames = Bridge.hookedFrames or {}
Bridge.stats = Bridge.stats or {
    pushed = 0,
    consumedByLineId = 0,
    consumedByFallback = 0,
    consumedByQueue = 0,
    missed = 0,
    pruned = 0,
}

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

local function ResolveLineId(...)
    local packed = addon.Utils and addon.Utils.PackArgs and addon.Utils.PackArgs(...) or { ... }
    for i = 1, packed.n or #packed do
        local value = packed[i]
        if type(value) == "number" then
            return value
        end
    end
    return nil
end

local function EnsureBucket(self, frame)
    local key = GetFrameKey(frame)
    if not key then
        return nil
    end

    local bucket = self.pendingByFrame[key]
    if type(bucket) ~= "table" then
        bucket = {
            items = {},
            byLineId = {},
        }
        self.pendingByFrame[key] = bucket
    end

    return bucket
end

local function ReindexLineIds(bucket)
    local byLineId = {}
    for _, item in ipairs(bucket.items) do
        if item.lineId ~= nil then
            byLineId[tostring(item.lineId)] = item
        end
    end
    bucket.byLineId = byLineId
end

local function Prune(self, bucket)
    local now = GetNow()
    local kept = {}

    for _, item in ipairs(bucket.items) do
        if (now - (item.createdAt or 0)) <= TTL_SECONDS then
            kept[#kept + 1] = item
        else
            self.stats.pruned = self.stats.pruned + 1
        end
    end

    local overflow = #kept - MAX_PENDING_PER_FRAME
    if overflow > 0 then
        for _ = 1, overflow do
            table.remove(kept, 1)
            self.stats.pruned = self.stats.pruned + 1
        end
    end

    bucket.items = kept
    ReindexLineIds(bucket)
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

local function ConsumeMessage(self, frame, msg, lineId)
    local bucket = EnsureBucket(self, frame)
    if not bucket then
        return nil
    end

    Prune(self, bucket)

    local matched = nil
    if lineId ~= nil then
        matched = bucket.byLineId[tostring(lineId)]
        if matched then
            self.stats.consumedByLineId = self.stats.consumedByLineId + 1
        end
    end

    if not matched then
        local author, body = TryExtractAuthorAndBody(msg)
        if type(author) == "string" and type(body) == "string" then
            for _, item in ipairs(bucket.items) do
                local message = item.message
                if type(message) == "table" and message.author == author and message.rawText == body then
                    matched = item
                    self.stats.consumedByFallback = self.stats.consumedByFallback + 1
                    break
                end
            end
        end
    end

    if not matched and #bucket.items > 0 then
        matched = bucket.items[1]
        self.stats.consumedByQueue = self.stats.consumedByQueue + 1
    end

    if not matched then
        self.stats.missed = self.stats.missed + 1
        return nil
    end

    RemoveItem(bucket, matched)
    return matched.message
end

function Bridge:EnsureHook(frame)
    if type(frame) ~= "table" or type(frame.AddMessage) ~= "function" then
        return false
    end

    local key = GetFrameKey(frame)
    if self.hookedFrames[key] then
        return true
    end

    local origAddMessage = frame.AddMessage
    frame._TinyChatonOrigAddMessage = frame._TinyChatonOrigAddMessage or origAddMessage
    frame._TinyChatonHookedAddMessage = true

    frame.AddMessage = function(targetFrame, msg, ...)
        if targetFrame._TinyChatonInAddMessageHook then
            return origAddMessage(targetFrame, msg, ...)
        end

        targetFrame._TinyChatonInAddMessageHook = true
        local finalMsg = msg

        local lineId = ResolveLineId(...)
        local message = ConsumeMessage(Bridge, targetFrame, msg, lineId)
        if type(message) == "table" and addon.DisplayPipeline and addon.DisplayPipeline.Render then
            local rendered = addon.DisplayPipeline:Render(targetFrame, message)
            if type(rendered) == "table" and type(rendered.displayText) == "string" then
                finalMsg = rendered.displayText
            end
        end

        local ok, result = pcall(origAddMessage, targetFrame, finalMsg, ...)
        targetFrame._TinyChatonInAddMessageHook = nil
        if not ok then
            error(result)
        end
        return result
    end

    self.hookedFrames[key] = true
    return true
end

function Bridge:Register(frame, message)
    if type(message) ~= "table" then
        return false
    end
    if addon.ValidateContract then
        addon:ValidateContract("DisplayMessage", message)
    end

    local bucket = EnsureBucket(self, frame)
    if not bucket then
        return false
    end

    Prune(self, bucket)

    local item = {
        createdAt = GetNow(),
        lineId = message.lineId,
        message = message,
    }
    bucket.items[#bucket.items + 1] = item
    if message.lineId ~= nil then
        bucket.byLineId[tostring(message.lineId)] = item
    end

    self.stats.pushed = self.stats.pushed + 1
    Prune(self, bucket)

    return self:EnsureHook(frame)
end

function Bridge:GetStats()
    return {
        pushed = self.stats.pushed,
        consumedByLineId = self.stats.consumedByLineId,
        consumedByFallback = self.stats.consumedByFallback,
        consumedByQueue = self.stats.consumedByQueue,
        missed = self.stats.missed,
        pruned = self.stats.pruned,
    }
end

return Bridge
