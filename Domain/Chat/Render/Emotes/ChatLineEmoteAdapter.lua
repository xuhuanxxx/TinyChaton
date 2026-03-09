local addonName, addon = ...

addon.ChatLineEmoteAdapter = addon.ChatLineEmoteAdapter or {}
local Adapter = addon.ChatLineEmoteAdapter

Adapter.enabled = Adapter.enabled == true

function Adapter:Apply(text, r, g, b, extraArgs)
    if not self.enabled then
        return text, r, g, b, extraArgs
    end
    if type(text) ~= "string" then
        return text, r, g, b, extraArgs
    end

    local parser = addon.EmoteParser
    if not parser or type(parser.Parse) ~= "function" then
        return text, r, g, b, extraArgs
    end

    local result = parser:Parse(text)
    return result.renderedText, r, g, b, extraArgs
end

function Adapter:Enable()
    self.enabled = true
end

function Adapter:Disable()
    self.enabled = false
end

return Adapter
