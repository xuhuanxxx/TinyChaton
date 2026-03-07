local addonName, addon = ...

addon.StreamContracts = addon.StreamContracts or {}

addon.StreamContracts.EventContext = {
    frame = "table|nil",
    event = "string",
    text = "string|nil",
    author = "string|nil",
    streamKey = "string|nil",
    wowChatType = "string|nil",
    metadata = "table",
}

addon.StreamContracts.VisibilityDecision = {
    visible = "boolean",
    reason = "string|nil",
}

addon.StreamContracts.SnapshotRecord = {
    text = "string",
    author = "string|nil",
    streamKey = "string",
    wowChatType = "string",
    streamMeta = "table|nil",
    time = "number",
}

addon.StreamContracts.DisplayEnvelope = {
    mode = "string",
    frameName = "string|nil",
    event = "string",
    streamKey = "string",
    streamKind = "string|nil",
    streamGroup = "string|nil",
    wowChatType = "string",
    author = "string",
    channelMeta = "table",
    timestamp = "number",
    lineId = "number|string|nil",
    rawText = "string",
    classFilename = "string|nil",
}

addon.StreamContracts.DisplayAugmentContext = {
    frame = "table|nil",
    envelope = "table",
    line = "table",
    renderOptions = "table",
    displayText = "string|nil",
    r = "number|nil",
    g = "number|nil",
    b = "number|nil",
    extraArgs = "table|nil",
}

addon.StreamContracts.DisplayRenderResult = {
    displayText = "string",
    r = "number",
    g = "number",
    b = "number",
    extraArgs = "table",
    line = "table",
    debug = "table",
}

local function IsDebugValidationEnabled()
    return addon.runtime and addon.runtime.debug == true
end

local function IsTypeAllowed(spec, value)
    if spec == "any" then
        return true
    end

    for token in string.gmatch(spec, "[^|]+") do
        if token == "nil" and value == nil then
            return true
        end
        if token ~= "nil" and type(value) == token then
            return true
        end
    end
    return false
end

function addon:ValidateContract(name, value)
    local spec = addon.StreamContracts and addon.StreamContracts[name]
    if not spec then
        return true
    end

    if not IsDebugValidationEnabled() then
        return true
    end

    if type(value) ~= "table" then
        if addon.Warn then
            addon:Warn("Contract %s invalid: value must be table", tostring(name))
        end
        return false
    end

    local ok = true
    for field, expected in pairs(spec) do
        if not IsTypeAllowed(expected, value[field]) then
            ok = false
            if addon.Warn then
                addon:Warn(
                    "Contract %s.%s invalid: expected %s, got %s",
                    tostring(name),
                    tostring(field),
                    tostring(expected),
                    type(value[field])
                )
            end
        end
    end

    return ok
end
