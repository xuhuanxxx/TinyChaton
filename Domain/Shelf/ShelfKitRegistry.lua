local addonName, addon = ...
local L = addon.L

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

        order = 210,
        defaultPinned = true,
        defaultBindings = { left = "readycheck" },

        tooltip = L["KIT_READYCHECK_TOOLTIP"]
    },
    {
        key = "countdown",
        label = L["KIT_COUNTDOWN"],
        short = L["KIT_COUNTDOWN_SHORT"],

        order = 220,
        defaultPinned = true,
        defaultBindings = { left = "countdown_primary", right = "countdown_secondary", middle = "countdown_cancel" },

        tooltip = L["KIT_COUNTDOWN_TOOLTIP"]
    },
    {
        key = "leave",
        label = L["KIT_LEAVE"],
        short = L["KIT_LEAVE_SHORT"],

        order = 230,
        defaultPinned = true,
        defaultBindings = { left = "leave_party" },

        tooltip = L["KIT_LEAVE_TOOLTIP"]
    },
    {
        key = "resetInstances",
        label = L["KIT_RESET_INSTANCES"],
        short = L["KIT_RESET_INSTANCES_SHORT"],

        order = 240,
        defaultPinned = true,
        defaultBindings = { left = "reset_instances" },

        tooltip = L["KIT_RESET_INSTANCES_TOOLTIP"]
    },
    {
        key = "roll",
        label = L["KIT_ROLL"],
        short = L["KIT_ROLL_SHORT"],

        order = 250,
        defaultPinned = true,
        defaultBindings = { left = "roll" },

        tooltip = L["KIT_ROLL_TOOLTIP"]
    },
    {
        key = "macro",
        label = L["KIT_MACRO"],
        short = L["KIT_MACRO_SHORT"],

        order = 280,
        defaultPinned = false,
        defaultBindings = { left = "macro_toggle" },

        tooltip = L["KIT_MACRO_TOOLTIP"]
    },
    {
        key = "reload",
        label = L["KIT_RELOAD"],
        short = L["KIT_RELOAD_SHORT"],

        order = 260,
        defaultPinned = true,
        defaultBindings = { left = "reload_ui" },

        tooltip = L["KIT_RELOAD_TOOLTIP"]
    },
    {
        key = "emotePanel",
        label = L["KIT_EMOTE"],
        short = L["KIT_EMOTE_SHORT"],

        order = 270,
        defaultPinned = true,
        defaultBindings = { left = "emote_panel" },

        tooltip = L["KIT_EMOTE_TOOLTIP"]
    },
}
