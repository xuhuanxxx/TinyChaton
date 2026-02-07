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
        colors = {
            white = {1, 1, 1, 1},
            blizzard = {1, 0.82, 0, 1},
            rainbow = {1, 1, 1, 1},
        },
        order = 10, 
        defaultPinned = true, 
        defaultBindings = { left = "default" }, 
        actions = { { key = "default", label = L["KIT_READYCHECK"], tooltip = L["KIT_READYCHECK_TOOLTIP"], execute = function() DoReadyCheck() end } }, 
        tooltip = L["KIT_READYCHECK_TOOLTIP"] 
    },
    { 
        key = "resetInstances", 
        label = L["KIT_RESET_INSTANCES"], 
        short = L["KIT_RESET_INSTANCES_SHORT"], 
        colors = {
            white = {1, 1, 1, 1},
            blizzard = {1, 0.82, 0, 1},
            rainbow = {1, 1, 1, 1},
        },
        order = 20, 
        defaultPinned = true, 
        defaultBindings = { left = "default" }, 
        actions = { { key = "default", label = L["KIT_RESET_INSTANCES"], tooltip = L["KIT_RESET_INSTANCES_TOOLTIP"], execute = function() ResetInstances() end } }, 
        tooltip = L["KIT_RESET_INSTANCES_TOOLTIP"] 
    },
    { 
        key = "countdown", 
        label = L["KIT_COUNTDOWN"], 
        short = L["KIT_COUNTDOWN_SHORT"], 
        colors = {
            white = {1, 1, 1, 1},
            blizzard = {1, 0.82, 0, 1},
            rainbow = {1, 1, 1, 1},
        },
        order = 30, 
        defaultPinned = true, 
        defaultBindings = { left = "default", right = "secondary", middle = "cancel" }, 
        actions = { 
            { key = "default", label = L["ACTION_TIMER_PRIMARY"], tooltip = L["ACTION_TIMER_PRIMARY_DESC"], execute = function() C_PartyInfo.DoCountdown(addon.db.plugin.shelf.kitOptions.countdown.primary or 10) end }, 
            { key = "secondary", label = L["ACTION_TIMER_SECONDARY"], tooltip = L["ACTION_TIMER_SECONDARY_DESC"], execute = function() C_PartyInfo.DoCountdown(addon.db.plugin.shelf.kitOptions.countdown.secondary or 5) end }, 
            { key = "cancel", label = L["ACTION_CANCEL"], tooltip = L["ACTION_CANCEL"], execute = function() C_PartyInfo.DoCountdown(0) end } 
        }, 
        tooltip = L["KIT_COUNTDOWN_TOOLTIP"] 
    },
    { 
        key = "roll", 
        label = L["KIT_ROLL"], 
        short = L["KIT_ROLL_SHORT"], 
        colors = {
            white = {1, 1, 1, 1},
            blizzard = {1, 0.82, 0, 1},
            rainbow = {1, 1, 1, 1},
        },
        order = 40, 
        defaultPinned = true, 
        defaultBindings = { left = "default" }, 
        actions = { { key = "default", label = L["KIT_ROLL"], tooltip = L["KIT_ROLL_TOOLTIP"], execute = function() RandomRoll(1, 100) end } }, 
        tooltip = L["KIT_ROLL_TOOLTIP"] 
    },
    { 
        key = "filter", 
        label = L["KIT_FILTER"], 
        short = L["KIT_FILTER_SHORT"], 
        colors = {
            white = {1, 1, 1, 1},
            blizzard = {1, 0.82, 0, 1},
            rainbow = {1, 1, 1, 1},
        },
        order = 50, 
        defaultPinned = false, 
        defaultBindings = { left = "default" }, 
        actions = { { key = "default", label = L["KIT_FILTER"], tooltip = L["KIT_FILTER_TOOLTIP"], execute = function() if addon.db.plugin.filter then addon.db.plugin.filter.enabled = not addon.db.plugin.filter.enabled; addon:ApplyFilterSettings(); print(L["LABEL_FILTER"] .. " " .. (addon.db.plugin.filter.enabled and L["LABEL_STATUS_ENABLED"] or L["LABEL_STATUS_DISABLED"])) end end } }, 
        tooltip = function(tooltip, self) local enabled = addon.db and addon.db.plugin.filter and addon.db.plugin.filter.enabled or false; tooltip:AddLine(enabled and L["LABEL_STATUS_ENABLED"] or L["LABEL_STATUS_DISABLED"], 1, 1, 1) end 
    },
    { 
        key = "macro", 
        label = L["KIT_MACRO"], 
        short = L["KIT_MACRO_SHORT"], 
        colors = {
            white = {1, 1, 1, 1},
            blizzard = {1, 0.82, 0, 1},
            rainbow = {1, 1, 1, 1},
        },
        order = 60, 
        defaultPinned = false, 
        defaultBindings = { left = "default" }, 
        actions = { { key = "default", label = L["KIT_MACRO"], tooltip = L["KIT_MACRO_TOOLTIP"], execute = function() if MacroFrame and MacroFrame:IsShown() then HideUIPanel(MacroFrame) else ShowMacroFrame() end end } }, 
        tooltip = L["KIT_MACRO_TOOLTIP"] 
    },
    { 
        key = "leave", 
        label = L["KIT_LEAVE"], 
        short = L["KIT_LEAVE_SHORT"], 
        colors = {
            white = {1, 1, 1, 1},
            blizzard = {1, 0.82, 0, 1},
            rainbow = {1, 0.5, 0.5, 1},  -- 红色警示
        },
        order = 70, 
        defaultPinned = true, 
        defaultBindings = { left = "default" }, 
        actions = { { key = "default", label = L["KIT_LEAVE"], tooltip = L["KIT_LEAVE_TOOLTIP"], execute = function() C_PartyInfo.LeaveParty() end } }, 
        tooltip = L["KIT_LEAVE_TOOLTIP"] 
    },
    { 
        key = "emotePanel", 
        label = L["KIT_EMOTE"], 
        short = L["KIT_EMOTE_SHORT"], 
        colors = {
            white = {1, 1, 1, 1},
            blizzard = {1, 0.82, 0, 1},
            rainbow = {1, 1, 1, 1},
        },
        order = 80, 
        defaultPinned = true, 
        defaultBindings = { left = "default" }, 
        actions = { { key = "default", label = L["KIT_EMOTE"], tooltip = L["KIT_EMOTE_TOOLTIP"], execute = function(self) if addon.ToggleEmotePanel then addon:ToggleEmotePanel(self) end end } }, 
        tooltip = L["KIT_EMOTE_TOOLTIP"] 
    },
    { 
        key = "reload", 
        label = L["KIT_RELOAD"], 
        short = L["KIT_RELOAD_SHORT"], 
        colors = {
            white = {1, 1, 1, 1},
            blizzard = {1, 0.82, 0, 1},
            rainbow = {1, 1, 1, 1},
        },
        order = 90, 
        defaultPinned = true, 
        defaultBindings = { left = "default" }, 
        actions = { { key = "default", label = L["KIT_RELOAD"], tooltip = L["KIT_RELOAD_TOOLTIP"], execute = function() ReloadUI() end } }, 
        tooltip = L["KIT_RELOAD_TOOLTIP"] 
    },
}
