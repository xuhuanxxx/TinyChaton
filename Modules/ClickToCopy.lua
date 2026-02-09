local addonName, addon = ...
local L = addon.L

addon.messageCache = addon.messageCache or {}

local function PruneMessageCache()
    local cache = addon.messageCache
    local maxAge = 600
    local maxCount = addon.COPY_MESSAGE_LIMIT or 200
    local now = GetTime()
    local toRemove = {}
    local n = 0
    
    -- Count and mark old entries
    for id, entry in pairs(cache) do
        n = n + 1
        local age = entry and type(entry) == "table" and entry.time and (now - entry.time) or 0
        if age > maxAge then
            toRemove[#toRemove + 1] = id
        end
    end
    
    -- Remove old entries
    for _, id in ipairs(toRemove) do
        cache[id] = nil
        n = n - 1
    end
    
    -- Enforce count limit
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

-- Transformer Logic (Replaces old Middleware)
local function CopyTimeStampTransformer(frame, text, r, g, b, ...)
    if not text then return text, r, g, b, ... end
    if not addon.db or not addon.db.enabled then return text, r, g, b, ... end

    local interaction = addon.db.plugin and addon.db.plugin.chat and addon.db.plugin.chat.interaction
    -- Check CVar directly
    local cvarTimestamp = C_CVar.GetCVar("showTimestamps")
    local cvarEnabled = (cvarTimestamp and cvarTimestamp ~= "none")
    
    if not cvarEnabled and (not interaction or not interaction.timestampEnabled) then 
        return text, r, g, b, ... 
    end
    
    local fmt = (interaction and interaction.timestampFormat) or cvarTimestamp or "%H:%M:%S"
    if fmt == "none" then fmt = "%H:%M:%S" end
    
    local ts = date(fmt)
    local tsColor
    
    if interaction and interaction.timestampColor then
        tsColor = interaction.timestampColor
    else
        -- Use message color (r,g,b) if available, otherwise default to white
        if r and g and b then
            tsColor = string.format("FF%02x%02x%02x", r * 255, g * 255, b * 255)
        else
            tsColor = "FFFFFFFF"
        end
    end
    
    local clickEnabled = (interaction and interaction.clickToCopy ~= false)
    
    local timestamp = ""
    
    if clickEnabled then
        local id = tostring(GetTime()) .. "_" .. tostring(math.random(10000, 99999))
        
        PruneMessageCache()
        -- Cache the text AS RECEIVED
        addon.messageCache[id] = { msg = text, time = GetTime() }
        
        -- Construct link: |cColor|Htinychat:copy:ID|h[Timestamp]|h|r
        timestamp = string.format("|c%s|Htinychat:copy:%s|h[%s]|h|r", tsColor, id, ts)
    else
        -- Static timestamp
        timestamp = string.format("|c%s[%s]|r", tsColor, ts)
    end
    
    -- Prepend timestamp to text
    return timestamp .. " " .. text, r, g, b, ...
end

local function SyncTimestampSettings(value)
    local currentEnabled = (value ~= "none")
    local currentFormat = currentEnabled and value or (addon.db.plugin.chat.interaction.timestampFormat or "%H:%M:%S")
    
    -- 1. Update live DB
    if addon.db and addon.db.plugin.chat and addon.db.plugin.chat.interaction then
        addon.db.plugin.chat.interaction.timestampEnabled = currentEnabled
        addon.db.plugin.chat.interaction.timestampFormat = currentFormat
    end
    
    -- 2. Update internal defaults
    if addon.DEFAULTS and addon.DEFAULTS.plugin and addon.DEFAULTS.plugin.chat and addon.DEFAULTS.plugin.chat.interaction then
        addon.DEFAULTS.plugin.chat.interaction.timestampEnabled = currentEnabled
        addon.DEFAULTS.plugin.chat.interaction.timestampFormat = currentFormat
    end
end

function addon:InitClickToCopy()
    -- Register Transformer
    addon:RegisterChatFrameTransformer("copy_timestamp", CopyTimeStampTransformer)

    -- Inject into TRANSFORMER_ORDER
    if addon.TRANSFORMER_ORDER then
        local found = false
        for _, v in ipairs(addon.TRANSFORMER_ORDER) do
            if v == "copy_timestamp" then found = true; break end
        end
        if not found then
            table.insert(addon.TRANSFORMER_ORDER, "copy_timestamp")
        end
    end

    -- [Phase 5 & 8] Sync Logic
    local currentFmt = C_CVar.GetCVar("showTimestamps")
    if currentFmt then
        addon.lastTimestampFormat = currentFmt
        -- Initial Sync
        if addon.db then SyncTimestampSettings(currentFmt) end
    end
    
    -- [Migration] Clear legacy default gray color so dynamic coloring works
    if addon.db and addon.db.plugin and addon.db.plugin.chat and addon.db.plugin.chat.interaction then
        if addon.db.plugin.chat.interaction.timestampColor == "FF888888" then
            addon.db.plugin.chat.interaction.timestampColor = nil
        end
    end

    hooksecurefunc("SetItemRef", function(link, text, button, chatFrame)
        if not link or type(link) ~= "string" then return end
        
        local prefix, id = link:match("^(tinychat:copy):(.+)$")
        if not prefix and link:sub(1, 9) == "tinychat:" then
             prefix = "tinychat"
             id = link:sub(10)
        end

        if prefix and id then
            local entry = addon.messageCache and addon.messageCache[id]
            local msg = entry and (type(entry) == "table" and entry.msg or entry) or nil
            
            if msg and type(msg) == "string" then
                local editBox = ChatEdit_ChooseBoxForSend()
                if not editBox:HasFocus() then
                    ChatEdit_ActivateChat(editBox)
                end
                editBox:SetText(msg)
            end
        end
    end)
    
    -- Real-time Mirror Sync
    addon:RegisterEvent("CVAR_UPDATE", function(_, name, value)
        if name == "showTimestamps" then
            SyncTimestampSettings(value)
        end
    end)
end
