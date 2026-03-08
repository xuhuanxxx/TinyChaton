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
        identity = {
            labelKey = "KIT_READYCHECK",
            shortOneKey = "KIT_READYCHECK_SHORT_ONE",
            shortTwoKey = "KIT_READYCHECK_SHORT_TWO",
        },

        priority = KIT_BASE + PRI_STEP * 0,
        defaultPinned = true,
        defaultBindings = { left = "readycheck" },

        tooltip = L["KIT_READYCHECK_TOOLTIP"]
    },
    {
        key = "countdown",
        identity = {
            labelKey = "KIT_COUNTDOWN",
            shortOneKey = "KIT_COUNTDOWN_SHORT_ONE",
            shortTwoKey = "KIT_COUNTDOWN_SHORT_TWO",
        },

        priority = KIT_BASE + PRI_STEP * 1,
        defaultPinned = true,
        defaultBindings = { left = "countdown_primary", right = "countdown_secondary" },

        tooltip = L["KIT_COUNTDOWN_TOOLTIP"]
    },
    {
        key = "leave",
        identity = {
            labelKey = "KIT_LEAVE",
            shortOneKey = "KIT_LEAVE_SHORT_ONE",
            shortTwoKey = "KIT_LEAVE_SHORT_TWO",
        },

        priority = KIT_BASE + PRI_STEP * 2,
        defaultPinned = true,
        defaultBindings = { left = "leave_party" },

        tooltip = L["KIT_LEAVE_TOOLTIP"]
    },
    {
        key = "resetInstances",
        identity = {
            labelKey = "KIT_RESET_INSTANCES",
            shortOneKey = "KIT_RESET_INSTANCES_SHORT_ONE",
            shortTwoKey = "KIT_RESET_INSTANCES_SHORT_TWO",
        },

        priority = KIT_BASE + PRI_STEP * 3,
        defaultPinned = true,
        defaultBindings = { left = "reset_instances" },

        tooltip = L["KIT_RESET_INSTANCES_TOOLTIP"]
    },
    {
        key = "roll",
        identity = {
            labelKey = "KIT_ROLL",
            shortOneKey = "KIT_ROLL_SHORT_ONE",
            shortTwoKey = "KIT_ROLL_SHORT_TWO",
        },

        priority = KIT_BASE + PRI_STEP * 4,
        defaultPinned = true,
        defaultBindings = { left = "roll" },

        tooltip = L["KIT_ROLL_TOOLTIP"]
    },
    {
        key = "macro",
        identity = {
            labelKey = "KIT_MACRO",
            shortOneKey = "KIT_MACRO_SHORT_ONE",
            shortTwoKey = "KIT_MACRO_SHORT_TWO",
        },

        priority = KIT_BASE + PRI_STEP * 7,
        defaultPinned = false,
        defaultBindings = { left = "macro_toggle" },

        tooltip = L["KIT_MACRO_TOOLTIP"]
    },
    {
        key = "reload",
        identity = {
            labelKey = "KIT_RELOAD",
            shortOneKey = "KIT_RELOAD_SHORT_ONE",
            shortTwoKey = "KIT_RELOAD_SHORT_TWO",
        },

        priority = KIT_BASE + PRI_STEP * 5,
        defaultPinned = true,
        defaultBindings = { left = "reload_ui" },

        tooltip = L["KIT_RELOAD_TOOLTIP"]
    },
    {
        key = "emotePanel",
        identity = {
            labelKey = "KIT_EMOTE",
            shortOneKey = "KIT_EMOTE_SHORT_ONE",
            shortTwoKey = "KIT_EMOTE_SHORT_TWO",
        },

        priority = KIT_BASE + PRI_STEP * 6,
        defaultPinned = true,
        defaultBindings = { left = "emote_panel" },

        tooltip = L["KIT_EMOTE_TOOLTIP"]
    },
}
