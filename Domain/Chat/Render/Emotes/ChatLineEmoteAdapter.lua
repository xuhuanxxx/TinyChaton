local addonName, addon = ...

addon.ChatLineEmoteAdapter = addon.ChatLineEmoteAdapter or {}
local Adapter = addon.ChatLineEmoteAdapter

Adapter.transformerName = "visual_emotes"
Adapter.enabled = Adapter.enabled == true

local function Transform(_, text, r, g, b, extraArgs)
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
    if self.enabled then
        return
    end

    addon:RegisterChatFrameTransformer(self.transformerName, Transform)
    self.enabled = true
end

function Adapter:Disable()
    if addon.chatFrameTransformers then
        addon.chatFrameTransformers[self.transformerName] = nil
    end
    self.enabled = false
end

return Adapter
