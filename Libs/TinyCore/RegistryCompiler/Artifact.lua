local addonName, addon = ...

addon.TinyCoreRegistryArtifact = addon.TinyCoreRegistryArtifact or {}
local Artifact = addon.TinyCoreRegistryArtifact

local function FreezeTable(value, seen)
    if type(value) ~= "table" then
        return value
    end
    seen = seen or {}
    if seen[value] then
        return value
    end
    seen[value] = true

    for _, nested in pairs(value) do
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
            error("Attempt to modify frozen compiler output: " .. tostring(key), 2)
        end,
        __metatable = false,
    })
    return value
end

function Artifact:Freeze(value)
    return FreezeTable(value)
end
