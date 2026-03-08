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

function addon:EnableInteractionTimestamp()
    if itemRefHooked then
        return
    end
    itemRefHooked = true

    -- SetItemRef is not unhookable; keep a one-time hook and gate behavior by capability+feature.
    hooksecurefunc("SetItemRef", function(link, text, button, chatFrame)
        if not link or type(link) ~= "string" then return end

        local action, payload = link:match("^tinychat:([^:]+):(.+)$")
        if action == "prefix" and type(payload) == "string" and payload ~= "" then
            if addon.ChatLinkAdapter then
                addon.ChatLinkAdapter:Execute(payload, {
                    link = link,
                    text = text,
                    button = button,
                    chatFrame = chatFrame,
                })
            end
            return
        end

        if addon.Can and not addon:Can(addon.CAPABILITIES.MUTATE_CHAT_DISPLAY) then
            return
        end
        if addon.IsFeatureEnabled and not addon:IsFeatureEnabled("InteractionTimestamp") then
            return
        end

        local id = nil
        if action == "copy" and type(payload) == "string" and payload ~= "" then
            id = payload
        elseif link:sub(1, 10) == "tinychat:" then
            id = link:sub(11)
        end

        if type(id) == "string" and id ~= "" then
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
end

function addon:InitTimestampInteraction()
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
end

addon:RegisterModule("TimestampInteraction", addon.InitTimestampInteraction)
