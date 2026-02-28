local addonName, addon = ...

local hookedFrames = {}
local addMessageConflictWarned = {}

local function WarnAddMessageConflict(frame)
    if not addon.Warn or not frame then return end
    local name = frame:GetName() or tostring(frame)
    if addMessageConflictWarned[name] then return end
    addMessageConflictWarned[name] = true
    addon:Warn("AddMessage hook chain changed externally on %s", tostring(name))
end

local function SetupChatFrameAddMessageHook(frame)
    if frame._TinyChatonAddMessageHooked then
        if frame.AddMessage ~= frame._TinyChatonAddMessageWrapper then
            WarnAddMessageConflict(frame)
        end
        return
    end
    frame._TinyChatonAddMessageHooked = true

    local orig = frame.AddMessage
    frame._TinyChatonOrigAddMessage = orig

    frame._TinyChatonAddMessageWrapper = function(self, msg, ...)
        if addon.Gateway and addon.Gateway.Display and addon.Gateway.Display.Transform then
            local extraArgs = addon.Utils.PackArgs(...)
            local transformedMsg, r, g, b, transformedExtra = addon.Gateway.Display:Transform(self, msg, extraArgs[1], extraArgs[2], extraArgs[3], extraArgs)
            local outArgs = type(transformedExtra) == "table" and transformedExtra or extraArgs
            if outArgs.n == nil then
                outArgs.n = #outArgs
            end
            outArgs[1], outArgs[2], outArgs[3] = r, g, b
            return orig(self, transformedMsg, addon.Utils.UnpackArgs(outArgs))
        end
        return orig(self, msg, ...)
    end
    frame.AddMessage = frame._TinyChatonAddMessageWrapper

    table.insert(hookedFrames, frame)
end

function addon:UnhookChatFrames()
    for _, frame in ipairs(hookedFrames) do
        if frame._TinyChatonOrigAddMessage then
            if frame.AddMessage ~= frame._TinyChatonAddMessageWrapper then
                WarnAddMessageConflict(frame)
            end
            frame.AddMessage = frame._TinyChatonOrigAddMessage
            frame._TinyChatonOrigAddMessage = nil
            frame._TinyChatonAddMessageHooked = nil
            frame._TinyChatonAddMessageWrapper = nil
        end
    end
    hookedFrames = {}
end

function addon:SetupChatFrameHooks()
    for i = 1, NUM_CHAT_WINDOWS do
        local cf = _G["ChatFrame" .. i]
        if cf and cf.AddMessage then
            SetupChatFrameAddMessageHook(cf)
        end
    end

    if FCF_OpenTemporaryWindow then
        hooksecurefunc("FCF_OpenTemporaryWindow", function(chatFrame)
            if not chatFrame or chatFrame._TinyChatonAddMessageHooked then return end
            if chatFrame.AddMessage then
                SetupChatFrameAddMessageHook(chatFrame)
            else
                chatFrame:HookScript("OnShow", function(self)
                    if not self._TinyChatonAddMessageHooked and self.AddMessage then
                        SetupChatFrameAddMessageHook(self)
                    end
                end)
            end
        end)
    end
end
