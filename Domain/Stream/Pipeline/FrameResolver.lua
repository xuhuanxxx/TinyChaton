local addonName, addon = ...

addon.FrameResolver = addon.FrameResolver or {}
local Resolver = addon.FrameResolver

local function ResolveFrameName(frame)
    if type(frame) ~= "table" then
        return nil
    end
    if type(frame.GetName) == "function" then
        local ok, name = pcall(frame.GetName, frame)
        if ok and type(name) == "string" and name ~= "" then
            return name
        end
    end
    if type(frame.name) == "string" and frame.name ~= "" then
        return frame.name
    end
    return nil
end

function Resolver:IsEligible(frame, event, mode)
    if type(frame) ~= "table" then
        return false, "frame_missing"
    end
    if type(frame.AddMessage) ~= "function" then
        return false, "frame_no_add_message"
    end

    if type(event) == "string" and event ~= "" and type(frame.IsEventRegistered) == "function" then
        local ok, registered = pcall(frame.IsEventRegistered, frame, event)
        if ok and registered == false then
            return false, "event_not_registered"
        end
    end

    return true, "eligible"
end

function Resolver:ResolveRealtime(frame, event)
    local eligible, reason = self:IsEligible(frame, event, "realtime")
    if not eligible then
        return nil, reason
    end
    return frame, reason
end

function Resolver:ResolveReplay(line)
    if type(line) ~= "table" then
        return nil, "line_missing"
    end

    local frameName = type(line.frameName) == "string" and line.frameName or nil
    if not frameName or frameName == "" then
        return nil, "frame_name_missing"
    end

    local frame = _G[frameName]
    local event = type(line.event) == "string" and line.event or nil
    local eligible, reason = self:IsEligible(frame, event, "replay")
    if not eligible then
        return nil, reason
    end

    return frame, reason
end

function Resolver:GetFrameName(frame)
    return ResolveFrameName(frame)
end
