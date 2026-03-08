local addonName, addon = ...

addon.ChatLinkRouter = addon.ChatLinkRouter or {}
local Router = addon.ChatLinkRouter

local itemRefHooked = false
local frameHyperlinkHooked = false
local recentDispatch = recentDispatch or {
    token = nil,
    time = 0,
}

local function DebugLog(fmt, ...)
    if addon._chatLinkDebug ~= true then
        return
    end
    print(string.format("|cff00ffff[TinyChaton][LinkDebug]|r " .. tostring(fmt), ...))
end

function Router:Dispatch(link, text, button, chatFrame)
    if type(link) ~= "string" or link == "" then
        return false
    end

    local frameName = chatFrame and chatFrame.GetName and chatFrame:GetName() or chatFrame
    local token = table.concat({
        tostring(link),
        tostring(button),
        tostring(frameName),
    }, "|")
    local now = GetTime and GetTime() or time()
    if recentDispatch.token == token and (now - (recentDispatch.time or 0)) <= 0.05 then
        DebugLog("dispatch deduped token=%s", tostring(token))
        return true
    end

    local action, payload = link:match("^tinychat:([^:]+):(.+)$")
    if type(action) ~= "string" or action == "" then
        return false
    end

    DebugLog("dispatch action=%s payload=%s button=%s frame=%s", tostring(action), tostring(payload), tostring(button),
        tostring(chatFrame and chatFrame.GetName and chatFrame:GetName() or chatFrame))

    if action == "prefix" then
        if not (type(payload) == "string" and payload ~= "" and addon.ChatLinkAdapter) then
            DebugLog("prefix dispatch aborted: missing adapter or payload")
            return false
        end
        recentDispatch.token = token
        recentDispatch.time = now
        addon.ChatLinkAdapter:Execute(payload, {
            link = link,
            text = text,
            button = button,
            chatFrame = chatFrame,
        })
        DebugLog("prefix dispatch executed payload=%s", tostring(payload))
        return true
    end

    if action == "copy" then
        local service = addon.TimestampCopyService
        if not (type(payload) == "string" and payload ~= "" and type(service) == "table"
            and type(service.OpenChatWithPayload) == "function") then
            DebugLog("copy dispatch aborted: missing service or payload")
            return false
        end
        recentDispatch.token = token
        recentDispatch.time = now
        local ok = service:OpenChatWithPayload(payload) == true
        DebugLog("copy dispatch handled=%s payload=%s", tostring(ok), tostring(payload))
        return ok
    end

    DebugLog("dispatch ignored unknown action=%s", tostring(action))
    return false
end

local function HookHyperlinkFrames()
    if frameHyperlinkHooked then
        return
    end

    for i = 1, NUM_CHAT_WINDOWS do
        local frame = _G["ChatFrame" .. i]
        if type(frame) == "table" and type(frame.HookScript) == "function" then
            frame:HookScript("OnHyperlinkClick", function(self, link, text, button)
                if type(link) == "string" and link:find("^tinychat:", 1, false) then
                    DebugLog("OnHyperlinkClick received link=%s", tostring(link))
                    Router:Dispatch(link, text, button, self)
                end
            end)
        end
    end

    frameHyperlinkHooked = true
    DebugLog("ChatFrame OnHyperlinkClick hooks enabled")
end

function Router:Enable()
    if itemRefHooked then
        DebugLog("SetItemRef hook already enabled")
    else
        itemRefHooked = true

        -- WoW custom chat hyperlinks resolve through SetItemRef; route TinyChaton links here.
        hooksecurefunc("SetItemRef", function(link, text, button, chatFrame)
            if type(link) == "string" and link:find("^tinychat:", 1, false) then
                DebugLog("SetItemRef received link=%s", tostring(link))
            end
            Router:Dispatch(link, text, button, chatFrame)
        end)
        DebugLog("SetItemRef hook enabled")
    end

    HookHyperlinkFrames()
end

function Router:Disable()
end

function addon:InitChatLinkRouter()
    addon:RegisterFeature("ChatLinkRouter", {
        plane = addon.RUNTIME_PLANES and addon.RUNTIME_PLANES.UI_ONLY or "UI_ONLY",
        onEnable = function()
            Router:Enable()
        end,
        onDisable = function()
            Router:Disable()
        end,
    })
end

addon:RegisterModule("ChatLinkRouter", addon.InitChatLinkRouter)

SLASH_TINYCHATON_LINKDEBUG1 = "/tclinkdebug"
SlashCmdList["TINYCHATON_LINKDEBUG"] = function()
    addon._chatLinkDebug = not addon._chatLinkDebug
    print(string.format("|cff00ffff[TinyChaton][LinkDebug]|r %s", addon._chatLinkDebug and "ON" or "OFF"))
end
