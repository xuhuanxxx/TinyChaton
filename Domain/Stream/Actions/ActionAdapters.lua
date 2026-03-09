local addonName, addon = ...

addon.ShelfButtonAdapter = addon.ShelfButtonAdapter or {}
addon.ChatLinkAdapter = addon.ChatLinkAdapter or {}
addon.DirectUserActionAdapter = addon.DirectUserActionAdapter or {}
addon.PrefixInteractionAdapter = addon.PrefixInteractionAdapter or {}

local function ResolveActionSpec(actionKey)
    return addon.ACTION_REGISTRY and addon.ACTION_REGISTRY[actionKey] or nil
end

local function CloneTable(input)
    local copy = {}
    if type(input) ~= "table" then
        return copy
    end
    for key, value in pairs(input) do
        if type(value) == "table" then
            local nested = {}
            for nestedKey, nestedValue in pairs(value) do
                nested[nestedKey] = nestedValue
            end
            copy[key] = nested
        else
            copy[key] = value
        end
    end
    return copy
end

local function ResolveStreamBindingActionKey(streamKey, buttonType)
    if type(streamKey) ~= "string" or streamKey == "" then
        return nil
    end
    if type(buttonType) ~= "string" or buttonType == "" then
        return nil
    end

    local stream = addon.GetStreamByKey and addon:GetStreamByKey(streamKey) or nil
    if type(stream) ~= "table" then
        return nil
    end

    local bindings = addon.db and addon.db.profile and addon.db.profile.buttons and addon.db.profile.buttons.bindings or nil
    local customBind = type(bindings) == "table" and bindings[streamKey] or nil
    local selected = nil
    if type(customBind) == "table" and customBind[buttonType] ~= nil then
        selected = customBind[buttonType]
    else
        local defaults = type(stream.defaultBindings) == "table" and stream.defaultBindings or nil
        selected = defaults and defaults[buttonType] or nil
    end

    if selected == nil or selected == false then
        return selected
    end
    if addon.ACTION_REGISTRY and addon.ACTION_REGISTRY[selected] then
        return selected
    end
    if selected == "send" then
        return "send_" .. streamKey
    end
    if selected == "mute_toggle" then
        return "mute_toggle_" .. streamKey
    end
    return "channel_" .. streamKey .. "_" .. selected
end

addon.ResolveStreamBindingActionKey = addon.ResolveStreamBindingActionKey or ResolveStreamBindingActionKey

local PREFIX_CACHE_MAX_AGE = 600
local PREFIX_CACHE_LIMIT = 200

local function PrunePrefixCache()
    local cache = addon.prefixInteractionCache
    if type(cache) ~= "table" then
        return
    end

    local now = GetTime()
    local ordered = {}
    for id, entry in pairs(cache) do
        if type(entry) ~= "table" or type(entry.time) ~= "number" or (now - entry.time) > PREFIX_CACHE_MAX_AGE then
            cache[id] = nil
        else
            ordered[#ordered + 1] = { id = id, time = entry.time }
        end
    end

    if #ordered <= PREFIX_CACHE_LIMIT then
        return
    end

    table.sort(ordered, function(a, b)
        return a.time < b.time
    end)

    for index = 1, #ordered - PREFIX_CACHE_LIMIT do
        cache[ordered[index].id] = nil
    end
end

local function BuildPrefixInteractionId()
    return tostring(GetTime()) .. "_" .. tostring(math.random(10000, 99999))
end

local function ResolveNativeChannelMenuContext(frame, envelope)
    if type(envelope) ~= "table" then
        return nil
    end
    if envelope.wowChatType ~= "CHANNEL" then
        return nil
    end
    if not addon.GetStreamGroup or addon:GetStreamGroup(envelope.streamKey) ~= "dynamic" then
        return nil
    end

    local resolver = addon.ChannelSemanticResolver
    if type(resolver) ~= "table" or type(resolver.ResolveDynamic) ~= "function" then
        return nil
    end

    local resolved = resolver.ResolveDynamic({
        streamKey = envelope.streamKey,
        channelId = envelope.channelId,
        channelName = envelope.channelNameObserved,
    })
    local chatTarget = resolved and tonumber(resolved.channelId) or tonumber(envelope.channelId) or nil
    local chatName = resolved and resolved.activeName or envelope.channelNameObserved
    if not chatTarget or chatTarget <= 0 then
        return nil
    end
    if type(chatName) ~= "string" or chatName == "" then
        return nil
    end

    return {
        chatType = "CHANNEL",
        chatTarget = chatTarget,
        chatName = chatName,
        chatFrame = frame,
    }
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

function addon.PrefixInteractionAdapter:BuildRenderSpec(frame, envelope)
    local streamKey = type(envelope) == "table" and envelope.streamKey or nil
    if type(streamKey) ~= "string" or streamKey == "" then
        return nil
    end

    local leftActionKey = addon.ResolveStreamBindingActionKey and addon.ResolveStreamBindingActionKey(streamKey, "left") or nil
    if leftActionKey == false then
        leftActionKey = nil
    end

    local nativeMenuContext = ResolveNativeChannelMenuContext(frame, envelope)
    local rightInteractionKind = nativeMenuContext and "native_channel_menu" or "none"

    if (type(leftActionKey) ~= "string" or leftActionKey == "") and rightInteractionKind == "none" then
        return nil
    end

    PrunePrefixCache()
    addon.prefixInteractionCache = addon.prefixInteractionCache or {}

    local spec = {
        streamKey = streamKey,
        mode = envelope.sourceMode,
        leftActionKey = leftActionKey,
        rightInteractionKind = rightInteractionKind,
        nativeMenuContext = nativeMenuContext,
    }

    local interactionId = BuildPrefixInteractionId()
    addon.prefixInteractionCache[interactionId] = {
        time = GetTime(),
        spec = CloneTable(spec),
    }

    spec.interactionId = interactionId
    return spec
end

function addon.PrefixInteractionAdapter:OpenNativeChannelMenu(menuContext, clickContext)
    if type(menuContext) ~= "table" then
        return { ok = false, reason = "disabled" }
    end
    if not ChatFrameUtil or type(ChatFrameUtil.ShowChatChannelContextMenu) ~= "function" then
        return { ok = false, reason = "unsupported" }
    end

    local clickData = type(clickContext) == "table" and clickContext or {}
    local chatFrame = clickData.chatFrame or menuContext.chatFrame or _G.SELECTED_CHAT_FRAME or _G.DEFAULT_CHAT_FRAME or _G.ChatFrame1
    ChatFrameUtil.ShowChatChannelContextMenu(
        chatFrame,
        menuContext.chatType or "CHANNEL",
        menuContext.chatTarget,
        menuContext.chatName
    )

    return {
        ok = true,
        source = "prefix_interaction",
        reason = "native_channel_menu",
    }
end

function addon.PrefixInteractionAdapter:Execute(interactionId, clickContext)
    local cache = addon.prefixInteractionCache
    local entry = type(cache) == "table" and cache[interactionId] or nil
    if type(entry) ~= "table" or type(entry.spec) ~= "table" then
        return { ok = false, reason = "missing_interaction" }
    end

    local spec = entry.spec
    local clickData = type(clickContext) == "table" and clickContext or {}
    if clickData.button == "RightButton" then
        if spec.rightInteractionKind == "native_channel_menu" then
            return self:OpenNativeChannelMenu(spec.nativeMenuContext, clickData)
        end
        return { ok = false, reason = "disabled" }
    end

    if type(spec.leftActionKey) ~= "string" or spec.leftActionKey == "" then
        return { ok = false, reason = "disabled" }
    end

    return addon.ActionIntentOrchestrator:Execute({
        actionKey = spec.leftActionKey,
        targetKind = "stream",
        targetKey = spec.streamKey,
        source = "prefix_interaction",
        context = clickData,
    })
end

function addon.ChatLinkAdapter:BuildIntent(interactionId, context)
    local cache = addon.prefixInteractionCache
    local entry = type(cache) == "table" and cache[interactionId] or nil
    if type(entry) ~= "table" or type(entry.spec) ~= "table" then
        return nil
    end

    local spec = entry.spec
    if type(spec.leftActionKey) ~= "string" or spec.leftActionKey == "" then
        return nil
    end

    return {
        actionKey = spec.leftActionKey,
        targetKind = "stream",
        targetKey = spec.streamKey,
        source = "prefix_interaction",
        context = type(context) == "table" and context or nil,
    }
end

function addon.ChatLinkAdapter:Dispatch(interactionId, context)
    return self:Execute(interactionId, context)
end

function addon.ChatLinkAdapter:Execute(interactionId, context)
    if type(interactionId) ~= "string" or interactionId == "" then
        return { ok = false, reason = "missing_interaction" }
    end
    return addon.PrefixInteractionAdapter:Execute(interactionId, context)
end

function addon.ChatLinkAdapter:BuildRenderSpec(frame, envelope)
    return addon.PrefixInteractionAdapter:BuildRenderSpec(frame, envelope)
end

function addon.ChatLinkAdapter:BuildLink(interactionId, displayText)
    if type(interactionId) ~= "string" or interactionId == "" then
        return displayText
    end
    if type(displayText) ~= "string" or displayText == "" then
        return displayText
    end
    return string.format("|Htinychat:prefix:%s|h%s|h", interactionId, displayText)
end

function addon.ChatLinkAdapter:ResolveBoundAction(streamKey, buttonType)
    if addon.ResolveStreamBindingActionKey then
        return addon.ResolveStreamBindingActionKey(streamKey, buttonType)
    end
    return nil
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
