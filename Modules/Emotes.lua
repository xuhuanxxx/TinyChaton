local addonName, addon = ...
local L = addon.L

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
    if not addon.db or not addon.db.enabled or not addon.db.plugin.chat or not addon.db.plugin.chat.content.emoteRender then return msg end

    for _, e in ipairs(emotes) do
        -- Escape magic characters in key (e.g. { }) to treat them as literals
        local pattern = e.key:gsub("[%(%)%.%%%+%-%*%?%[%]%^%$]", "%%%1")
        msg = msg:gsub(pattern, "|T"..e.file..":0|t")
    end
    return msg
end

local function EmoteFilter(self, event, msg, ...)
    local newMsg = addon.Emotes.Parse(msg)
    if newMsg ~= msg then
        return false, newMsg, ...
    end
    return false, msg, ...
end

-- Chat Bubble Support
local function HookChatBubbles()
    if not C_ChatBubbles then return end
    
    local function FindFontString(frame)
        if not frame then return nil end
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
            local found = FindFontString(child)
            if found then return found end
        end
        
        return nil
    end
    
    local function UpdateBubbles()
        if not addon.db or not addon.db.enabled or not addon.db.plugin.chat or not addon.db.plugin.chat.content.emoteRender then return end
        
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
    addon._bubbleTicker = C_Timer.NewTicker(0.1, UpdateBubbles)
end

-- Stop bubble ticker when disabled
function addon:StopBubbleTicker()
    if addon._bubbleTicker then
        addon._bubbleTicker:Cancel()
        addon._bubbleTicker = nil
    end
end

function addon:InitEmotes()
    local events = addon.CHAT_EVENTS or {}
    for _, event in ipairs(events) do
        ChatFrame_AddMessageEventFilter(event, EmoteFilter)
    end
    HookChatBubbles()
end

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
        panel = CreateFrame("Frame", "TinyChatonEmotePanel", UIParent, "BackdropTemplate")
        panel:SetBackdrop({
            bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", -- Lighter border
            tile = true, tileSize = 16, edgeSize = 16,
            insets = { left = 4, right = 4, top = 4, bottom = 4 }
        })
        panel:SetBackdropColor(0, 0, 0, 0.9)
        panel:SetFrameStrata("DIALOG")
        panel:SetClampedToScreen(true)
        panel:EnableMouse(true)
        
        -- Register for ESC key closing
        table.insert(UISpecialFrames, "TinyChatEmotePanel")

        local size = 24
        local padding = 6
        local cols = 8 
        local rows = 5
        
        local width = 16 + (cols * (size + padding)) + 10
        local height = 16 + (rows * (size + padding)) + 30 -- +30 for navigation bar
        panel:SetSize(width, height)

        -- Create Buttons
        for i = 1, GetPageSize() do
            local btn = CreateFrame("Button", nil, panel)
            btn:SetSize(size, size)
            local row = math.floor((i-1) / cols)
            local col = (i-1) % cols
            btn:SetPoint("TOPLEFT", 16 + (col * (size + padding)), -16 - (row * (size + padding)))

            btn:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight")

            btn:SetScript("OnClick", function(self)
                local editBox = ChatEdit_ChooseBoxForSend()
                if editBox then
                    ChatEdit_ActivateChat(editBox)
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
        prevBtn:SetPoint("BOTTOMLEFT", 16, 8)
        prevBtn:SetText("<")
        prevBtn:SetScript("OnClick", function()
            if currentPage > 1 then
                currentPage = currentPage - 1
                UpdateEmotePanel()
            end
        end)
        panel.prevBtn = prevBtn
        
        local nextBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
        nextBtn:SetSize(20, navHeight)
        nextBtn:SetPoint("BOTTOMRIGHT", -16, 8)
        nextBtn:SetText(">")
        nextBtn:SetScript("OnClick", function()
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
