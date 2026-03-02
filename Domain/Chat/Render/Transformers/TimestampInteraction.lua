local addonName, addon = ...

addon.messageCache = addon.messageCache or {}
addon.InteractionTimestamp = addon.InteractionTimestamp or {}
local itemRefHooked = false

local function PruneCache()
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

function addon:CreateClickableTimestamp(tsText, copyMsg, tsColor)
    local interaction = self.db and self.db.profile and self.db.profile.chat and self.db.profile.chat.interaction
    local clickEnabled = interaction and (interaction.clickToCopy ~= false) or false

    local color = tsColor or "FFFFFFFF"

    if not clickEnabled then
        -- Static timestamp with color reset to let message keep original color
        return string.format("|c%s%s|r ", color, tsText), nil
    end

    PruneCache()
    local id = tostring(GetTime()) .. "_" .. tostring(math.random(10000, 99999))

    -- Format: |cTimestampColor|Timestamp|h|r
    -- The |r at the end resets color so message keeps original color
    local linkified = string.format("|c%s|Htinychat:copy:%s|h%s|h|r ", color, id, tsText)

    self.messageCache[id] = { msg = copyMsg or (tsText .. " "), time = GetTime() }

    return linkified, id
end

local function InteractionTimestampTransformer(frame, text, r, g, b, extraArgs)
    if not addon.db or not addon.db.enabled then return text, r, g, b, extraArgs end
    if type(text) ~= "string" or text == "" then return text, r, g, b, extraArgs end

    -- Skip if already processed
    if text:find("|Htinychat:copy:") then return text, r, g, b, extraArgs end

    -- Match timestamp at start: [HH:MM] or [HH:MM:SS]
    local _, finish, ts = text:find("^(%[?%d+:%d+:?%d*%]?)")

    if not ts or not ts:find("%d+:%d+") then
        return text, r, g, b, extraArgs
    end

    -- Check for trailing |r (color reset)
    if text:sub(finish + 1, finish + 2) == "|r" then
        ts = ts .. "|r"
        finish = finish + 2
    end

    -- Get the rest of the message
    local rest = text:sub(finish + 1)
    local needsSpace = rest:sub(1, 1) ~= " "

    -- Keep timestamp color consistent with formatter rules.
    local color = addon.MessageFormatter.ResolveTimestampColor({r = r, g = g, b = b})
    local linkified = addon:CreateClickableTimestamp(ts, ts .. (needsSpace and " " or "") .. rest, color)

    return linkified .. rest, r, g, b, extraArgs
end

function addon:EnableInteractionTimestamp()
    self:RegisterChatFrameTransformer("interaction_timestamp", InteractionTimestampTransformer)

    if itemRefHooked then
        return
    end
    itemRefHooked = true

    -- SetItemRef is not unhookable; keep a one-time hook and gate behavior by capability+feature.
    hooksecurefunc("SetItemRef", function(link, text, button, chatFrame)
        if addon.Can and not addon:Can(addon.CAPABILITIES.MUTATE_CHAT_DISPLAY) then
            return
        end
        if addon.IsFeatureEnabled and not addon:IsFeatureEnabled("InteractionTimestamp") then
            return
        end
        if not link or type(link) ~= "string" then return end

        local id = link:match("^tinychat:copy:(.+)$")
        if not id and link:sub(1, 10) == "tinychat:" then
            id = link:sub(11)
        end

        if id then
            local entry = addon.messageCache[id]
            if entry and entry.msg then
                local editBox = ChatEdit_ChooseBoxForSend()
                if not editBox:HasFocus() then ChatEdit_ActivateChat(editBox) end
                editBox:SetText(entry.msg)
            end
        end
    end)
end

function addon:DisableInteractionTimestamp()
    addon.chatFrameTransformers["interaction_timestamp"] = nil
end

function addon:InitTimestampInteraction()
    if addon.RegisterFeature then
        addon:RegisterFeature("InteractionTimestamp", {
            requires = { "MUTATE_CHAT_DISPLAY" },
            plane = addon.RUNTIME_PLANES and addon.RUNTIME_PLANES.CHAT_DATA or "CHAT_DATA",
            onEnable = function()
                addon:EnableInteractionTimestamp()
            end,
            onDisable = function()
                addon:DisableInteractionTimestamp()
            end,
        })
    else
        addon:EnableInteractionTimestamp()
    end
end

addon:RegisterModule("TimestampInteraction", addon.InitTimestampInteraction)
