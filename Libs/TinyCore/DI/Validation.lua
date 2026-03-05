local addonName, addon = ...

addon.TinyCoreDIValidation = addon.TinyCoreDIValidation or {}
local Validation = addon.TinyCoreDIValidation

function Validation.ResolveRequired(container, required)
    if type(container) ~= "table" or type(container.Resolve) ~= "function" then
        error("[DI] ResolveRequired requires a container with Resolve(name)")
    end
    if type(required) ~= "table" then
        error("[DI] ResolveRequired requires a required service list")
    end

    local resolved = {}
    for _, name in ipairs(required) do
        if type(name) ~= "string" or name == "" then
            error("[DI] required service name must be a non-empty string")
        end
        resolved[name] = container:Resolve(name)
    end
    return resolved
end
