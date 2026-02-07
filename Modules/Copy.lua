local addonName, addon = ...
local L = addon.L

addon.messageCache = addon.messageCache or {}

local function PruneMessageCache()
    local cache = addon.messageCache
    local maxAge = addon.MESSAGE_CACHE_MAX_AGE or 600
    local maxCount = addon.COPY_MESSAGE_LIMIT or 200
    local now = GetTime()
    local toRemove = {}
    local n = 0
    for id, entry in pairs(cache) do
        n = n + 1
        local age = entry and type(entry) == "table" and entry.time and (now - entry.time) or 0
        if age > maxAge then
            toRemove[#toRemove + 1] = id
        end
    end
    for _, id in ipairs(toRemove) do
        cache[id] = nil
        n = n - 1
    end
    if n > maxCount then
        local ordered = {}
        for id, entry in pairs(cache) do
            local t = entry and type(entry) == "table" and entry.time or 0
            ordered[#ordered + 1] = { id = id, time = t }
        end
        table.sort(ordered, function(a, b) return a.time < b.time end)
        for i = 1, n - maxCount do
            local item = ordered[i]
            if item then cache[item.id] = nil end
        end
    end
end

local function GetTimestampPrefix()
    if not addon.db or not addon.db.plugin.chat or not addon.db.plugin.chat.interaction or not addon.db.plugin.chat.interaction.timestampEnabled then return nil end
    local fmt = addon.db.plugin.chat.interaction.timestampFormat
    if not fmt or fmt == "" then return nil end
    local tsColor = addon.db.plugin.chat.interaction.timestampColor or "FF888888"
    local ts = date(fmt)
    
    -- Check if click-to-copy is enabled (default true)
    local clickEnabled = (addon.db.plugin.chat.interaction.clickToCopy ~= false)
    
    if clickEnabled then
        local id = tostring(GetTime()) .. "_" .. tostring(math.random(10000, 99999))
        PruneMessageCache()
        return string.format("|c%s|Htinychat:%s|h[%s]|h|r ", tsColor, id, ts), id
    else
        return string.format("|c%s[%s]|r ", tsColor, ts), nil
    end
end


function addon:InitCopy()
    -- [Phase 5] Seed the last known format for the settings proxy
    local currentFmt = C_CVar.GetCVar("showTimestamps")
    if currentFmt and currentFmt ~= "none" then
        addon.lastTimestampFormat = currentFmt
    end

    -- Transformer to linkify system-generated timestamps
    addon:RegisterChatFrameTransformer("copy", function(frame, msg, ...)
        if not addon.db or not addon.db.enabled then return msg end
        if type(msg) ~= "string" or msg == "" then return msg end

        -- Precise strategy: Match timestamp pattern but be careful with trailing characters.
        -- We removed the trailing |?r? from the regex because it greedily matched the '|' 
        -- of the NEXT link (e.g. |Hchannel...) breaking it.
        local pattern = "^(%s*|?c?%x*|?r?%[?%d+:%d+:?%d*%]?)"
        local start, finish, capture = msg:find(pattern)
        
        if start and capture then
             if capture:find("%d+:%d+") then
                -- Manually check for trailing |r (color reset) which wasn't in the safe regex
                if msg:sub(finish + 1, finish + 2) == "|r" then
                    capture = capture .. "|r"
                    finish = finish + 2
                end
             
                -- Generate a copy ID
                local id = tostring(GetTime()) .. "_" .. tostring(math.random(10000, 99999))
                PruneMessageCache()
                
                -- Smart Spacing:
                local nextChar = msg:sub(finish + 1, finish + 1)
                local needsSpace = (nextChar ~= "" and nextChar ~= " ")
                
                -- Construct the display link
                local linkified = string.format("|Htinychat:copy:%s|h%s|h%s", id, capture, needsSpace and " " or "")
                
                -- Construct the COPY text (what goes into the editbox)
                -- We want the copy text to also have the nice spacing
                local cleanCopyMsg = capture .. (needsSpace and " " or "") .. msg:sub(finish + 1)
                
                addon.messageCache[id] = { msg = cleanCopyMsg, time = GetTime() }
                
                -- Reassemble the message
                return linkified .. msg:sub(finish + 1)
             end
        end
        
        return msg
    end)
    
    -- Cleanup Debug commands
    if SLASH_TCTEST1 then
        SlashCmdList["TCTEST"] = nil
        SLASH_TCTEST1 = nil
    end

    hooksecurefunc("SetItemRef", function(link, text, button, chatFrame)
        if not link or type(link) ~= "string" then return end
        
        -- Check for our new link format: tinychat:copy:ID
        local prefix, id = link:match("^(tinychat:copy):(.+)$")
        
        -- Fallback for legacy format or just "tinychat:ID" if we ever use that
        if not prefix and link:sub(1, 9) == "tinychat:" then
             prefix = "tinychat"
             id = link:sub(10)
        end

        if prefix and id then
            local entry = addon.messageCache and addon.messageCache[id]
            -- entry could be the table {msg=..., time=...} or just string (legacy)
            local msg = entry and (type(entry) == "table" and entry.msg or entry) or nil
            
            if msg and type(msg) == "string" then
                local editBox = ChatEdit_ChooseBoxForSend()
                if not editBox:HasFocus() then
                    ChatEdit_ActivateChat(editBox)
                end
                -- When copying, we might want to strip the clickable link structure if it was part of the stored msg?
                -- Actually we stored the raw 'msg' passed to transformer.
                -- If that msg had a raw timestamp, we want to copy that. 
                -- We do NOT want to copy the |H...|h junk if we stored the modified one.
                -- But in the transformer, we stored 'msg' (original) BEFORE modification?
                -- Wait, in the code above: addon.messageCache[id] = { msg = msg ... } -> 'msg' is the INPUT to transformer.
                -- So it is the raw text with raw timestamp. Perfect.
                editBox:SetText(msg)
            end
        end
    end)
    
    -- [Phase 8] Real-time Mirror Sync
    -- If the user changes timestamps via Blizzard's own chat settings,
    -- we update our mirror DB and defaults so TinyChaton's UI stays in sync
    -- and its "Reset" buttons remain no-ops.
    addon:RegisterEvent("CVAR_UPDATE", function(_, name, value)
        if name == "showTimestamps" then
            local currentEnabled = (value ~= "none")
            local currentFormat = currentEnabled and value or (addon.db.plugin.chat.interaction.timestampFormat or "%H:%M ")
            
            -- 1. Update live DB (Crucial to do this first!)
            if addon.db and addon.db.plugin.chat and addon.db.plugin.chat.interaction then
                addon.db.plugin.chat.interaction.timestampEnabled = currentEnabled
                addon.db.plugin.chat.interaction.timestampFormat = currentFormat
            end
            
            -- 2. Update internal defaults (for global reset)
            if addon.DEFAULTS.plugin and addon.DEFAULTS.plugin.chat and addon.DEFAULTS.plugin.chat.interaction then
                addon.DEFAULTS.plugin.chat.interaction.timestampEnabled = currentEnabled
                addon.DEFAULTS.plugin.chat.interaction.timestampFormat = currentFormat
            end
            
            -- 3. Update Blizzard Setting defaults (for local page reset)
            local P_TS = "TinyChaton_Chat_Interaction_"
            local s_enable = Settings.GetSetting(P_TS .. "timestampEnabled")
            if s_enable then
                s_enable.defaultValue = currentEnabled and Settings.Default.True or Settings.Default.False
            end
            local s_format = Settings.GetSetting(P_TS .. "timestampFormat")
            if s_format then
                s_format.defaultValue = currentFormat
            end
        end
    end)
end
