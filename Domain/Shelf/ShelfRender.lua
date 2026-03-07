local addonName, addon = ...
local CF = _G["Create" .. "Frame"]
local L = addon.L

addon.ShelfSettingsService = addon.ShelfSettingsService or {}

local Shelf = nil
local shelfEventFrame = nil
local editModeCallbackRegistered = false

local SNAP_THRESHOLD = 50

local function SavePosition()
    if not Shelf then return end
    local db = addon.db and addon.db.profile and addon.db.profile.shelf
    if not db then return end

    local sl, sr, st, sb = Shelf:GetLeft(), Shelf:GetRight(), Shelf:GetTop(), Shelf:GetBottom()
    if not sl or not sr or not st or not sb then return end

    local parL, parR, parT, parB = UIParent:GetLeft(), UIParent:GetRight(), UIParent:GetTop(), UIParent:GetBottom()
    if not parL or not parR or not parT or not parB then return end

    local point
    local relPoint
    local snapX
    local snapY

    local nearLeft = (sl - parL) < SNAP_THRESHOLD
    local nearRight = (parR - sr) < SNAP_THRESHOLD
    local nearTop = (parT - st) < SNAP_THRESHOLD
    local nearBottom = (sb - parB) < SNAP_THRESHOLD

    if nearTop then
        if nearLeft then
            point, relPoint = "TOPLEFT", "TOPLEFT"
            snapX = nearLeft and 0 or (sl - parL)
            snapY = nearTop and 0 or (st - parT)
        elseif nearRight then
            point, relPoint = "TOPRIGHT", "TOPRIGHT"
            snapX = nearRight and 0 or (sr - parR)
            snapY = nearTop and 0 or (st - parT)
        else
            point, relPoint = "TOP", "TOP"
            snapX = ((sl + sr) / 2) - ((parL + parR) / 2)
            snapY = nearTop and 0 or (st - parT)
        end
    elseif nearBottom then
        if nearLeft then
            point, relPoint = "BOTTOMLEFT", "BOTTOMLEFT"
            snapX = nearLeft and 0 or (sl - parL)
            snapY = nearBottom and 0 or (sb - parB)
        elseif nearRight then
            point, relPoint = "BOTTOMRIGHT", "BOTTOMRIGHT"
            snapX = nearRight and 0 or (sr - parR)
            snapY = nearBottom and 0 or (sb - parB)
        else
            point, relPoint = "BOTTOM", "BOTTOM"
            snapX = ((sl + sr) / 2) - ((parL + parR) / 2)
            snapY = nearBottom and 0 or (sb - parB)
        end
    else
        point, relPoint = "BOTTOMLEFT", "BOTTOMLEFT"
        snapX = nearLeft and 0 or (sl - parL)
        snapY = sb - parB
    end

    Shelf:ClearAllPoints()
    Shelf:SetPoint(point, UIParent, relPoint, snapX, snapY)

    local p, _, rp, x, y = Shelf:GetPoint(1)
    db.savedPoint = { p, rp, x, y }
    db.anchor = "custom"

    if SettingsPanel and SettingsPanel:IsShown() then
        addon:ExecuteSettingsIntent("shelf_position_drag", "shelf")
    end
end

local function ApplyPosition(self)
    local db = addon.db and addon.db.profile and addon.db.profile.shelf
    if not db then return end
    self:ClearAllPoints()

    self:SetClampedToScreen(true)

    local applied = false
    local anchors = addon.AnchorRegistry and addon.AnchorRegistry:GetAnchors()

    if db.anchor == "custom" then
        if db.savedPoint and #db.savedPoint > 0 then
            local sp = db.savedPoint
            local rp = (#sp >= 4) and sp[2] or sp[1]
            self:SetPoint(sp[1], UIParent, rp, sp[#sp - 1], sp[#sp])
            applied = true
        else
            local defaultPos = addon.CONSTANTS.SHELF_DEFAULT_POSITION
            if anchors then
                for _, cfg in ipairs(anchors) do
                    if cfg.name == defaultPos and cfg.isValid() then
                        cfg.apply(self)
                        applied = true
                        break
                    end
                end
            end
        end
    end

    if not applied and anchors then
        for _, cfg in ipairs(anchors) do
            if cfg.name == db.anchor then
                if cfg.isValid() then
                    cfg.apply(self)
                    applied = true
                end
                break
            end
        end
    end

    if not applied and anchors then
        for _, cfg in ipairs(anchors) do
            if cfg.isValid() then
                cfg.apply(self)
                applied = true
                break
            end
        end
    end

    if not applied then
        self:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    end
end

local function UpdateEditModeShelf(self)
    if not self.selectionFrame then
        local f = CF("Frame", nil, self, "EditModeSystemSelectionTemplate")
        f:SetAllPoints()

        f.system = {
            GetSystemName = function() return L["LABEL_EDIT_MODE"] end,
            IsSelected = function() return self.isSelected end,
        }

        f:SetScript("OnMouseDown", function()
            if EditModeManagerFrame and EditModeManagerFrame.ClearSelectedSystem then
                EditModeManagerFrame:ClearSelectedSystem()
            end
            self.isSelected = true
            f:ShowSelected(true)
            self:StartMoving()
        end)

        f:SetScript("OnMouseUp", function()
            self:StopMovingOrSizing()
            SavePosition()
        end)

        self.selectionFrame = f
    end

    if self.isEditing then
        self.selectionFrame:Show()
        self.selectionFrame:ShowHighlighted()
    elseif self.selectionFrame and self.selectionFrame:IsShown() then
        self.selectionFrame:Hide()
        self.isSelected = false
    end
end

local function ToggleEditMode(self, enabled)
    if self.isEditing == enabled then return end
    self.isEditing = enabled
    self:SetMovable(enabled)
    self:EnableMouse(enabled)
    UpdateEditModeShelf(self)
end

function addon.Shelf:RenderToContainer(containerFrame, options, context)
    if not containerFrame then
        return nil
    end

    local spec = self:BuildRenderSpec(context)
    if not spec or not addon.TinyReactorShelfAdapter then
        return nil
    end

    return addon.TinyReactorShelfAdapter:Render(containerFrame, spec, options)
end

function addon.Shelf:Render()
    if not Shelf then return end

    if not addon.db or not addon.db.enabled or not addon.db.profile or not addon.db.profile.buttons or not addon.db.profile.buttons.enabled then
        Shelf:Hide()
        return
    end

    Shelf:Show()
    self:RenderToContainer(Shelf)
    ApplyPosition(Shelf)

    if Shelf.isEditing and Shelf.UpdateEditModeShelf then
        Shelf:UpdateEditModeShelf()
    end
end

function addon.Shelf:InitRender()
    if not addon.db or not addon.db.enabled or not addon.db.profile or not addon.db.profile.buttons then return end
    if not addon.db.profile.buttons.enabled then return end

    if not Shelf then
        Shelf = CF("Frame", "TinyChatonShelf", UIParent)
        Shelf:SetFrameStrata("MEDIUM")
        Shelf:SetFrameLevel(100)
        Shelf:Hide()

        Shelf.UpdateEditModeShelf = UpdateEditModeShelf
        Shelf.ToggleEditMode = ToggleEditMode
        Shelf.SavePosition = SavePosition
        Shelf.ApplyPosition = ApplyPosition

        self.frame = Shelf
        self.SavePosition = SavePosition
        self.ApplyPosition = ApplyPosition
    end

    local function SyncEditMode()
        if EditModeManagerFrame then
            ToggleEditMode(Shelf, EditModeManagerFrame:IsEditModeActive())
        end
    end

    if EventRegistry and EventRegistry.RegisterFrameEventAndCallback and not editModeCallbackRegistered then
        EventRegistry:RegisterFrameEventAndCallback("EDIT_MODE_LAYOUTS_UPDATED", SyncEditMode)
        editModeCallbackRegistered = true
    end

    if EditModeManagerFrame then
        EditModeManagerFrame:HookScript("OnShow", function() ToggleEditMode(Shelf, true) end)
        EditModeManagerFrame:HookScript("OnHide", function() ToggleEditMode(Shelf, false) end)
    end

    SyncEditMode()

    if not shelfEventFrame then
        shelfEventFrame = CF("Frame")
        shelfEventFrame:RegisterEvent("CHANNEL_UI_UPDATE")
        shelfEventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    end

    shelfEventFrame:SetScript("OnEvent", function()
        if addon.DynamicChannelResolver and addon.DynamicChannelResolver.InvalidateCache then
            addon.DynamicChannelResolver:InvalidateCache()
        end
        addon.Shelf:Render()
    end)

    self:Render()
end

function addon:RefreshShelf()
    if addon.Profiler and addon.Profiler.Start then
        addon.Profiler:Start("ShelfService.RefreshShelf")
    end
    if addon.Shelf then
        addon.Shelf:Render()
    end
    if addon.Profiler and addon.Profiler.Stop then
        addon.Profiler:Stop("ShelfService.RefreshShelf")
    end
end

function addon:RegisterChannelButtons()
    if addon.Shelf then
        addon.Shelf:Render()
    end
end

function addon:InitShelf()
    if not addon.Shelf then return end

    addon:RegisterSettingsSubscriber({
        key = "settings.shelf.render",
        phase = "shelf",
        priority = 10,
        apply = function(ctx)
            local service = addon:ResolveRequiredService("ShelfService")
            service:Commit(ctx)
        end,
    })

    if addon.Shelf.InitActionRegistry then
        addon.Shelf:InitActionRegistry()
    end

    if addon.Shelf.InitRender then
        addon.Shelf:InitRender()
    end
end

function addon.ShelfSettingsService:Commit()
    addon:RefreshShelf()
end

addon:RegisterModule("Shelf", addon.InitShelf)
