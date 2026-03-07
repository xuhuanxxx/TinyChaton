local addonName, addon = ...

addon.DisplayRenderResult = addon.DisplayRenderResult or {}
local Result = addon.DisplayRenderResult

function Result.Create(displayText, r, g, b, extraArgs, line, debug)
    local value = {
        displayText = type(displayText) == "string" and displayText or "",
        r = type(r) == "number" and r or 1,
        g = type(g) == "number" and g or 1,
        b = type(b) == "number" and b or 1,
        extraArgs = type(extraArgs) == "table" and extraArgs or (addon.Utils and addon.Utils.PackArgs(1, 1, 1) or { 1, 1, 1 }),
        line = type(line) == "table" and line or {},
        debug = type(debug) == "table" and debug or {},
    }

    if addon.ValidateContract then
        addon:ValidateContract("DisplayRenderResult", value)
    end

    return value
end

return Result
