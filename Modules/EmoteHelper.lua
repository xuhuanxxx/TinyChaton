local addonName, addon = ...
local L = addon.L
local format = string.format

addon.Emotes = {}

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
        key = "{" .. name .. "}",
        -- Use addonName to ensure correct path even if folder is renamed
        file = "Interface\\AddOns\\" .. addonName .. "\\Media\\Texture\\Emote\\" .. name .. ".tga"
    })
end

-- Exported parser function
function addon.Emotes.Parse(msg)
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
    
    local newText = addon.Emotes.Parse(text)
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
                        local newText = addon.Emotes.Parse(text)
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

function addon:InitEmoteHelper()
    -- Register as a Transformer (Visual Layer)
    addon:RegisterChatFrameTransformer("emote_render", EmoteTransformer)
    
    -- Ensure it's in the execution order (lowest priority, run last)
    if addon.TRANSFORMER_ORDER then
        local found = false
        for _, v in ipairs(addon.TRANSFORMER_ORDER) do
            if v == "emote_render" then found = true; break end
        end
        if not found then
            table.insert(addon.TRANSFORMER_ORDER, "emote_render")
        end
    end

    HookChatBubbles()
    
    -- Hook into settings application to toggle ticker
    local origApply = addon.ApplyAllSettings
    addon.ApplyAllSettings = function(self)
        if origApply then origApply(self) end
        self:UpdateEmoteTickerState()
    end
end

-- P0: Register Module
addon:RegisterModule("EmoteHelper", addon.InitEmoteHelper)

local panel
local buttons = {}
local currentPage = 1
local maxPage = 1

local function GetPageSize()
    return addon.CONSTANTS and addon.CONSTANTS.EMOTE_PAGE_SIZE or 40
end

local function UpdateEmotePanel()
    if not panel then return end
    
    local pageSize = GetPageSize()
    local total = #emotes
    maxPage = math.ceil(total / pageSize)
    if currentPage > maxPage then currentPage = maxPage end
    if currentPage < 1 then currentPage = 1 end
    
    local startIndex = (currentPage - 1) * pageSize
    
    for i = 1, GetPageSize() do
        local btn = buttons[i]
        local emoteIndex = startIndex + i
        local emote = emotes[emoteIndex]
        
        if emote then
            btn:SetNormalTexture(emote.file)
            btn.emoteKey = emote.key
            btn:Show()
        else
            btn:Hide()
        end
    end
    
    panel.pageLabel:SetText(currentPage .. " / " .. maxPage)
    
    panel.prevBtn:SetEnabled(currentPage > 1)
    panel.nextBtn:SetEnabled(currentPage < maxPage)
end

function addon:ToggleEmotePanel(anchorFrame)
    if not panel then
        panel = CreateFrame("Frame", "TinyChatonEmotePanel", UIParent, "DialogBorderDarkTemplate")
        panel:ClearAllPoints()
        panel:SetFrameStrata("DIALOG")
        panel:SetClampedToScreen(true)
        panel:EnableMouse(true)
        
        -- Right-click on background to close
        panel:SetScript("OnMouseUp", function(self, button)
            if button == "RightButton" then
                self:Hide()
            end
        end)
        
        -- Register for ESC key closing (Fixed typo)
        table.insert(UISpecialFrames, "TinyChatonEmotePanel")

        -- Header (Native Style)
        panel.Header = CreateFrame("Frame", nil, panel, "DialogHeaderTemplate")
        panel.Header:SetPoint("TOP", 0, 12)
        -- DialogHeaderTemplate puts text in .Text
        if panel.Header.Text then
            panel.Header.Text:SetText(L["KIT_EMOTE"])
        else
             -- Fallback scan
            for _, region in ipairs({panel.Header:GetRegions()}) do
                if region:GetObjectType() == "FontString" then
                    region:SetText(L["KIT_EMOTE"])
                    break
                end
            end
        end
        panel.Header:SetFrameLevel(panel:GetFrameLevel() + 5)
        -- Allow right-click on header to close
        panel.Header:EnableMouse(true)
        panel.Header:SetScript("OnMouseUp", function(self, button)
            if button == "RightButton" then panel:Hide() end
        end)
        
        -- Close Button
        panel.CloseButton = CreateFrame("Button", nil, panel, "UIPanelCloseButton")
        panel.CloseButton:SetSize(24, 24)
        panel.CloseButton:SetPoint("TOPRIGHT", -5, -5)
        -- Allow right-click on close button to "close" (same as left)
        panel.CloseButton:RegisterForClicks("AnyUp")
        panel.CloseButton:SetScript("OnClick", function(self, button) 
            panel:Hide() 
        end)

        local size = 24
        local padding = 6
        local cols = 8 
        local rows = 5
        
        -- Adaptive Grid Container
        if not panel.Content then
            panel.Content = CreateFrame("Frame", nil, panel)
        end
        panel.Content:ClearAllPoints()
        -- Anchor content relative to the Header's bottom
        panel.Content:SetPoint("TOP", panel.Header, "BOTTOM", 0, -10)
        
        local gridWidth = (cols * (size + padding)) - padding
        local gridHeight = (rows * (size + padding)) - padding
        panel.Content:SetSize(gridWidth, gridHeight)
        
        -- Resize main panel to wrap content
        -- Width: Grid + Side Margins (approx 32 total)
        -- Height: Grid + Top Margin (Header area) + Bottom Margin (Nav area)
        -- We estimate header area takes ~40 space, Nav area ~30
        panel:SetSize(gridWidth + 40, gridHeight + 70) 

        -- Create Buttons
        for i = 1, GetPageSize() do
            local btn = CreateFrame("Button", nil, panel.Content) -- Parent to Content
            btn:SetSize(size, size)
            local row = math.floor((i-1) / cols)
            local col = (i-1) % cols
            
            -- Relative to Content Frame (0,0 is TopLeft of content)
            btn:SetPoint("TOPLEFT", col * (size + padding), -(row * (size + padding)))

            btn:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight")
            
            -- Register right-click to close
            btn:RegisterForClicks("AnyUp")
            btn:SetScript("OnClick", function(self, button)
                if button == "RightButton" then
                    panel:Hide()
                    return
                end
                
                local editBox = ChatEdit_ChooseBoxForSend()
                if editBox then
                    ChatEdit_ActivateChat(editBox)
                    -- ... insert logic ...
                    editBox:Insert(self.emoteKey)
                    if not IsShiftKeyDown() then
                        panel:Hide()
                    end
                end
            end)

            btn:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetText(self.emoteKey)
                GameTooltip:Show()
            end)
            btn:SetScript("OnLeave", function() GameTooltip:Hide() end)
            
            buttons[i] = btn
        end
        
        -- Create Navigation
        local navHeight = 20
        local prevBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
        prevBtn:SetSize(20, navHeight)
        prevBtn:SetPoint("BOTTOMLEFT", 16, 12) -- Fixed margin from bottom
        prevBtn:SetText("<")
        prevBtn:RegisterForClicks("AnyUp")
        prevBtn:SetScript("OnClick", function(self, button)
            if button == "RightButton" then panel:Hide() return end
            if currentPage > 1 then
                currentPage = currentPage - 1
                UpdateEmotePanel()
            end
        end)
        panel.prevBtn = prevBtn
        
        local nextBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
        nextBtn:SetSize(20, navHeight)
        nextBtn:SetPoint("BOTTOMRIGHT", -16, 12)
        nextBtn:SetText(">")
        nextBtn:RegisterForClicks("AnyUp")
        nextBtn:SetScript("OnClick", function(self, button)
            if button == "RightButton" then panel:Hide() return end
            if currentPage < maxPage then
                currentPage = currentPage + 1
                UpdateEmotePanel()
            end
        end)
        panel.nextBtn = nextBtn
        
        local pageLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        pageLabel:SetPoint("CENTER", panel, "BOTTOM", 0, 18)
        panel.pageLabel = pageLabel
        
        -- Explicitly update content on first creation
        UpdateEmotePanel()
        
        -- Set initial point if anchor provided, otherwise center
        if anchorFrame then
            panel:SetPoint("BOTTOMLEFT", anchorFrame, "TOPLEFT", 0, 5)
        else
            panel:SetPoint("CENTER")
        end
        
        -- Show it immediately on creation
        panel:Show()
        return
    end

    if panel:IsShown() then
        panel:Hide()
    else
        panel:ClearAllPoints()
        panel:SetPoint("BOTTOMLEFT", anchorFrame, "TOPLEFT", 0, 5)
        UpdateEmotePanel()
        panel:Show()
    end
end
