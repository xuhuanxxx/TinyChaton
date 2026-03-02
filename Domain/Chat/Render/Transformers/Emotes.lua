local addonName, addon = ...
local L = addon.L
local format = string.format

addon.EmotesRender = {}
addon.EmotesRender.bubbleCache = addon.EmotesRender.bubbleCache or setmetatable({}, { __mode = "k" })

-- Custom Emotes (Media/Texture/Emote/*.tga)
local customEmotes = {
    "Innocent", "Titter", "angel", "angry", "biglaugh", "clap", "cool", "cry", "cutie", "despise",
    "dreamsmile", "embarrass", "evil", "excited", "faint", "fight", "flu", "freeze", "frown", "greet",
    "grimace", "growl", "happy", "heart", "horror", "ill", "kongfu", "love", "mail", "makeup",
    "mario", "meditate", "miserable", "okay", "pretty", "puke", "raiders", "shake", "shout", "shuuuu",
    "shy", "sleep", "smile", "suprise", "surrender", "sweat", "tear", "tears", "think", "ugly",
    "victory", "volunteer", "wronged"
}

local function EnsureEmotes()
    if addon.EmotesRender.emotesBuilt and type(addon.EmotesRender.emotes) == "table" then
        return addon.EmotesRender.emotes
    end

    local emotes = {
        { key = "{star}",       file = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_1" },
        { key = "{circle}",     file = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_2" },
        { key = "{diamond}",    file = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_3" },
        { key = "{triangle}",   file = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_4" },
        { key = "{moon}",       file = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_5" },
        { key = "{square}",     file = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_6" },
        { key = "{cross}",      file = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_7" },
        { key = "{skull}",      file = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_8" },
    }

    for _, name in ipairs(customEmotes) do
        table.insert(emotes, {
            key = format("{%s}", name),
            file = format("Interface\\AddOns\\%s\\Media\\Texture\\Emote\\%s.tga", addonName, name)
        })
    end

    addon.EmotesRender.emotes = emotes
    addon.EmotesRender.emotesBuilt = true
    return emotes
end

addon.EmotesRender.GetEmotes = EnsureEmotes

-- Exported parser function
function addon.EmotesRender.Parse(msg)
    if not msg or type(msg) ~= "string" then return msg end
    if not addon:GetConfig("profile.chat.content.emoteRender", true) then return msg end

    local emotes = EnsureEmotes()
    for _, e in ipairs(emotes) do
        if not e.pattern then
             -- Escape magic characters in key (e.g. { }) to treat them as literals
             e.pattern = e.key:gsub("[%(%)%.%%%+%-%*%?%[%]%^%$]", "%%%1")
             e.replacement = format("|T%s:0|t", e.file)
        end
        msg = msg:gsub(e.pattern, e.replacement)
    end
    return msg
end

local function EmoteTransformer(frame, text, r, g, b, extraArgs)
    if not text or type(text) ~= "string" then return text, r, g, b, extraArgs end
    if not addon:GetConfig("profile.chat.content.emoteRender", true) then return text, r, g, b, extraArgs end

    local newText = addon.EmotesRender.Parse(text)
    return newText, r, g, b, extraArgs
end

-- Chat Bubble Support
local function HookChatBubbles()
    if not C_ChatBubbles then return end

    local function FindFontString(frame, depth)
        if not frame then return nil end

        -- Recursion guard
        depth = depth or 0
        if depth > 10 then return nil end

        if frame:IsForbidden() then return nil end

        -- Check regions directly
        for i = 1, frame:GetNumRegions() do
            local region = select(i, frame:GetRegions())
            if region and region:GetObjectType() == "FontString" then
                local text = region:GetText()
                -- Chat bubbles usually have text. If it's empty, it might be a shadow or something else.
                if text and text ~= "" then
                    return region
                end
            end
        end

        -- Check children recursively
        for i = 1, frame:GetNumChildren() do
            local child = select(i, frame:GetChildren())
            local found = FindFontString(child, depth + 1)
            if found then return found end
        end

        return nil
    end

    local function UpdateBubbles()
        if not addon:GetConfig("profile.chat.content.emoteRender", true) then return end

        local now = GetTime()
        local cache = addon.EmotesRender.bubbleCache
        local bubbles = C_ChatBubbles.GetAllChatBubbles()
        for _, bubble in ipairs(bubbles) do
            if not bubble:IsForbidden() then
                local state = cache[bubble]
                if not state then
                    state = {}
                    cache[bubble] = state
                end

                if not state.fontString then
                    local canRetry = (not state.lastScanAt) or ((now - state.lastScanAt) >= 2)
                    if canRetry then
                        state.lastScanAt = now
                        state.fontString = FindFontString(bubble)
                        state.failed = not state.fontString
                    end
                end

                if state.fontString then
                    local text = state.fontString:GetText()
                    if text then
                        if state.lastText ~= text then
                            local newText = addon.EmotesRender.Parse(text)
                            if newText ~= text then
                                state.fontString:SetText(newText)
                                state.lastText = newText
                            else
                                state.lastText = text
                            end
                        end
                    end
                end
            end
        end
    end

    local interval = addon.CONSTANTS.EMOTE_TICKER_INTERVAL or 0.5

    if not addon._bubbleTicker and addon:GetConfig("profile.chat.content.emoteRender", true) then
        addon._bubbleTicker = C_Timer.NewTicker(interval, UpdateBubbles)
    end
end

-- Stop bubble ticker
function addon:StopBubbleTicker()
    if addon._bubbleTicker then
        addon._bubbleTicker:Cancel()
        addon._bubbleTicker = nil
    end
    addon.EmotesRender.bubbleCache = setmetatable({}, { __mode = "k" })
end

-- Update ticker state based on settings
function addon:UpdateEmoteTickerState()
    local enabled = addon:GetConfig("profile.chat.content.emoteRender", true)

    if enabled then
        -- Delegate to HookChatBubbles which handles ticker creation and uses the correct local UpdateBubbles function
        if not addon._bubbleTicker then
            HookChatBubbles()
        end
    else
        addon:StopBubbleTicker()
    end
end

function addon:InitDisplayEmotesRender()
    local function ReconcileEmoteTickerState()
        if not addon.db or not addon.db.enabled then
            addon:StopBubbleTicker()
            return
        end

        if addon.IsFeatureEnabled and not addon:IsFeatureEnabled("EmotesRender") then
            addon:StopBubbleTicker()
            return
        end

        if addon.Can and addon.CAPABILITIES and not addon:Can(addon.CAPABILITIES.MUTATE_CHAT_DISPLAY) then
            addon:StopBubbleTicker()
            return
        end

        addon:UpdateEmoteTickerState()
    end

    local function EnableEmotesRender()
        addon:RegisterChatFrameTransformer("visual_emotes", EmoteTransformer)
        ReconcileEmoteTickerState()
    end

    local function DisableEmotesRender()
        addon.chatFrameTransformers["visual_emotes"] = nil
        addon:StopBubbleTicker()
    end

    if addon.RegisterFeature then
        addon:RegisterFeature("EmotesRender", {
            requires = { "MUTATE_CHAT_DISPLAY" },
            plane = addon.RUNTIME_PLANES and addon.RUNTIME_PLANES.CHAT_DATA or "CHAT_DATA",
            onEnable = EnableEmotesRender,
            onDisable = DisableEmotesRender,
        })
    else
        EnableEmotesRender()
    end

    if addon.RegisterCallback then
        addon:RegisterCallback("SETTINGS_APPLIED", ReconcileEmoteTickerState, "EmotesRender")
        addon:RegisterCallback("CHAT_RUNTIME_MODE_CHANGED", ReconcileEmoteTickerState, "EmotesRender")
    end
end

addon:RegisterModule("DisplayEmotesRender", addon.InitDisplayEmotesRender)
