-- =========================================================================
-- TinyReactor Component
-- =========================================================================
-- Note: The basic class construction is handled in Core.lua via TR:Component
-- This file is reserved for future stateful component logic (Hooks, setState, etc.)

local addonName, addon = ...

local TR = addon.TinyReactor
if not TR then
    error("TinyReactor not initialized")
end

-- Placeholder for now.
-- In a full implementation, we might add lifecycle methods here.
