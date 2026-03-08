local addonName, addon = ...

addon.messageCache = addon.messageCache or {}
addon.TimestampCopyService = addon.TimestampCopyService or {}
local Service = addon.TimestampCopyService

local function DebugLog(fmt, ...)
    if addon._chatLinkDebug ~= true then
        return
    end
    print(string.format("|cff00ffff[TinyChaton][LinkDebug]|r " .. tostring(fmt), ...))
end

local function NormalizeCopyMessage(text)
    if type(text) ~= "string" or text == "" then
        return ""
    end

    text = text:gsub("|H[^|]+|h(.-)|h", "%1")
    text = text:gsub("|T.-|t", "")
    text = text:gsub("|c%x%x%x%x%x%x%x%x", "")
    text = text:gsub("|r", "")
    text = text:gsub("||", "|")
    return text
end

function Service:Prune()
    local now = GetTime()
    local maxAge = addon.CONSTANTS.MESSAGE_CACHE_MAX_AGE or 600
    local maxCount = addon.CONSTANTS.MESSAGE_CACHE_LIMIT or 200
    local toRemove = {}
    local n = 0

    for id, entry in pairs(addon.messageCache) do
        n = n + 1
        if entry.time and (now - entry.time) > maxAge then
            toRemove[#toRemove + 1] = id
        end
    end

    for _, id in ipairs(toRemove) do
        addon.messageCache[id] = nil
        n = n - 1
    end

    if n > maxCount then
        local ordered = {}
        for id, entry in pairs(addon.messageCache) do
            ordered[#ordered + 1] = { id = id, time = entry.time or 0 }
        end
        table.sort(ordered, function(a, b) return a.time < b.time end)
        for i = 1, n - maxCount do
            addon.messageCache[ordered[i].id] = nil
        end
    end
end

function Service:BuildLink(tsText, payload, colorHex)
    if type(tsText) ~= "string" or tsText == "" then
        return nil, nil
    end

    self:Prune()
    local id = tostring(GetTime()) .. "_" .. tostring(math.random(10000, 99999))
    local color = type(colorHex) == "string" and colorHex ~= "" and colorHex or "FFFFFFFF"
    local normalizedPayload = NormalizeCopyMessage(payload or (tsText .. " "))

    addon.messageCache[id] = {
        msg = normalizedPayload,
        time = GetTime(),
    }

    DebugLog("timestamp injected id=%s ts=%s", tostring(id), tostring(tsText))
    return string.format("|c%s|Htinychat:copy:%s|h%s|h|r ", color, id, tsText), id
end

function Service:Resolve(copyId)
    if type(copyId) ~= "string" or copyId == "" then
        DebugLog("copy resolve aborted: invalid id")
        return nil
    end

    local entry = addon.messageCache[copyId]
    if not (type(entry) == "table" and type(entry.msg) == "string") then
        DebugLog("copy resolve cache miss id=%s", tostring(copyId))
        return nil
    end

    DebugLog("copy resolve hit id=%s", tostring(copyId))
    return entry.msg
end

function Service:OpenChatWithPayload(copyId)
    local payload = self:Resolve(copyId)
    if type(payload) ~= "string" or payload == "" then
        return false
    end

    local editBox = ChatEdit_ChooseBoxForSend and ChatEdit_ChooseBoxForSend() or nil
    if not editBox then
        DebugLog("copy open aborted: no edit box id=%s", tostring(copyId))
        return false
    end

    if ChatEdit_ActivateChat and not editBox:HasFocus() then
        ChatEdit_ActivateChat(editBox)
    end
    editBox:SetText(payload)
    DebugLog("copy open success id=%s text=%s", tostring(copyId), tostring(payload))
    return true
end

function addon:CreateClickableTimestamp(tsText, copyMsg, tsColor)
    return Service:BuildLink(tsText, copyMsg, tsColor)
end

function addon:HandleTimestampCopyLink(id)
    return Service:OpenChatWithPayload(id)
end

function addon:InitTimestampCopyService()
end

addon:RegisterModule("TimestampCopyService", addon.InitTimestampCopyService)
