local addonName, addon = ...

local function NoticeNoop(context)
    return context
end

if addon.StreamHighlighter and addon.StreamHighlighter.RegisterKindHighlighter then
    addon.StreamHighlighter:RegisterKindHighlighter("notice", NoticeNoop)
end
