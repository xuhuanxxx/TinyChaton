local addonName, addon = ...

addon.TinyCoreRegistryCompiler = addon.TinyCoreRegistryCompiler or {}
local Compiler = addon.TinyCoreRegistryCompiler
Compiler.__index = Compiler

function Compiler:New(opts)
    local options = type(opts) == "table" and opts or {}
    local artifact = options.artifact
    if type(artifact) ~= "table" or type(artifact.Freeze) ~= "function" then
        error("TinyCore RegistryCompiler requires artifact with Freeze(value)")
    end

    return setmetatable({
        passes = options.passes or {},
        artifact = artifact,
    }, self)
end

function Compiler:Run(input, context)
    local ctx = type(context) == "table" and context or {}
    local state = input

    for index, pass in ipairs(self.passes) do
        if type(pass) ~= "function" then
            error(string.format("Registry compiler pass[%d] must be function", index))
        end
        state = pass(state, ctx)
    end

    return self.artifact:Freeze(state)
end
