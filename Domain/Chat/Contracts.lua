local addonName, addon = ...

addon.ChatContracts = addon.ChatContracts or {}

addon.ChatContracts.EventContext = {
    frame = "table|nil",
    event = "string",
    text = "string|nil",
    author = "string|nil",
    metadata = "table",
}

addon.ChatContracts.VisibilityDecision = {
    visible = "boolean",
    reason = "string|nil",
}

addon.ChatContracts.SnapshotRecord = {
    text = "string",
    author = "string|nil",
    channelKey = "string",
    time = "number",
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
    local spec = addon.ChatContracts and addon.ChatContracts[name]
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
