local addonName, addon = ...

addon.MemoryDiagnostics = addon.MemoryDiagnostics or {
    samples = {},
    sessionStarted = false,
    settingsOpenSampled = false,
    settingsCloseHooked = false,
}

local function IsAutoSampleEnabled()
    local account = addon.db and addon.db.account
    if type(account) ~= "table" then
        return false
    end
    return account.memoryDiagnosticsAutoSample == true
end

local function SetAutoSampleEnabled(enabled)
    local account = addon.db and addon.db.account
    if type(account) ~= "table" then
        return
    end
    account.memoryDiagnosticsAutoSample = enabled == true
end

local function CountSnapshotRecords()
    local total = 0
    local db = TinyChatonCharDB and TinyChatonCharDB.snapshot
    if type(db) ~= "table" then
        return 0
    end

    for _, channelBuffer in pairs(db) do
        if type(channelBuffer) == "table" and type(channelBuffer.size) == "number" then
            total = total + channelBuffer.size
        end
    end
    return total
end

local function CountMessageCache()
    local cache = addon.messageCache
    if type(cache) ~= "table" then
        return 0
    end
    local n = 0
    for _ in pairs(cache) do
        n = n + 1
    end
    return n
end

function addon.MemoryDiagnostics:Read()
    UpdateAddOnMemoryUsage()
    return {
        at = date("%H:%M:%S"),
        addonKB = GetAddOnMemoryUsage(addonName) or 0,
        luaKB = collectgarbage("count") or 0,
        snapshot = CountSnapshotRecords(),
        messageCache = CountMessageCache(),
    }
end

function addon.MemoryDiagnostics:Sample(tag, source)
    local src = source or "manual"
    if src == "auto" and not IsAutoSampleEnabled() then
        return
    end
    local key = tostring(tag or ("sample_" .. tostring(#self.samples + 1)))
    local stat = self:Read()
    self.samples[key] = stat
    print(string.format(
        "|cff00ffff[TinyChaton]|r mem[%s] addon=%.1fKB lua=%.1fKB snapshot=%d msgCache=%d time=%s",
        key,
        stat.addonKB,
        stat.luaKB,
        stat.snapshot,
        stat.messageCache,
        stat.at
    ))
end

function addon.MemoryDiagnostics:Diff(a, b)
    local sa = self.samples[a]
    local sb = self.samples[b]
    if not sa or not sb then
        print("|cffff0000[TinyChaton]|r Missing sample(s): " .. tostring(a) .. ", " .. tostring(b))
        return
    end
    print(string.format(
        "|cff00ffff[TinyChaton]|r diff[%s->%s] addon=%+.1fKB lua=%+.1fKB snapshot=%+d msgCache=%+d",
        tostring(a),
        tostring(b),
        (sb.addonKB - sa.addonKB),
        (sb.luaKB - sa.luaKB),
        (sb.snapshot - sa.snapshot),
        (sb.messageCache - sa.messageCache)
    ))
end

function addon.MemoryDiagnostics:StartSession()
    if self.sessionStarted then
        return
    end
    if not IsAutoSampleEnabled() then
        return
    end
    self.sessionStarted = true
    C_Timer.After(10, function()
        if IsAutoSampleEnabled() then
            addon.MemoryDiagnostics:Sample("t0_login_10s", "auto")
        end
    end)
    C_Timer.After(300, function()
        if IsAutoSampleEnabled() then
            addon.MemoryDiagnostics:Sample("t1_chat_5m", "auto")
        end
    end)
end

function addon.MemoryDiagnostics:MarkSettingsOpened()
    if not IsAutoSampleEnabled() then
        return
    end
    if self.settingsOpenSampled then
        return
    end
    self.settingsOpenSampled = true
    self:Sample("t2_settings_opened", "auto")

    if self.settingsCloseHooked then
        return
    end
    if SettingsPanel and SettingsPanel.HookScript then
        SettingsPanel:HookScript("OnHide", function()
            C_Timer.After(60, function()
                addon.MemoryDiagnostics:Sample("t3_settings_closed_60s", "auto")
            end)
        end)
        self.settingsCloseHooked = true
    end
end

SLASH_TINYCHATON_MEM1 = "/tcmem"
SlashCmdList["TINYCHATON_MEM"] = function(msg)
    local cmd, a, b = string.match(msg or "", "^(%S*)%s*(%S*)%s*(%S*)$")
    cmd = string.lower(cmd or "")
    if cmd == "" or cmd == "report" then
        addon.MemoryDiagnostics:Sample("manual", "manual")
    elseif cmd == "sample" then
        addon.MemoryDiagnostics:Sample(a ~= "" and a or nil, "manual")
    elseif cmd == "diff" then
        addon.MemoryDiagnostics:Diff(a, b)
    elseif cmd == "reset" then
        addon.MemoryDiagnostics.samples = {}
        addon.MemoryDiagnostics.settingsOpenSampled = false
        print("|cff00ffff[TinyChaton]|r memory samples reset.")
    elseif cmd == "auto" then
        local opt = string.lower(a or "")
        if opt == "on" then
            SetAutoSampleEnabled(true)
            print("|cff00ffff[TinyChaton]|r memory auto-sample enabled.")
        elseif opt == "off" then
            SetAutoSampleEnabled(false)
            print("|cff00ffff[TinyChaton]|r memory auto-sample disabled.")
        else
            local status = IsAutoSampleEnabled() and "on" or "off"
            print("|cff00ffff[TinyChaton]|r memory auto-sample is " .. status .. ".")
        end
    else
        print("|cff00ffff[TinyChaton]|r /tcmem report | sample <tag> | diff <a> <b> | reset | auto <on|off>")
    end
end
