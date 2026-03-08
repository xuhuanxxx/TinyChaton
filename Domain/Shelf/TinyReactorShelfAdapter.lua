local addonName, addon = ...

addon.TinyReactorShelfAdapter = addon.TinyReactorShelfAdapter or {}

local Adapter = addon.TinyReactorShelfAdapter
local TR = addon.TinyReactor
if not TR then
    error("TinyReactor not initialized")
end

local ShelfButton = TR:Component("ShelfButton")
addon.ShelfButton = ShelfButton

local function BuildTooltipRenderer(tooltipSpec)
    if type(tooltipSpec) ~= "table" then
        return nil
    end

    return function(tt)
        if tooltipSpec.header and tooltipSpec.header ~= "" then
            tt:SetText(tooltipSpec.header, 1, 0.82, 0)
        end

        if tooltipSpec.description and tooltipSpec.description ~= "" then
            tt:AddLine(tooltipSpec.description, 1, 1, 1, 1, true)
        end

        for _, binding in ipairs(tooltipSpec.bindings or {}) do
            local prefix
            if binding.button == "left" then
                prefix = (addon.L and addon.L["LABEL_BINDING_LEFT"]) or "Left"
            elseif binding.button == "right" then
                prefix = (addon.L and addon.L["LABEL_BINDING_RIGHT"]) or "Right"
            else
                prefix = binding.button or ""
            end
            tt:AddLine(prefix .. "  " .. (binding.label or ""), 1, 1, 1, 1, true)
        end
    end
end

function ShelfButton:Render(props)
    local visual = props.visual or {}
    local statusIndicator = props.statusIndicator or {}
    local buttonSize = props.size

    return TR:CreateElement("Button", {
        key = props.key,
        size = buttonSize,
        point = props.point,
        text = props.text,
        textColor = visual.textColor,
        template = visual.template,
        backdrop = visual.backdrop,
        backdropColor = visual.bgColor,
        backdropBorderColor = visual.borderColor,

        onClick = function(btnSelf, button)
            if button == "LeftButton" and props.onLeftClick then
                props.onLeftClick(btnSelf)
            elseif button == "RightButton" and props.onRightClick then
                props.onRightClick(btnSelf)
            end
        end,

        onEnter = function(btnSelf)
            btnSelf:RegisterForClicks("AnyUp")

            if visual.hoverBorderColor then
                btnSelf:SetBackdropBorderColor(unpack(visual.hoverBorderColor))
            end

            if props.tooltip then
                GameTooltip:SetOwner(btnSelf, "ANCHOR_RIGHT")
                props.tooltip(GameTooltip, btnSelf)
                GameTooltip:Show()
            end
        end,

        onLeave = function(btnSelf)
            if visual.borderColor then
                btnSelf:SetBackdropBorderColor(unpack(visual.borderColor))
            end
            GameTooltip:Hide()
        end,

        onShow = function(btnSelf)
            btnSelf:RegisterForClicks("AnyUp")

            if visual.fontPath and visual.fontSize then
                local fs = btnSelf:GetFontString()
                if fs then
                    local _, _, outline = fs:GetFont()
                    fs:SetFont(visual.fontPath, visual.fontSize, outline or "")
                end
            end
        end,

        ref = function(btnSelf)
            if not btnSelf.StatusOverlay then
                btnSelf.StatusOverlay = btnSelf:CreateTexture(nil, "OVERLAY")
                btnSelf.StatusOverlay:SetPoint("CENTER")
            end

            local overlay = btnSelf.StatusOverlay
            local width = (buttonSize and buttonSize[1]) or 30
            local height = (buttonSize and buttonSize[2]) or 30
            local overlaySize = math.min(width, height) * 0.8

            overlay:SetSize(overlaySize, overlaySize)
            overlay:SetAlpha(statusIndicator.alpha or 0)

            if statusIndicator.kind ~= "none" and statusIndicator.texture then
                overlay:SetTexture(statusIndicator.texture)
                overlay:SetVertexColor(1, 1, 1, 1)
                overlay:Show()
            else
                overlay:Hide()
            end

            if btnSelf.GetFontString then
                local fontString = btnSelf:GetFontString()
                if fontString then
                    fontString:SetAlpha(statusIndicator.textAlpha or 1)
                end
            end
        end,
    })
end

local function ComputeContentSize(renderSpec)
    local items = renderSpec.items or {}
    local spacing = renderSpec.spacing or 0
    local count = #items
    local totalMainAxis = 0
    local maxCrossAxis = 0
    local defaultSize = renderSpec.buttonBaseSize or 30

    for _, item in ipairs(items) do
        local width = item.size and item.size[1] or renderSpec.buttonBaseSize or 30
        local height = item.size and item.size[2] or renderSpec.buttonBaseSize or 30
        if renderSpec.direction == "vertical" then
            totalMainAxis = totalMainAxis + height
            maxCrossAxis = math.max(maxCrossAxis, width)
        else
            totalMainAxis = totalMainAxis + width
            maxCrossAxis = math.max(maxCrossAxis, height)
        end
    end

    if count > 1 then
        totalMainAxis = totalMainAxis + ((count - 1) * spacing)
    end

    if renderSpec.direction == "vertical" then
        return math.max(maxCrossAxis, defaultSize), math.max(totalMainAxis, defaultSize)
    end
    return math.max(totalMainAxis, defaultSize), math.max(maxCrossAxis, defaultSize)
end

function Adapter:Render(containerFrame, renderSpec, options)
    if not containerFrame or not renderSpec then
        return nil
    end

    local opts = type(options) == "table" and options or {}
    local items = renderSpec.items or {}
    local elements = {}
    local contentWidth, contentHeight = ComputeContentSize(renderSpec)
    local centerContents = opts.centerContents == true
    local currentX = 0
    local currentY = 0

    if centerContents then
        if renderSpec.direction == "vertical" then
            currentY = 0
        else
            currentX = math.floor(((containerFrame:GetWidth() or contentWidth) - contentWidth) / 2)
        end
    end

    containerFrame:SetAlpha(renderSpec.alpha or 1)
    containerFrame:SetScale(renderSpec.scale or 1)

    for _, item in ipairs(items) do
        local point
        if renderSpec.direction == "vertical" then
            local x = centerContents and math.floor(((containerFrame:GetWidth() or item.size[1]) - (item.size[1] or 0)) / 2) or 0
            point = { "TOPLEFT", containerFrame, "TOPLEFT", x, currentY }
            currentY = currentY - ((item.size and item.size[2]) or (renderSpec.buttonBaseSize or 30)) - (renderSpec.spacing or 0)
        else
            point = { "LEFT", containerFrame, "LEFT", currentX, 0 }
            currentX = currentX + ((item.size and item.size[1]) or (renderSpec.buttonBaseSize or 30)) + (renderSpec.spacing or 0)
        end

        table.insert(elements, addon.ShelfButton:Create({
            key = item.key,
            text = item.text,
            size = item.size,
            point = point,
            visual = item.visual,
            statusIndicator = item.statusIndicator,
            tooltip = BuildTooltipRenderer(item.tooltip),
            onLeftClick = item.actions and item.actions.left and function(btnSelf)
                addon.Shelf:ExecuteAction(item.actions.left.actionKey, btnSelf, item.intentItem)
            end or nil,
            onRightClick = item.actions and item.actions.right and function(btnSelf)
                addon.Shelf:ExecuteAction(item.actions.right.actionKey, btnSelf, item.intentItem)
            end or nil,
        }))
    end

    TR.Reconciler:Render(containerFrame, elements)

    if not opts.preserveContainerSize then
        containerFrame:SetSize(contentWidth, contentHeight)
    end

    return {
        contentWidth = contentWidth,
        contentHeight = contentHeight,
        count = #items,
    }
end
