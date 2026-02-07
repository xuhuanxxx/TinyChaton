local addonName, addon = ...
local L = addon.L

TinyChaton_MultiDropdownMixin = CreateFromMixins(SettingsDropdownControlMixin)

-- Normalize selection table to key -> boolean mapping
local function NormalizeSelection(selection)
    local map = {}
    if type(selection) ~= "table" then return map end
    for key, value in pairs(selection) do
        if value and (type(key) == "string" or type(key) == "number") then
            map[key] = true
        end
    end
    return map
end

-- Copy selection table
local function CopySelection(selection)
    local copy = {}
    if type(selection) ~= "table" then return copy end
    for key, value in pairs(selection) do
        if value then copy[key] = true end
    end
    return copy
end



function TinyChaton_MultiDropdownMixin:OnLoad()
    SettingsDropdownControlMixin.OnLoad(self)
    self.selectionCache = nil
end

function TinyChaton_MultiDropdownMixin:GetSetting()
    if self.initializer and self.initializer.GetSetting then
        return self.initializer:GetSetting()
    end
    if self.data and self.data.GetSetting then
        return self.data:GetSetting()
    end
    return nil
end

function TinyChaton_MultiDropdownMixin:CloneOption(option)
    local cloned = {}
    if type(option) == "table" then
        for key, value in pairs(option) do
            cloned[key] = value
        end
    else
        cloned.value = option
    end
    
    if cloned.value == nil then cloned.value = cloned.text end
    if cloned.value == nil and cloned.label then cloned.value = cloned.label end
    if cloned.value == nil and cloned.key then cloned.value = cloned.key end
    
    local fallback = cloned.text or cloned.label or tostring(cloned.value or "")
    if cloned.value == nil then cloned.value = fallback end
    
    cloned.label = cloned.label or fallback
    cloned.text = cloned.text or fallback
    
    return cloned
end

function TinyChaton_MultiDropdownMixin:SetOptions(list)
    if type(list) ~= "table" then
        self.options = {}
        return
    end
    
    local normalized = {}
    for _, option in ipairs(list) do
        table.insert(normalized, self:CloneOption(option))
    end
    
    self.options = normalized
    self.selectionCache = nil
end

function TinyChaton_MultiDropdownMixin:GetOptions()
    if self.optionfunc then
        local result = self.optionfunc()
        if type(result) == "table" then
            self:SetOptions(result)
        else
            self.options = {}
        end
    end
    return self.options or {}
end

function TinyChaton_MultiDropdownMixin:Init(initializer)
    if not initializer or not initializer.GetData then return end
    
    self.initializer = initializer
    local data = initializer:GetData() or {}
    
    self.var = data.var
    self.db = data.db
    self.optionfunc = data.optionfunc
    self.getSelectionFunc = data.getSelection or data.get
    self.setSelectionFunc = data.setSelection or data.set
    self.defaultSelection = NormalizeSelection(data.defaultSelection or data.default or {})
    self.categoryID = data.categoryID
    self.callback = data.callback
    self.data = data
    
    self:SetOptions(data.options or {})
    
    self._suppressSync = true
    SettingsDropdownControlMixin.Init(self, initializer)
    self:EnsureDefaultCallbacks()
    self._suppressSync = nil
    
    if data.label then self.Text:SetText(data.label) end
    
    self.selectionCache = nil
    self:UpdateDropdownText()
end

function TinyChaton_MultiDropdownMixin:SetValue(value)
    self.selectionCache = nil
    self:UpdateDropdownText()
end

function TinyChaton_MultiDropdownMixin:UpdateDropdownText()
    if not self.Control or not self.Control.Dropdown then return end
    
    self:RefreshSelectionCache()
    local opts = self:GetOptions()
    local selectedCount = 0
    
    for _, opt in ipairs(opts) do
        if opt.value ~= nil and self:IsSelected(opt.value, opt) then
            selectedCount = selectedCount + 1
        end
    end
    
    local text
    if selectedCount == 0 then
        text = L["LABEL_DROPDOWN_NONE"]
    elseif selectedCount >= #opts then
        text = L["LABEL_DROPDOWN_ALL"]
    else
        text = string.format("%d/%d", selectedCount, #opts)
    end
    
    self.Control.Dropdown:OverrideText(text)
end



function TinyChaton_MultiDropdownMixin:RefreshSelectionCache()
    local selection = {}
    
    if self.getSelectionFunc then
        local ok, result = pcall(self.getSelectionFunc)
        if ok then selection = NormalizeSelection(result) end
    end
    
    self.selectionCache = selection or {}
    return self.selectionCache
end

function TinyChaton_MultiDropdownMixin:GetSelectionMap()
    return self.selectionCache or self:RefreshSelectionCache()
end

function TinyChaton_MultiDropdownMixin:GetSelectionMapSnapshot()
    return CopySelection(self:GetSelectionMap())
end

function TinyChaton_MultiDropdownMixin:IsSelected(key, option)
    return self:GetSelectionMap()[key] == true
end

function TinyChaton_MultiDropdownMixin:SetSelected(key, shouldSelect, option)
    local selection = self:GetSelectionMapSnapshot()
    
    if shouldSelect then
        selection[key] = true
    else
        selection[key] = nil
    end
    
    if self.setSelectionFunc then
        pcall(self.setSelectionFunc, CopySelection(selection))
    end
    
    self.selectionCache = nil
    selection = self:GetSelectionMap()
    
    self:SyncSetting(selection)
end

function TinyChaton_MultiDropdownMixin:SyncSetting(selection)
    if self._suppressSync then return end
    local setting = self:GetSetting()
    if not setting then return end
    
    setting:SetValue(self:SerializeSelection(selection or self:GetSelectionMap()))
end

function TinyChaton_MultiDropdownMixin:ToggleOption(key, option)
    self:RefreshSelectionCache()
    local newState = not self:IsSelected(key, option)
    self:SetSelected(key, newState, option)
    self:UpdateDropdownText()
end

function TinyChaton_MultiDropdownMixin:SelectAll()
    local selection = {}
    for _, opt in ipairs(self:GetOptions()) do
        if opt.value ~= nil then
            selection[opt.value] = true
        end
    end
    
    if self.setSelectionFunc then
        pcall(self.setSelectionFunc, selection)
    end
    
    self.selectionCache = nil
    self:SyncSetting(selection)
    self:UpdateDropdownText()
end

function TinyChaton_MultiDropdownMixin:SelectNone()
    local selection = {}
    
    if self.setSelectionFunc then
        pcall(self.setSelectionFunc, selection)
    end
    
    self.selectionCache = nil
    self:SyncSetting(selection)
    self:UpdateDropdownText()
end

function TinyChaton_MultiDropdownMixin:IsAllSelected()
    local opts = self:GetOptions()
    for _, opt in ipairs(opts) do
        if opt.value ~= nil and not self:IsSelected(opt.value, opt) then
            return false
        end
    end
    return #opts > 0
end

function TinyChaton_MultiDropdownMixin:IsNoneSelected()
    for _, opt in ipairs(self:GetOptions()) do
        if opt.value ~= nil and self:IsSelected(opt.value, opt) then
            return false
        end
    end
    return true
end

function TinyChaton_MultiDropdownMixin:SerializeSelection(tbl)
    if type(tbl) ~= "table" then return "" end
    
    local keys = {}
    for k, v in pairs(tbl) do
        if v and (type(k) == "string" or type(k) == "number") then
            table.insert(keys, k)
        end
    end
    table.sort(keys)
    return table.concat(keys, ",")
end



function TinyChaton_MultiDropdownMixin:ApplyDefaultSelection()
    local selection = CopySelection(self.defaultSelection or {})
    if self.setSelectionFunc then
        pcall(self.setSelectionFunc, selection)
    end
    self.selectionCache = nil
    self:SyncSetting(selection)
end

function TinyChaton_MultiDropdownMixin:EnsureDefaultCallbacks()
    if self.defaultCallbacksRegistered then return end
    self.defaultCallbacksRegistered = true
    
    EventRegistry:RegisterCallback("Settings.Defaulted", function(_, setting)
        if setting == self:GetSetting() then
            self:ApplyDefaultSelection()
        end
    end, self)
    
    EventRegistry:RegisterCallback("Settings.CategoryDefaulted", function(_, category)
        if not self.categoryID or not category or not category.GetID then return end
        if category:GetID() == self.categoryID then
            self:ApplyDefaultSelection()
        end
    end, self)
end



function TinyChaton_MultiDropdownMixin:InitDropdown()
    local setting = self:GetSetting()
    local initializer = self:GetElementData()
    
    local function optionsFunc() return self:GetOptions() end
    
    local initTooltip = Settings.CreateOptionsInitTooltip(setting, initializer:GetName(), initializer:GetTooltip(), optionsFunc)
    
    self:SetupDropdownMenu(self.Control.Dropdown, setting, optionsFunc, initTooltip)
    
    if self.Control and self.Control.SetSteppersShown then
        self.Control:SetSteppersShown(false)
    end
end

function TinyChaton_MultiDropdownMixin:SetupDropdownMenu(button, setting, optionsFunc, initTooltip)
    local dropdown = button or self.Control.Dropdown
    
    dropdown:SetDefaultText("")
    
    dropdown:SetupMenu(function(_, rootDescription)
        self:RefreshSelectionCache()
        local opts = optionsFunc() or {}
        
        local selectAllLabel = L["LABEL_SELECT_ALL"]
        
        rootDescription:CreateCheckbox(selectAllLabel, function()
            return self:IsAllSelected()
        end, function()
            if self:IsAllSelected() then
                self:SelectNone()
            else
                self:SelectAll()
            end
            if self.callback then self.callback() end
        end)
        
        rootDescription:CreateDivider()

        for _, opt in ipairs(opts) do
            if opt.value ~= nil then
                local label = opt.label or opt.text or tostring(opt.value)
                
                rootDescription:CreateCheckbox(label, function()
                    return self:IsSelected(opt.value, opt)
                end, function()
                    self:ToggleOption(opt.value, opt)
                    if self.callback then self.callback(opt) end
                end, opt)
            end
        end
    end)
    
    if initTooltip then
        dropdown:SetTooltipFunc(initTooltip)
        dropdown:SetDefaultTooltipAnchors()
    end
    
    dropdown:SetScript("OnEnter", function()
        ButtonStateBehaviorMixin.OnEnter(dropdown)
        DefaultTooltipMixin.OnEnter(dropdown)
    end)
    
    dropdown:SetScript("OnLeave", function()
        ButtonStateBehaviorMixin.OnLeave(dropdown)
        DefaultTooltipMixin.OnLeave(dropdown)
    end)
end
