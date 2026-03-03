local addonName, addon = ...

addon.StreamRegistryCompiler = addon.StreamRegistryCompiler or {}

local Compiler = addon.StreamRegistryCompiler

local KIND_SET = {
    channel = true,
    notice = true,
}

local GROUP_SET = {
    system = true,
    dynamic = true,
    private = true,
    alert = true,
    log = true,
}

local CAPABILITY_KEYS = {
    "inbound",
    "outbound",
    "snapshotDefault",
    "copyDefault",
    "supportsMute",
    "supportsAutoJoin",
    "pinnable",
}

local CATEGORY_ORDER = { "CHANNEL", "NOTICE" }
local GROUP_ORDER = {
    CHANNEL = { "SYSTEM", "DYNAMIC", "PRIVATE" },
    NOTICE = { "SYSTEM", "ALERT", "LOG" },
}

local function AssertNonEmptyString(value, label)
    if type(value) ~= "string" or value == "" then
        error(string.format("%s must be a non-empty string", tostring(label)))
    end
end

local function CloneValue(value, seen)
    if type(value) ~= "table" then
        return value
    end
    seen = seen or {}
    if seen[value] then
        return seen[value]
    end
    local out = {}
    seen[value] = out
    for k, v in pairs(value) do
        out[CloneValue(k, seen)] = CloneValue(v, seen)
    end
    return out
end

local function FreezeTable(value, seen)
    if type(value) ~= "table" then
        return value
    end
    seen = seen or {}
    if seen[value] then
        return value
    end
    seen[value] = true

    for key, nested in pairs(value) do
        if type(nested) == "table" then
            FreezeTable(nested, seen)
        end
    end

    local mt = getmetatable(value)
    if mt and mt.__newindex then
        return value
    end
    setmetatable(value, {
        __newindex = function(_, key)
            error("Attempt to modify frozen stream compiler output: " .. tostring(key), 2)
        end,
        __metatable = false,
    })
    return value
end

local function CollectSubKeys(category, ordered)
    local seen = {}
    local out = {}
    for _, key in ipairs(ordered or {}) do
        if type(category[key]) == "table" then
            out[#out + 1] = key
            seen[key] = true
        end
    end

    local extras = {}
    for key, value in pairs(category) do
        if type(value) == "table" and not seen[key] then
            extras[#extras + 1] = key
        end
    end
    table.sort(extras)
    for _, key in ipairs(extras) do
        out[#out + 1] = key
    end

    return out
end

local function CollectRawStreams(registry)
    local orderedRaw = {}

    for _, categoryKey in ipairs(CATEGORY_ORDER) do
        local category = registry[categoryKey]
        if type(category) == "table" then
            local orderedSubKeys = CollectSubKeys(category, GROUP_ORDER[categoryKey])
            for _, subKey in ipairs(orderedSubKeys) do
                local streams = category[subKey]
                if type(streams) == "table" then
                    for index, stream in ipairs(streams) do
                        if type(stream) == "table" then
                            orderedRaw[#orderedRaw + 1] = {
                                raw = stream,
                                categoryKey = categoryKey,
                                subKey = subKey,
                                sourceLabel = string.format("STREAM_REGISTRY.%s.%s[%d]", tostring(categoryKey), tostring(subKey), index),
                            }
                        else
                            error(string.format("STREAM_REGISTRY.%s.%s[%d] must be table", tostring(categoryKey), tostring(subKey), index))
                        end
                    end
                else
                    error(string.format("STREAM_REGISTRY.%s.%s must be table", tostring(categoryKey), tostring(subKey)))
                end
            end
        end
    end

    return orderedRaw
end

local function SchemaPass(orderedRaw)
    local seenKeys = {}

    for _, row in ipairs(orderedRaw) do
        local stream = row.raw
        local source = row.sourceLabel

        AssertNonEmptyString(stream.key, source .. ".key")
        if seenKeys[stream.key] then
            error(string.format("Duplicate stream key '%s': %s vs %s", stream.key, seenKeys[stream.key], source))
        end
        seenKeys[stream.key] = source

        AssertNonEmptyString(stream.kind, source .. ".kind")
        local kind = string.lower(stream.kind)
        if not KIND_SET[kind] then
            error(source .. ".kind must be 'channel'|'notice'")
        end

        AssertNonEmptyString(stream.group, source .. ".group")
        local group = string.lower(stream.group)
        if not GROUP_SET[group] then
            error(source .. ".group is invalid")
        end

        AssertNonEmptyString(stream.chatType, source .. ".chatType")
        if type(stream.priority) ~= "number" then
            error(source .. ".priority must be number")
        end
        if type(stream.identity) ~= "table" then
            error(source .. ".identity must be table")
        end

        if type(stream.events) ~= "table" then
            error(source .. ".events must be table")
        end
        for eventIndex, eventName in ipairs(stream.events) do
            AssertNonEmptyString(eventName, source .. ".events[" .. tostring(eventIndex) .. "]")
        end

        if type(stream.capabilities) ~= "table" then
            error(source .. ".capabilities must be table")
        end
        for _, key in ipairs(CAPABILITY_KEYS) do
            if type(stream.capabilities[key]) ~= "boolean" then
                error(source .. ".capabilities." .. tostring(key) .. " must be boolean")
            end
        end

        if kind == "notice" then
            if stream.capabilities.outbound ~= false then
                error(source .. ".capabilities.outbound must be false for notice")
            end
            if stream.capabilities.supportsAutoJoin ~= false then
                error(source .. ".capabilities.supportsAutoJoin must be false for notice")
            end
        end

        if stream.capabilities.outbound ~= true and stream.defaultBindings ~= nil then
            error(source .. ".defaultBindings is not allowed when capabilities.outbound=false")
        end

        if stream.defaultAutoJoin ~= nil then
            if type(stream.defaultAutoJoin) ~= "boolean" then
                error(source .. ".defaultAutoJoin must be boolean when provided")
            end
            if stream.capabilities.supportsAutoJoin ~= true then
                error(source .. ".defaultAutoJoin requires capabilities.supportsAutoJoin=true")
            end
        end
    end
end

local function NormalizeStream(raw)
    local normalized = CloneValue(raw)
    local kind = string.lower(raw.kind)
    local group = string.lower(raw.group)
    local capabilities = {}
    for _, key in ipairs(CAPABILITY_KEYS) do
        capabilities[key] = raw.capabilities[key] == true
    end

    normalized.kind = kind
    normalized.group = group
    normalized.capabilities = capabilities

    normalized.defaultPinned = capabilities.pinnable == true
    normalized.defaultSnapshotted = capabilities.snapshotDefault == true
    normalized.defaultCopyable = capabilities.copyDefault == true
    normalized.isInboundOnly = capabilities.outbound ~= true
    if capabilities.supportsAutoJoin == true then
        normalized.defaultAutoJoin = raw.defaultAutoJoin == true
    else
        normalized.defaultAutoJoin = nil
    end

    if capabilities.outbound ~= true then
        normalized.defaultBindings = nil
    end

    return normalized
end

local function NormalizePass(orderedRaw)
    local normalizedRows = {}
    for _, row in ipairs(orderedRaw) do
        normalizedRows[#normalizedRows + 1] = {
            raw = row.raw,
            stream = NormalizeStream(row.raw),
            categoryKey = row.categoryKey,
            subKey = row.subKey,
            sourceLabel = row.sourceLabel,
        }
    end
    return normalizedRows
end

local function IndexPass(normalizedRows)
    local compiled = {
        byKey = {},
        rawByKey = {},
        kindByKey = {},
        groupByKey = {},
        capabilitiesByKey = {},
        streamKeysByGroup = {},
        outboundStreamKeys = {},
        dynamicStreamKeys = {},
        orderedStreamKeys = {},
    }

    for _, row in ipairs(normalizedRows) do
        local stream = row.stream
        local key = stream.key

        compiled.byKey[key] = stream
        compiled.rawByKey[key] = row.raw
        compiled.kindByKey[key] = stream.kind
        compiled.groupByKey[key] = stream.group
        compiled.capabilitiesByKey[key] = stream.capabilities
        compiled.orderedStreamKeys[#compiled.orderedStreamKeys + 1] = key

        if not compiled.streamKeysByGroup[stream.group] then
            compiled.streamKeysByGroup[stream.group] = {}
        end
        compiled.streamKeysByGroup[stream.group][#compiled.streamKeysByGroup[stream.group] + 1] = key

        if stream.capabilities.outbound == true then
            compiled.outboundStreamKeys[#compiled.outboundStreamKeys + 1] = key
        end
        if stream.kind == "channel" and stream.group == "dynamic" then
            compiled.dynamicStreamKeys[#compiled.dynamicStreamKeys + 1] = key
        end
    end

    return compiled
end

local function EventPass(compiled)
    local eventToChatType = {}
    local eventToStreamKey = {}

    for _, streamKey in ipairs(compiled.orderedStreamKeys) do
        local stream = compiled.byKey[streamKey]
        for _, eventName in ipairs(stream.events or {}) do
            local mappedChatType = eventToChatType[eventName]
            if mappedChatType and mappedChatType ~= stream.chatType then
                error(string.format(
                    "Chat event mapping conflict: %s => %s vs %s (stream=%s)",
                    tostring(eventName),
                    tostring(mappedChatType),
                    tostring(stream.chatType),
                    tostring(streamKey)
                ))
            end
            eventToChatType[eventName] = stream.chatType

            if eventName ~= "CHAT_MSG_CHANNEL" then
                local mappedStream = eventToStreamKey[eventName]
                if mappedStream and mappedStream ~= streamKey then
                    error(string.format(
                        "Chat event stream mapping conflict: %s => %s vs %s",
                        tostring(eventName),
                        tostring(mappedStream),
                        tostring(streamKey)
                    ))
                end
                eventToStreamKey[eventName] = streamKey
            end
        end
    end

    local chatEvents = {}
    for eventName in pairs(eventToChatType) do
        chatEvents[#chatEvents + 1] = eventName
        if eventName ~= "CHAT_MSG_CHANNEL" and string.match(eventName, "^CHAT_MSG_") then
            local streamKey = eventToStreamKey[eventName]
            if type(streamKey) ~= "string" or streamKey == "" then
                error("Missing stream mapping for non-channel event: " .. tostring(eventName))
            end
        end
    end

    table.sort(chatEvents)

    if eventToChatType["CHAT_MSG_CHANNEL"] ~= "CHANNEL" then
        error("CHAT_MSG_CHANNEL must map to chatType CHANNEL")
    end

    compiled.eventToChatType = eventToChatType
    compiled.eventToStreamKey = eventToStreamKey
    compiled.chatEvents = chatEvents
end

function Compiler:Compile(registry)
    if type(registry) ~= "table" then
        error("STREAM_REGISTRY is not initialized")
    end

    local orderedRaw = CollectRawStreams(registry)
    SchemaPass(orderedRaw)

    local normalizedRows = NormalizePass(orderedRaw)
    local compiled = IndexPass(normalizedRows)
    EventPass(compiled)

    return FreezeTable(compiled)
end
