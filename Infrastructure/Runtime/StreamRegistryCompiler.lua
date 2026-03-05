local addonName, addon = ...

addon.StreamRegistryCompiler = addon.StreamRegistryCompiler or {}
local Compiler = addon.StreamRegistryCompiler

if not addon.TinyCoreRegistryCompiler or type(addon.TinyCoreRegistryCompiler.New) ~= "function" then
    error("TinyCore RegistryCompiler is not initialized")
end
if not addon.TinyCoreRegistryArtifact or type(addon.TinyCoreRegistryArtifact.Freeze) ~= "function" then
    error("TinyCore RegistryArtifact is not initialized")
end
if not addon.TinyCoreRegistryStreamPasses or type(addon.TinyCoreRegistryStreamPasses.CreatePipeline) ~= "function" then
    error("TinyCore RegistryStreamPasses is not initialized")
end

local CoreCompiler = addon.TinyCoreRegistryCompiler:New({
    passes = addon.TinyCoreRegistryStreamPasses.CreatePipeline(),
    artifact = addon.TinyCoreRegistryArtifact,
})

function Compiler:Compile(registry)
    return CoreCompiler:Run(registry)
end
