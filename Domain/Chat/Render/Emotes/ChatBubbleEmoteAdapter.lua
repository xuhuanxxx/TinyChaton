local addonName, addon = ...

addon.ChatBubbleEmoteAdapter = addon.ChatBubbleEmoteAdapter or {}
local Adapter = addon.ChatBubbleEmoteAdapter

Adapter.enabled = Adapter.enabled == true
Adapter.bubbleCache = Adapter.bubbleCache or setmetatable({}, { __mode = "k" })
Adapter.ticker = Adapter.ticker or nil

local function CreateCache()
    return setmetatable({}, { __mode = "k" })
end

local function FindFontString(frame, depth)
    if type(frame) ~= "table" then
        return nil
    end

    depth = depth or 0
    if depth > 10 then
        return nil
    end

    if type(frame.IsForbidden) == "function" and frame:IsForbidden() then
        return nil
    end

    if type(frame.GetNumRegions) == "function" and type(frame.GetRegions) == "function" then
        for i = 1, frame:GetNumRegions() do
            local region = select(i, frame:GetRegions())
            if region and type(region.GetObjectType) == "function" and region:GetObjectType() == "FontString" then
                local text = type(region.GetText) == "function" and region:GetText() or nil
                if type(text) == "string" and text ~= "" then
                    return region
                end
            end
        end
    end

    if type(frame.GetNumChildren) == "function" and type(frame.GetChildren) == "function" then
        for i = 1, frame:GetNumChildren() do
            local child = select(i, frame:GetChildren())
            local found = FindFontString(child, depth + 1)
            if found then
                return found
            end
        end
    end

    return nil
end

function Adapter:ResetCache()
    self.bubbleCache = CreateCache()
end

function Adapter:StopTicker()
    if self.ticker and type(self.ticker.Cancel) == "function" then
        self.ticker:Cancel()
    end
    self.ticker = nil
end

function Adapter:Disable()
    self:StopTicker()
    self:ResetCache()
    self.enabled = false
end

function Adapter:ProcessBubble(bubble, now)
    if type(bubble) ~= "table" then
        return
    end
    if type(bubble.IsForbidden) == "function" and bubble:IsForbidden() then
        return
    end

    local state = self.bubbleCache[bubble]
    if not state then
        state = {}
        self.bubbleCache[bubble] = state
    end

    if not state.fontString then
        local canRetry = (not state.lastScanAt) or ((now - state.lastScanAt) >= 2)
        if canRetry then
            state.lastScanAt = now
            state.fontString = FindFontString(bubble)
            state.failed = not state.fontString
        end
    end

    local fontString = state.fontString
    if not fontString or type(fontString.GetText) ~= "function" then
        return
    end

    local text = fontString:GetText()
    if type(text) ~= "string" or state.lastText == text then
        return
    end

    local parser = addon.EmoteParser
    if not parser or type(parser.Parse) ~= "function" then
        return
    end

    local result = parser:Parse(text)
    if result.renderedText ~= text and type(fontString.SetText) == "function" then
        fontString:SetText(result.renderedText)
        state.lastText = result.renderedText
        return
    end

    state.lastText = text
end

function Adapter:Tick()
    if not C_ChatBubbles or type(C_ChatBubbles.GetAllChatBubbles) ~= "function" then
        return
    end

    local now = type(GetTime) == "function" and GetTime() or 0
    local bubbles = C_ChatBubbles.GetAllChatBubbles()
    if type(bubbles) ~= "table" then
        return
    end

    for _, bubble in ipairs(bubbles) do
        self:ProcessBubble(bubble, now)
    end
end

function Adapter:Enable()
    if self.enabled then
        return
    end

    self.enabled = true
    if not C_ChatBubbles or not C_Timer or type(C_Timer.NewTicker) ~= "function" then
        return
    end

    local interval = addon.CONSTANTS and addon.CONSTANTS.EMOTE_TICKER_INTERVAL or 0.5
    self.ticker = C_Timer.NewTicker(interval, function()
        Adapter:Tick()
    end)
end

function Adapter:Reconcile(shouldEnable)
    if shouldEnable then
        self:Enable()
    else
        self:Disable()
    end
end

return Adapter
