local addonName, addon = ...

local hookedFrames = {}

local function SetupChatFrameAddMessageHook(frame)
    if frame._TinyChatonAddMessageHooked then return end
    frame._TinyChatonAddMessageHooked = true

    local orig = frame.AddMessage
    frame._TinyChatonOrigAddMessage = orig

    frame.AddMessage = function(self, msg, ...)
        if addon.Gateway and addon.Gateway.Display and addon.Gateway.Display.Transform then
            local transformed = { addon.Gateway.Display:Transform(self, msg, ...) }
            return orig(self, unpack(transformed))
        end
        return orig(self, msg, ...)
    end

    table.insert(hookedFrames, frame)
end

function addon:UnhookChatFrames()
    for _, frame in ipairs(hookedFrames) do
        if frame._TinyChatonOrigAddMessage then
            frame.AddMessage = frame._TinyChatonOrigAddMessage
            frame._TinyChatonOrigAddMessage = nil
            frame._TinyChatonAddMessageHooked = nil
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
