local addonName, addon = ...
local L = addon.L

-- Colors Registry

addon.Colors = {
    themes = {
        white = {
            order = 10,
            name = L["COLORSET_WHITE"],
            desc = "Uniform white text for all buttons",
            defaultColor = {1, 1, 1, 1}
        },
        blizzard = {
            order = 20,
            name = L["COLORSET_BLIZZARD"],
            desc = "Classic Blizzard gold/yellow text",
            defaultColor = {1, 0.82, 0, 1}
        },
        rainbow = {
            order = 30,
            name = L["COLORSET_RAINBOW"],
            desc = "Distinct colors for each channel and tool",
            colors = {
                CHANNEL = {
                    say = {1, 1, 1, 1},
                    yell = {1, 0.25, 0.25, 1},
                    party = {0.66, 0.66, 1, 1},
                    raid = {1, 0.5, 0, 1},
                    instance = {1, 0.5, 0, 1},
                    battleground = {1, 0.5, 0, 1},
                    guild = {0.25, 1, 0.25, 1},
                    officer = {0.25, 0.75, 0.25, 1},
                    emote = {1, 0.5, 0.25, 1},
                    general = {0.8, 1, 0.8, 1},
                    trade = {1, 0.8, 0.8, 1},
                    localdefense = {0.8, 0.8, 1, 1},
                    lfg = {1, 1, 0.8, 1},
                    services = {0.8, 1, 1, 1},
                    world = {0.8, 0.8, 1, 1},
                    whisper = {1, 0.5, 1, 1},
                    bn_whisper = {0, 1, 0.96, 1},
                },
                KIT = {
                    readyCheck = {1, 1, 1, 1},
                    resetInstances = {1, 1, 1, 1},
                    countdown = {1, 1, 1, 1},
                    roll = {1, 1, 1, 1},
                    macro = {1, 1, 1, 1},
                    leave = {1, 0.5, 0.5, 1},
                    emotePanel = {1, 1, 1, 1},
                    reload = {1, 1, 1, 1},
                }
            }
        },
        red = {
            order = 40,
            name = L["COLORSET_RED"],
            desc = "Red text for all buttons",
            defaultColor = {1, 0, 0, 1}
        },
        blue = {
            order = 50,
            name = L["COLORSET_BLUE"],
            desc = "Blue text for all buttons",
            defaultColor = {0, 0.5, 1, 1}
        },
        green = {
            order = 60,
            name = L["COLORSET_GREEN"],
            desc = "Green text for all buttons",
            defaultColor = {0, 1, 0, 1}
        },
    }
}

-- API Implementation

local Colors = addon.Colors

--- Get color for a specific stream/kit in the specified theme
function addon:GetColor(category, key, theme)
    local default = {1, 1, 1, 1}
    
    local themeData = Colors.themes[theme]
    if not themeData then return default end
    
    if themeData.defaultColor then
        return themeData.defaultColor
    end
    
    if theme == "rainbow" and themeData.colors then
        local categoryColors = themeData.colors[category]
        if categoryColors and categoryColors[key] then
            return categoryColors[key]
        end
        return default
    end
    
    return default
end

function addon:GetChannelColor(streamKey, theme)
    return self:GetColor("CHANNEL", streamKey, theme)
end

function addon:GetKitColor(kitKey, theme)
    return self:GetColor("KIT", kitKey, theme)
end

function addon:GetChannelBaseColor(streamKey)
    return self:GetColor("CHANNEL", streamKey, "rainbow")
end
function addon:GetColorSetOptions()
    if Settings and Settings.CreateControlTextContainer then
        local c = Settings.CreateControlTextContainer()
        local list = {}
        for key, def in pairs(Colors.themes) do
            table.insert(list, { key = key, name = def.name, order = def.order })
        end
        table.sort(list, function(a, b) return (a.order or 0) < (b.order or 0) end)

        for _, item in ipairs(list) do
            c:Add(item.key, item.name)
        end
        return c:GetData()
    end

    local list = {}
    for key, def in pairs(Colors.themes) do
        table.insert(list, { key = key, name = def.name, order = def.order })
    end
    table.sort(list, function(a, b) return (a.order or 0) < (b.order or 0) end)
    return list
end

function addon:GetButtonColor(element)
    local theme = "rainbow"
    if addon.Shelf and addon.Shelf.GetThemeProperty then
        theme = addon.Shelf:GetThemeProperty("colorSet") or "rainbow"
    end

    -- 推断 Category
    local category = "CHANNEL"
    
    if element.type == "kit" then
        category = "KIT"
    elseif element.type == "channel" then
        category = "CHANNEL"
    elseif element.category then
        category = element.category == "kit" and "KIT" or "CHANNEL"
    elseif element.key and Colors.themes.rainbow.colors.KIT[element.key] then
        category = "KIT"
    end

    return addon:GetColor(category, element.key, theme)
end

-- 兼容旧的 ColorSetRegistry 访问
addon.ColorSetRegistry = {
    GetColor = function(self, element, setKey)
        return addon:GetButtonColor(element)
    end,
    GetAllSets = function(self)
        return addon:GetColorSetOptions()
    end
}
