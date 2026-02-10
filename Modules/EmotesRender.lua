local addonName, addon = ...
local L = addon.L
local format = string.format

addon.EmotesRender = {}

-- Built-in Raid Icons
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

-- Custom Emotes (Media/Texture/Emote/*.tga)
local customEmotes = {
    "Innocent", "Titter", "angel", "angry", "biglaugh", "clap", "cool", "cry", "cutie", "despise",
    "dreamsmile", "embarrass", "evil", "excited", "faint", "fight", "flu", "freeze", "frown", "greet",
    "grimace", "growl", "happy", "heart", "horror", "ill", "kongfu", "love", "mail", "makeup",
    "mario", "meditate", "miserable", "okay", "pretty", "puke", "raiders", "shake", "shout", "shuuuu",
    "shy", "sleep", "smile", "suprise", "surrender", "sweat", "tear", "tears", "think", "ugly",
    "victory", "volunteer", "wronged"
}

for _, name in ipairs(customEmotes) do
    table.insert(emotes, {
        key = format("{%s}", name),
        -- Use addonName to ensure correct path even if folder is renamed
        file = format("Interface\\AddOns\\%s\\Media\\Texture\\Emote\\%s.tga", addonName, name)
    })
end

-- Expose emotes list for Panel to use
addon.EmotesRender.emotes = emotes

-- Exported parser function
function addon.EmotesRender.Parse(msg)
    if not msg or type(msg) ~= "string" then return msg end
    -- P0: Config Safety
    if not addon:GetConfig("plugin.chat.content.emoteRender", true) then return msg end

    for _, e in ipairs(emotes) do
        -- P1: Regex Caching
        if not e.pattern then
             -- Escape magic characters in key (e.g. { }) to treat them as literals
             e.pattern = e.key:gsub("[%(%)%.%%%+%-%*%?%[%]%^%$]", "%%%1")
             e.replacement = format("|T%s:0|t", e.file)
        end
        msg = msg:gsub(e.pattern, e.replacement)
    end
    return msg
end

-- Transformer implementation (replaces old EmoteFilter)
local function EmoteTransformer(frame, text, ...)
    if not text or type(text) ~= "string" then return text, ... end
    if not addon:GetConfig("plugin.chat.content.emoteRender", true) then return text, ... end

    local newText = addon.EmotesRender.Parse(text)
    return newText, ...
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
        if not addon:GetConfig("plugin.chat.content.emoteRender", true) then return end

        local bubbles = C_ChatBubbles.GetAllChatBubbles()
        for _, bubble in ipairs(bubbles) do
            if not bubble:IsForbidden() then
                if not bubble.fontString then
                    bubble.fontString = FindFontString(bubble)
                end

                if bubble.fontString then
                    local text = bubble.fontString:GetText()
                    if text then
                        local newText = addon.EmotesRender.Parse(text)
                        if newText ~= text then
                            bubble.fontString:SetText(newText)
                        end
                    end
                end
            end
        end
    end

    -- Update bubbles periodically (save ticker for cleanup)
    -- P1: Config Constant
    local interval = addon.CONSTANTS.EMOTE_TICKER_INTERVAL or 0.2

    if not addon._bubbleTicker and addon:GetConfig("plugin.chat.content.emoteRender", true) then
        addon._bubbleTicker = C_Timer.NewTicker(interval, UpdateBubbles)
    end
end

-- Stop bubble ticker
function addon:StopBubbleTicker()
    if addon._bubbleTicker then
        addon._bubbleTicker:Cancel()
        addon._bubbleTicker = nil
    end
end

-- Update ticker state based on settings
function addon:UpdateEmoteTickerState()
    local enabled = addon:GetConfig("plugin.chat.content.emoteRender", true)

    if enabled then
        -- Delegate to HookChatBubbles which handles ticker creation and uses the correct local UpdateBubbles function
        if not addon._bubbleTicker then
            HookChatBubbles()
        end
    else
        addon:StopBubbleTicker()
    end
end

function addon:InitEmotesRender()
    -- Register as a Transformer (Visual Layer)
    addon:RegisterChatFrameTransformer("visual_emotes", EmoteTransformer)

    -- Transformer order is centralized in Core.lua

    HookChatBubbles()

    -- Hook into settings application to toggle ticker
    local origApply = addon.ApplyAllSettings
    addon.ApplyAllSettings = function(self)
        if origApply then origApply(self) end
        self:UpdateEmoteTickerState()
    end
end

-- P0: Register Module
addon:RegisterModule("EmotesRender", addon.InitEmotesRender)
