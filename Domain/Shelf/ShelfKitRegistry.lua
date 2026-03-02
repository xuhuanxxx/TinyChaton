local addonName, addon = ...
local L = addon.L
local KIT_BASE = (addon.PRIORITY_BASE and addon.PRIORITY_BASE.KIT) or 300
local PRI_STEP = addon.PRIORITY_STEP or 10

-- =========================================================================
-- KIT_REGISTRY
-- Shelf 工具按钮定义
-- 每个工具可以定义多种颜色方案
-- =========================================================================

addon.KIT_REGISTRY = {
    {
        key = "readyCheck",
        label = L["KIT_READYCHECK"],
        short = L["KIT_READYCHECK_SHORT"],

        priority = KIT_BASE + PRI_STEP * 0,
        defaultPinned = true,
        defaultBindings = { left = "readycheck" },

        tooltip = L["KIT_READYCHECK_TOOLTIP"]
    },
    {
        key = "countdown",
        label = L["KIT_COUNTDOWN"],
        short = L["KIT_COUNTDOWN_SHORT"],

        priority = KIT_BASE + PRI_STEP * 1,
        defaultPinned = true,
        defaultBindings = { left = "countdown_primary", right = "countdown_secondary", middle = "countdown_cancel" },

        tooltip = L["KIT_COUNTDOWN_TOOLTIP"]
    },
    {
        key = "leave",
        label = L["KIT_LEAVE"],
        short = L["KIT_LEAVE_SHORT"],

        priority = KIT_BASE + PRI_STEP * 2,
        defaultPinned = true,
        defaultBindings = { left = "leave_party" },

        tooltip = L["KIT_LEAVE_TOOLTIP"]
    },
    {
        key = "resetInstances",
        label = L["KIT_RESET_INSTANCES"],
        short = L["KIT_RESET_INSTANCES_SHORT"],

        priority = KIT_BASE + PRI_STEP * 3,
        defaultPinned = true,
        defaultBindings = { left = "reset_instances" },

        tooltip = L["KIT_RESET_INSTANCES_TOOLTIP"]
    },
    {
        key = "roll",
        label = L["KIT_ROLL"],
        short = L["KIT_ROLL_SHORT"],

        priority = KIT_BASE + PRI_STEP * 4,
        defaultPinned = true,
        defaultBindings = { left = "roll" },

        tooltip = L["KIT_ROLL_TOOLTIP"]
    },
    {
        key = "macro",
        label = L["KIT_MACRO"],
        short = L["KIT_MACRO_SHORT"],

        priority = KIT_BASE + PRI_STEP * 7,
        defaultPinned = false,
        defaultBindings = { left = "macro_toggle" },

        tooltip = L["KIT_MACRO_TOOLTIP"]
    },
    {
        key = "reload",
        label = L["KIT_RELOAD"],
        short = L["KIT_RELOAD_SHORT"],

        priority = KIT_BASE + PRI_STEP * 5,
        defaultPinned = true,
        defaultBindings = { left = "reload_ui" },

        tooltip = L["KIT_RELOAD_TOOLTIP"]
    },
    {
        key = "emotePanel",
        label = L["KIT_EMOTE"],
        short = L["KIT_EMOTE_SHORT"],

        priority = KIT_BASE + PRI_STEP * 6,
        defaultPinned = true,
        defaultBindings = { left = "emote_panel" },

        tooltip = L["KIT_EMOTE_TOOLTIP"]
    },
}
