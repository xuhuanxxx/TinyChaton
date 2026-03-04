local addonName, addon = ...

local function BuildValidRegistry()
    return {
        CHANNEL = {
            SYSTEM = {
                {
                    key = "say",
                    kind = "channel",
                    group = "system",
                    wowChatType = "SAY",
                    events = { "CHAT_MSG_SAY" },
                    priority = 100,
                    identity = {
                        labelKey = "STREAM_SAY_LABEL",
                        shortOneKey = "STREAM_SAY_SHORT_ONE",
                        shortTwoKey = "STREAM_SAY_SHORT_TWO",
                    },
                    capabilities = {
                        inbound = true,
                        outbound = true,
                        snapshotDefault = true,
                        copyDefault = true,
                        supportsMute = false,
                        supportsAutoJoin = false,
                        pinnable = true,
                    },
                    defaultBindings = { left = "send" },
                },
            },
            DYNAMIC = {
                {
                    key = "general",
                    kind = "channel",
                    group = "dynamic",
                    wowChatType = "CHANNEL",
                    events = { "CHAT_MSG_CHANNEL" },
                    priority = 200,
                    identity = {
                        labelKey = "STREAM_GENERAL_LABEL",
                        shortOneKey = "STREAM_GENERAL_SHORT_ONE",
                        shortTwoKey = "STREAM_GENERAL_SHORT_TWO",
                        candidatesId = "general",
                    },
                    capabilities = {
                        inbound = true,
                        outbound = true,
                        snapshotDefault = true,
                        copyDefault = true,
                        supportsMute = true,
                        supportsAutoJoin = true,
                        pinnable = true,
                    },
                    defaultBindings = { left = "send", right = "mute_toggle" },
                    defaultAutoJoin = true,
                },
            },
        },
        NOTICE = {
            SYSTEM = {
                {
                    key = "system_notice",
                    kind = "notice",
                    group = "system",
                    wowChatType = "SYSTEM",
                    events = { "CHAT_MSG_SYSTEM" },
                    priority = 300,
                    identity = {
                        labelKey = "STREAM_SYSTEM_NOTICE_LABEL",
                        shortOneKey = "STREAM_SYSTEM_NOTICE_SHORT_ONE",
                        shortTwoKey = "STREAM_SYSTEM_NOTICE_SHORT_TWO",
                    },
                    capabilities = {
                        inbound = true,
                        outbound = false,
                        snapshotDefault = true,
                        copyDefault = true,
                        supportsMute = false,
                        supportsAutoJoin = false,
                        pinnable = false,
                    },
                },
            },
        },
    }
end

local function CompileExpectFail(registry)
    local ok = pcall(function()
        addon.StreamRegistryCompiler:Compile(registry)
    end)
    addon.Tests.Assert(ok == false, "compiler should fail")
end

function addon.Tests.TestStreamRegistryCompilerRejectsMissingKind()
    local registry = BuildValidRegistry()
    registry.CHANNEL.SYSTEM[1].kind = nil
    CompileExpectFail(registry)
end

function addon.Tests.TestStreamRegistryCompilerRejectsNoticeOutbound()
    local registry = BuildValidRegistry()
    registry.NOTICE.SYSTEM[1].capabilities.outbound = true
    CompileExpectFail(registry)
end

function addon.Tests.TestStreamRegistryCompilerRejectsDuplicateKey()
    local registry = BuildValidRegistry()
    registry.CHANNEL.DYNAMIC[1].key = "say"
    CompileExpectFail(registry)
end

function addon.Tests.TestStreamRegistryCompilerRejectsDuplicateEventMapping()
    local registry = BuildValidRegistry()
    registry.NOTICE.SYSTEM[1].events = { "CHAT_MSG_SAY" }
    CompileExpectFail(registry)
end

function addon.Tests.TestStreamRegistryCompilerOutputIsFrozen()
    local compiled = addon.StreamRegistryCompiler:Compile(BuildValidRegistry())
    local ok = pcall(function()
        compiled.__test_mutation = true
    end)
    addon.Tests.Assert(ok == false, "compiled output should be frozen")
end
