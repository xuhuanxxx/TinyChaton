local addonName, addon = ...

addon.TinyCoreRuntimeCapabilityMatrix = addon.TinyCoreRuntimeCapabilityMatrix or {}
local CapabilityMatrix = addon.TinyCoreRuntimeCapabilityMatrix
CapabilityMatrix.__index = CapabilityMatrix

function CapabilityMatrix:New(matrix, defaultMode)
    return setmetatable({
        matrix = type(matrix) == "table" and matrix or {},
        defaultMode = type(defaultMode) == "string" and defaultMode or "ACTIVE",
    }, self)
end

function CapabilityMatrix:Can(mode, capability)
    if not capability then
        return true
    end
    local runtimeMode = type(mode) == "string" and mode or self.defaultMode
    local row = self.matrix[runtimeMode] or self.matrix[self.defaultMode] or {}
    return row[capability] == true
end
