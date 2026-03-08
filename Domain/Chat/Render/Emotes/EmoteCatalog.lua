local addonName, addon = ...

addon.EmoteCatalog = addon.EmoteCatalog or {}
local Catalog = addon.EmoteCatalog

local customEmotes = {
    "Innocent", "Titter", "angel", "angry", "biglaugh", "clap", "cool", "cry", "cutie", "despise",
    "dreamsmile", "embarrass", "evil", "excited", "faint", "fight", "flu", "freeze", "frown", "greet",
    "grimace", "growl", "happy", "heart", "horror", "ill", "kongfu", "love", "mail", "makeup",
    "mario", "meditate", "miserable", "okay", "pretty", "puke", "raiders", "shake", "shout", "shuuuu",
    "shy", "sleep", "smile", "suprise", "surrender", "sweat", "tear", "tears", "think", "ugly",
    "victory", "volunteer", "wronged"
}

local built = false
local catalog = nil
local tokenIndex = nil

local function BuildEntry(key, file)
    return {
        key = key,
        file = file,
        texturePath = file,
        replacementText = string.format("|T%s:0|t", file),
    }
end

local function BuildCatalog()
    local nextCatalog = {
        BuildEntry("{star}", "Interface\\TargetingFrame\\UI-RaidTargetingIcon_1"),
        BuildEntry("{circle}", "Interface\\TargetingFrame\\UI-RaidTargetingIcon_2"),
        BuildEntry("{diamond}", "Interface\\TargetingFrame\\UI-RaidTargetingIcon_3"),
        BuildEntry("{triangle}", "Interface\\TargetingFrame\\UI-RaidTargetingIcon_4"),
        BuildEntry("{moon}", "Interface\\TargetingFrame\\UI-RaidTargetingIcon_5"),
        BuildEntry("{square}", "Interface\\TargetingFrame\\UI-RaidTargetingIcon_6"),
        BuildEntry("{cross}", "Interface\\TargetingFrame\\UI-RaidTargetingIcon_7"),
        BuildEntry("{skull}", "Interface\\TargetingFrame\\UI-RaidTargetingIcon_8"),
    }

    for _, name in ipairs(customEmotes) do
        nextCatalog[#nextCatalog + 1] = BuildEntry(
            string.format("{%s}", name),
            string.format("Interface\\AddOns\\%s\\Media\\Texture\\Emote\\%s.tga", addonName, name)
        )
    end

    local nextIndex = {}
    for _, entry in ipairs(nextCatalog) do
        nextIndex[entry.key] = entry
    end

    catalog = nextCatalog
    tokenIndex = nextIndex
    built = true
end

local function EnsureBuilt()
    if not built then
        BuildCatalog()
    end
end

function Catalog:GetCatalog()
    EnsureBuilt()
    return catalog
end

function Catalog:GetTokenIndex()
    EnsureBuilt()
    return tokenIndex
end

return Catalog
