local addonName, addon = ...

addon.ShelfButtonAdapter = addon.ShelfButtonAdapter or {}
addon.ChatLinkAdapter = addon.ChatLinkAdapter or {}
addon.DirectUserActionAdapter = addon.DirectUserActionAdapter or {}

local function ResolveActionSpec(actionKey)
    return addon.ACTION_REGISTRY and addon.ACTION_REGISTRY[actionKey] or nil
end

function addon.ShelfButtonAdapter:BuildIntent(actionKey, buttonFrame, item)
    local action = ResolveActionSpec(actionKey)
    local itemSpec = type(item) == "table" and item or {}
    return {
        actionKey = actionKey,
        targetKind = (action and action.targetKind) or itemSpec.type,
        targetKey = (itemSpec.key or itemSpec.itemKey or (action and action.targetKey)),
        source = "shelf_button",
        context = {
            buttonFrame = buttonFrame,
            item = item,
        },
    }
end

function addon.ShelfButtonAdapter:Execute(actionKey, buttonFrame, item)
    return addon.ActionIntentOrchestrator:Execute(self:BuildIntent(actionKey, buttonFrame, item))
end

function addon.ChatLinkAdapter:BuildIntent(action, payload, context)
    if action == "send" and type(payload) == "string" and payload ~= "" then
        return {
            actionKey = "send_" .. payload,
            targetKind = "stream",
            targetKey = payload,
            source = "chat_link",
            context = type(context) == "table" and context or nil,
        }
    end
    return nil
end

function addon.ChatLinkAdapter:Execute(action, payload, context)
    local intent = self:BuildIntent(action, payload, context)
    if not intent then
        return nil
    end
    return addon.ActionIntentOrchestrator:Execute(intent)
end

function addon.DirectUserActionAdapter:BuildIntent(intentLike)
    local input = type(intentLike) == "table" and intentLike or {}
    local action = ResolveActionSpec(input.actionKey)
    return {
        actionKey = input.actionKey,
        targetKind = input.targetKind or (action and action.targetKind) or nil,
        targetKey = input.targetKey or (action and action.targetKey) or nil,
        payload = input.payload,
        source = "direct_user_action",
        context = type(input.context) == "table" and input.context or nil,
    }
end

function addon.DirectUserActionAdapter:Execute(intentLike)
    return addon.ActionIntentOrchestrator:Execute(self:BuildIntent(intentLike))
end

function addon:ExecuteUserAction(intentLike)
    return addon.DirectUserActionAdapter:Execute(intentLike)
end
