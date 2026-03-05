local addonName, addon = ...

addon.TinyCoreSettingsSchemaValidator = addon.TinyCoreSettingsSchemaValidator or {}
local Validator = addon.TinyCoreSettingsSchemaValidator

function Validator.ResolveAccessor(reg)
    local accessor = reg and reg.accessor or nil
    if not accessor then
        accessor = {
            get = reg and (reg.get or reg.getValue) or nil,
            set = reg and (reg.set or reg.setValue) or nil,
        }
    end
    return accessor
end

function Validator.ResolveDefault(reg)
    if not reg then return nil end
    if type(reg.default) == "function" then
        return reg.default()
    end
    return reg.default
end

function Validator.ValidateByType(reg, value)
    if not reg then
        return false, "unknown setting"
    end

    if reg.validate then
        return reg.validate(value)
    end

    local t = reg.valueType
    if t == "boolean" and type(value) ~= "boolean" then
        return false, "expected boolean"
    elseif t == "number" and type(value) ~= "number" then
        return false, "expected number"
    elseif (t == "string" or t == "color") and type(value) ~= "string" then
        return false, "expected string"
    elseif t == "table" and type(value) ~= "table" then
        return false, "expected table"
    end

    if reg.ui and reg.ui.type == "slider" and type(value) == "number" then
        if reg.ui.min and value < reg.ui.min then
            return false, "below min"
        end
        if reg.ui.max and value > reg.ui.max then
            return false, "above max"
        end
    end

    if reg.ui and reg.ui.options and type(value) == "string" then
        local options = reg.ui.options()
        if type(options) == "table" and #options > 0 then
            local found = false
            for _, opt in ipairs(options) do
                if opt.value == value then
                    found = true
                    break
                end
            end
            if not found then
                return false, "invalid option"
            end
        end
    end

    return true
end
