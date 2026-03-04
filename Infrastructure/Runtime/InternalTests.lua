local addonName, addon = ...
addon.Tests = {}

--- Assertions
function addon.Tests.Assert(condition, message)
    if not condition then
        error(message or "Assertion failed", 2)
    end
end

function addon.Tests.AssertEqual(actual, expected, message)
    if actual ~= expected then
        error(string.format("%s: Expected %s, got %s", message or "AssertEqual failed", tostring(expected), tostring(actual)), 2)
    end
end

--- Run all tests
function addon.Tests.RunAll()
    print("|cff00ffff[TinyChaton]|r Running tests...")
    local passed = 0
    local failed = 0
    local total = 0

    for name, testFunc in pairs(addon.Tests) do
        if type(testFunc) == "function" and name:match("^Test") then
            total = total + 1
            local status, err = pcall(testFunc)
            if status then
                passed = passed + 1
                -- print("  |cff00ff00✓|r " .. name)
            else
                failed = failed + 1
                print("  |cffff0000✗|r " .. name .. ": " .. err)
            end
        end
    end

    if failed == 0 then
        print(string.format("|cff00ff00[Success]|r All %d tests passed.", total))
    else
        print(string.format("|cffff0000[Failure]|r %d passed, %d failed.", passed, failed))
    end
end

--- Test Cases for Utils

function addon.Tests.TestDeepCopy()
    local orig = { a = 1, b = { c = 2 } }
    local copy = addon.Utils.DeepCopy(orig)
    
    addon.Tests.AssertEqual(copy.a, 1, "Basic property mismatch")
    addon.Tests.AssertEqual(copy.b.c, 2, "Nested property mismatch")
    addon.Tests.Assert(copy ~= orig, "Root table reference identity")
    addon.Tests.Assert(copy.b ~= orig.b, "Nested table reference identity")
    
    -- Cycle check
    local cycle = {}
    cycle.self = cycle
    local cycleCopy = addon.Utils.DeepCopy(cycle)
    addon.Tests.Assert(cycleCopy.self == cycleCopy, "Cycle copy failed")
    addon.Tests.Assert(cycleCopy ~= cycle, "Cycle root identity")
end

function addon.Tests.TestNormalizeChannelName()
    local N = addon.Utils.NormalizeChannelBaseName
    addon.Tests.AssertEqual(N("General"), "General", "Simple name")
    addon.Tests.AssertEqual(N("General - MyServer"), "General", "Server suffix removal")
    addon.Tests.AssertEqual(N("  General - MyServer  "), "General", "Whitespace trimming")
    addon.Tests.AssertEqual(N("Trade (Services)"), "Trade (Services)", "Parentheses usage")
end

function addon.Tests.TestChannelIdentityResolverPriority()
    local resolver = addon.ChannelIdentityResolver
    addon.Tests.Assert(type(resolver) == "table", "ChannelIdentityResolver missing")

    local labelKey = "TEST_STREAM_LABEL"
    local shortOneKey = "TEST_STREAM_SHORT_ONE"
    local shortTwoKey = "TEST_STREAM_SHORT_TWO"
    addon.L[labelKey] = "Test Stream"
    addon.L[shortOneKey] = "T"
    addon.L[shortTwoKey] = "TS"

    local stream = {
        key = "test_stream",
        wowChatType = "CHANNEL",
        identity = {
            labelKey = labelKey,
            shortOneKey = shortOneKey,
            shortTwoKey = shortTwoKey,
            candidatesId = "test_stream",
        },
    }

    local oldGetChannelNameApi = _G.GetChannelName
    local oldGetChannelNameMap = addon.ChannelCandidatesRegistry and addon.ChannelCandidatesRegistry.GetChannelName
    local oldBuildCanonicalIndex = addon.ChannelCandidatesRegistry and addon.ChannelCandidatesRegistry.BuildCanonicalIndex
    local ok, err = pcall(function()
        addon.ChannelCandidatesValid = true
        if addon.ChannelCandidatesRegistry then
            addon.ChannelCandidatesRegistry.GetChannelName = function(_, _, candidatesId)
                if candidatesId == "test_stream" then
                    return "Candidate B"
                end
                return nil
            end
            addon.ChannelCandidatesRegistry.BuildCanonicalIndex = function()
                return {
                    ["candidate b"] = "test_stream",
                }
            end
        end
        _G.GetChannelName = function(arg)
            if arg == 77 then return 77, "Candidate B - Realm" end
            if arg == "Candidate B" then return 55, "Candidate B - Realm" end
            return 0, nil
        end

        local byId = resolver.ResolveDynamicActiveName(stream, { streamMeta = { channelId = 77 } })
        addon.Tests.AssertEqual(byId.activeName, "Candidate B", "Dynamic active name should prefer channelId resolution")
        addon.Tests.AssertEqual(byId.channelId, 77, "Dynamic active id mismatch")

        local byCandidate = resolver.ResolveDynamicActiveName(stream, {})
        addon.Tests.AssertEqual(byCandidate.activeName, "Candidate B", "Dynamic active name should prefer first joined candidate")
        addon.Tests.AssertEqual(byCandidate.channelId, nil, "Joined candidate should not imply channelId without explicit context")

        _G.GetChannelName = function(arg)
            if arg == 77 then return 77, "Candidate B - Realm" end
            return 0, nil
        end
        local byMessage = resolver.ResolveDynamicActiveName(stream, { streamMeta = { channelBaseName = "Incoming Name - Realm" } })
        addon.Tests.AssertEqual(byMessage.activeName, "Incoming Name", "Dynamic active name should fall back to incoming channel name")

        local byDefault = resolver.ResolveDynamicActiveName(stream, {})
        addon.Tests.AssertEqual(byDefault.activeName, "Candidate B", "Dynamic active name should fall back to mapped name")

        local full = resolver.FormatDisplayText(stream, "channel", "chat", {
            streamMeta = { channelId = 77 },
            override = { showNumber = false, nameStyle = "FULL" },
        })
        local shortOne = resolver.FormatDisplayText(stream, "channel", "chat", {
            streamMeta = { channelId = 77 },
            override = { showNumber = false, nameStyle = "SHORT_ONE" },
        })
        local shortTwo = resolver.FormatDisplayText(stream, "channel", "chat", {
            streamMeta = { channelId = 77 },
            override = { showNumber = false, nameStyle = "SHORT_TWO" },
        })
        local chatNumberShortOne = resolver.FormatDisplayText(stream, "channel", "chat", {
            streamMeta = { channelId = 77 },
            override = { showNumber = true, nameStyle = "SHORT_ONE" },
        })
        local chatInvalidStyle = resolver.FormatDisplayText(stream, "channel", "chat", {
            streamMeta = { channelId = 77 },
            override = { showNumber = false, nameStyle = "INVALID_STYLE" },
        })
        local shelfOverrideFull = resolver.FormatDisplayText(stream, "channel", "shelf", {
            streamMeta = { channelId = 77 },
            override = { showNumber = false, nameStyle = "FULL" },
        })
        local oldShelfStyle = addon.db
            and addon.db.profile
            and addon.db.profile.shelf
            and addon.db.profile.shelf.visual
            and addon.db.profile.shelf.visual.display
            and addon.db.profile.shelf.visual.display.nameStyle
        if addon.db and addon.db.profile and addon.db.profile.shelf and addon.db.profile.shelf.visual and addon.db.profile.shelf.visual.display then
            addon.db.profile.shelf.visual.display.nameStyle = "FULL"
        end
        local shelfProfileFull = resolver.FormatDisplayText(stream, "channel", "shelf", {
            streamMeta = { channelId = 77 },
        })
        if addon.db and addon.db.profile and addon.db.profile.shelf and addon.db.profile.shelf.visual and addon.db.profile.shelf.visual.display then
            addon.db.profile.shelf.visual.display.nameStyle = oldShelfStyle
        end
        addon.Tests.AssertEqual(full, "Candidate B", "FULL format mismatch")
        addon.Tests.AssertEqual(shortOne, "T", "SHORT_ONE format mismatch")
        addon.Tests.AssertEqual(shortTwo, "TS", "SHORT_TWO format mismatch")
        addon.Tests.AssertEqual(chatNumberShortOne, "77.T", "chat display policy number+short mismatch")
        addon.Tests.AssertEqual(chatInvalidStyle, "T", "chat invalid style should normalize to SHORT_ONE")
        addon.Tests.AssertEqual(shelfOverrideFull, "T", "shelf override FULL should normalize to SHORT_ONE")
        addon.Tests.AssertEqual(shelfProfileFull, "T", "shelf profile FULL should normalize to SHORT_ONE")
    end)
    _G.GetChannelName = oldGetChannelNameApi
    if addon.ChannelCandidatesRegistry then
        addon.ChannelCandidatesRegistry.GetChannelName = oldGetChannelNameMap
        addon.ChannelCandidatesRegistry.BuildCanonicalIndex = oldBuildCanonicalIndex
    end
    if not ok then error(err, 0) end
end

function addon.Tests.TestChannelCandidatesRegistryValidation()
    local registry = addon.ChannelCandidatesRegistry
    addon.Tests.Assert(type(registry) == "table", "ChannelCandidatesRegistry missing")
    addon.Tests.Assert(type(registry.Validate) == "function", "ChannelCandidatesRegistry.Validate missing")

    local old = addon.CHANNEL_CANDIDATES
    local oldAliases = addon.CHANNEL_CANDIDATE_ALIASES
    local ok, err = pcall(function()
        addon.CHANNEL_CANDIDATES = {
            default = {
                general = "General",
                trade = "Trade",
                localdefense = "LocalDefense",
                services = "Service",
                lfg = "LFG",
                world = "World",
            },
        }
        addon.CHANNEL_CANDIDATE_ALIASES = {
            default = {
                services = { "Trade (Services)" },
            },
        }
        local valid, errs = registry:Validate("enUS")
        addon.Tests.Assert(valid == true, "Validate should pass on non-conflicting candidates")
        addon.Tests.Assert(type(errs) == "table", "Validate should return error table")

        addon.CHANNEL_CANDIDATES = {
            default = {
                general = "General",
                trade = "Trade",
                localdefense = "LocalDefense",
                services = "Trade",
                lfg = "LFG",
                world = "World",
            },
        }
        addon.CHANNEL_CANDIDATE_ALIASES = {
            default = {
                services = { "Trade (Services)" },
                lfg = { "Trade (Services)" },
            },
        }
        valid, errs = registry:Validate("enUS")
        addon.Tests.Assert(valid == false, "Validate should fail on duplicated alias")
        addon.Tests.Assert(type(errs) == "table" and #errs > 0, "Validate should return conflict details")
    end)
    addon.CHANNEL_CANDIDATES = old
    addon.CHANNEL_CANDIDATE_ALIASES = oldAliases
    if not ok then error(err, 0) end
end

function addon.Tests.TestTradeServicesSeparation()
    local resolver = addon.ChannelIdentityResolver
    addon.Tests.Assert(type(resolver) == "table", "ChannelIdentityResolver missing")

    local oldGetChannelNameMap = addon.ChannelCandidatesRegistry and addon.ChannelCandidatesRegistry.GetChannelName
    local oldGetChannelAliases = addon.ChannelCandidatesRegistry and addon.ChannelCandidatesRegistry.GetChannelAliases
    local oldBuildPrimaryCanonicalIndex = addon.ChannelCandidatesRegistry and addon.ChannelCandidatesRegistry.BuildPrimaryCanonicalIndex
    local oldBuildMessageCanonicalIndex = addon.ChannelCandidatesRegistry and addon.ChannelCandidatesRegistry.BuildMessageCanonicalIndex
    local oldBuildCanonicalIndex = addon.ChannelCandidatesRegistry and addon.ChannelCandidatesRegistry.BuildCanonicalIndex
    local oldGetChannelNameApi = _G.GetChannelName
    local ok, err = pcall(function()
        addon.ChannelCandidatesValid = true
        if addon.ChannelCandidatesRegistry then
            addon.ChannelCandidatesRegistry.GetChannelName = function(_, _, candidatesId)
                if candidatesId == "trade" then
                    return "Trade"
                end
                if candidatesId == "services" then
                    return "Service"
                end
                return nil
            end
            addon.ChannelCandidatesRegistry.GetChannelAliases = function(_, _, candidatesId)
                if candidatesId == "services" then
                    return { "Trade (Services)" }
                end
                return {}
            end
            addon.ChannelCandidatesRegistry.BuildPrimaryCanonicalIndex = function()
                return {
                    ["trade"] = "trade",
                    ["service"] = "services",
                }
            end
            addon.ChannelCandidatesRegistry.BuildMessageCanonicalIndex = function()
                return {
                    ["trade"] = "trade",
                    ["service"] = "services",
                    ["trade(services)"] = "services",
                }
            end
            addon.ChannelCandidatesRegistry.BuildCanonicalIndex = function()
                return {
                    ["trade"] = "trade",
                    ["service"] = "services",
                }
            end
        end

        _G.GetChannelName = function(arg)
            if arg == "Trade" then return 2, "Trade - Realm" end
            if arg == "Service" then return 4, "Service - Realm" end
            return 0, nil
        end

        local trade = addon:GetStreamByKey("trade")
        local services = addon:GetStreamByKey("services")
        addon.Tests.Assert(type(trade) == "table", "Trade stream missing")
        addon.Tests.Assert(type(services) == "table", "Services stream missing")

        local tradeIdentity = resolver.ResolveDynamicActiveName(trade, {})
        local servicesIdentity = resolver.ResolveDynamicActiveName(services, {})
        addon.Tests.AssertEqual(tradeIdentity.channelId, 2, "Trade should resolve to channel 2")
        addon.Tests.AssertEqual(servicesIdentity.channelId, 4, "Services should resolve to channel 4")

        _G.GetChannelName = function(arg)
            if arg == "Trade" then return 2, "Trade - Realm" end
            if arg == "Service" then return 4, "Service - Realm" end
            if arg == "Trade (Services)" then return 0, nil end
            return 0, nil
        end
        local key = addon:ResolveStreamKey("CHAT_MSG_CHANNEL", nil, nil, nil, nil, nil, nil, nil, nil, "Trade (Services)")
        addon.Tests.AssertEqual(key, "services", "Message alias should map to services")
    end)
    _G.GetChannelName = oldGetChannelNameApi
    if addon.ChannelCandidatesRegistry then
        addon.ChannelCandidatesRegistry.GetChannelName = oldGetChannelNameMap
        addon.ChannelCandidatesRegistry.GetChannelAliases = oldGetChannelAliases
        addon.ChannelCandidatesRegistry.BuildPrimaryCanonicalIndex = oldBuildPrimaryCanonicalIndex
        addon.ChannelCandidatesRegistry.BuildMessageCanonicalIndex = oldBuildMessageCanonicalIndex
        addon.ChannelCandidatesRegistry.BuildCanonicalIndex = oldBuildCanonicalIndex
    end
    if not ok then error(err, 0) end
end

function addon.Tests.TestResolveByChannelIdUsesPrimaryOnly()
    local semantic = addon.ChannelSemanticResolver
    addon.Tests.Assert(type(semantic) == "table", "ChannelSemanticResolver missing")
    addon.Tests.Assert(type(semantic.ResolveStreamKey) == "function", "ResolveStreamKey missing")

    local oldBuildPrimaryCanonicalIndex = addon.ChannelCandidatesRegistry and addon.ChannelCandidatesRegistry.BuildPrimaryCanonicalIndex
    local oldBuildMessageCanonicalIndex = addon.ChannelCandidatesRegistry and addon.ChannelCandidatesRegistry.BuildMessageCanonicalIndex
    local oldBuildCanonicalIndex = addon.ChannelCandidatesRegistry and addon.ChannelCandidatesRegistry.BuildCanonicalIndex
    local oldGetChannelNameApi = _G.GetChannelName
    local ok, err = pcall(function()
        if addon.ChannelCandidatesRegistry then
            addon.ChannelCandidatesRegistry.BuildPrimaryCanonicalIndex = function()
                return {
                    ["trade"] = "trade",
                    ["service"] = "services",
                }
            end
            addon.ChannelCandidatesRegistry.BuildMessageCanonicalIndex = function()
                return {
                    ["trade"] = "trade",
                    ["service"] = "services",
                    ["trade(services)"] = "services",
                }
            end
            addon.ChannelCandidatesRegistry.BuildCanonicalIndex = function()
                return {
                    ["trade"] = "trade",
                    ["service"] = "services",
                }
            end
        end

        _G.GetChannelName = function(arg)
            if arg == 77 then return 77, "Trade (Services)" end
            return 0, nil
        end

        local byIdOnly = semantic.ResolveStreamKey({ channelId = 77 })
        addon.Tests.AssertEqual(byIdOnly, "unknown_dynamic", "Availability/id path must ignore alias-only names")

        local byName = semantic.ResolveStreamKey({ channelName = "Trade (Services)" })
        addon.Tests.AssertEqual(byName, "services", "Message/name path should allow alias names")
    end)

    _G.GetChannelName = oldGetChannelNameApi
    if addon.ChannelCandidatesRegistry then
        addon.ChannelCandidatesRegistry.BuildPrimaryCanonicalIndex = oldBuildPrimaryCanonicalIndex
        addon.ChannelCandidatesRegistry.BuildMessageCanonicalIndex = oldBuildMessageCanonicalIndex
        addon.ChannelCandidatesRegistry.BuildCanonicalIndex = oldBuildCanonicalIndex
    end
    if not ok then error(err, 0) end
end

function addon.Tests.TestSnapshotKeyDynamicCandidates()
    local world = addon:GetStreamByKey("world")
    addon.Tests.Assert(type(world) == "table", "World stream missing")
    local identity = addon.ResolveStreamIdentity and addon:ResolveStreamIdentity(world, {}) or nil
    addon.Tests.Assert(type(identity) == "table", "World identity missing")
    addon.Tests.Assert(type(identity.candidates) == "table" and #identity.candidates > 0, "World candidates missing")

    local candidate = identity.candidates[1]
    local key = addon:ResolveStreamKey("CHAT_MSG_CHANNEL", nil, nil, nil, nil, nil, nil, nil, nil, candidate)
    addon.Tests.AssertEqual(key, "world", "Snapshot key should resolve dynamic candidate to world")
end

function addon.Tests.TestNamePolicyAndAvailability()
    addon.Tests.Assert(type(addon.NamePolicy) == "table", "NamePolicy missing")
    addon.Tests.Assert(type(addon.NamePolicy.Resolve) == "function", "NamePolicy.Resolve missing")
    addon.Tests.Assert(type(addon.AvailabilityResolver) == "table", "AvailabilityResolver missing")
    addon.Tests.Assert(type(addon.AvailabilityResolver.Resolve) == "function", "AvailabilityResolver.Resolve missing")

    local world = addon:GetStreamByKey("world")
    addon.Tests.Assert(type(world) == "table", "World stream missing")
    local named = addon.NamePolicy.Resolve(world, "channel", {})
    addon.Tests.Assert(type(named) == "table", "NamePolicy.Resolve should return table")
    addon.Tests.Assert(type(named.label) == "string" and named.label ~= "", "NamePolicy label missing")
    addon.Tests.Assert(type(named.shortOne) == "string" and named.shortOne ~= "", "NamePolicy shortOne missing")
    addon.Tests.Assert(type(named.shortTwo) == "string" and named.shortTwo ~= "", "NamePolicy shortTwo missing")

    local sys = addon:GetStreamByKey("say")
    local sysAvailability = addon.AvailabilityResolver.Resolve(sys and sys.key, "channel", {})
    addon.Tests.AssertEqual(sysAvailability.state, "ready", "System channel should be ready")
    addon.Tests.Assert(sysAvailability.available == true, "System channel should be available")
end

function addon.Tests.TestPool()
    local factoryCount = 0
    local resetCount = 0
    
    addon.Pool:Create("TestPool", 
        function() 
            factoryCount = factoryCount + 1
            return { id = factoryCount } 
        end,
        function(obj)
            resetCount = resetCount + 1
            obj.value = nil
        end
    )
    
    -- Acquire new
    local obj1 = addon.Pool:Acquire("TestPool")
    addon.Tests.AssertEqual(obj1.id, 1, "Factory produced correct ID")
    addon.Tests.AssertEqual(factoryCount, 1, "Factory called once")
    
    -- Modifiy and release
    obj1.value = "foo"
    addon.Pool:Release("TestPool", obj1)
    addon.Tests.AssertEqual(resetCount, 1, "Reset called on release")
    
    -- Acquire reused
    local obj2 = addon.Pool:Acquire("TestPool")
    addon.Tests.Assert(obj1 == obj2, "Object reused")
    addon.Tests.Assert(obj2.value == nil, "Object reset")
    addon.Tests.AssertEqual(factoryCount, 1, "Factory not called on reuse")
    
    -- Acquire another
    local obj3 = addon.Pool:Acquire("TestPool")
    addon.Tests.AssertEqual(obj3.id, 2, "New object created when pool empty")
    addon.Tests.AssertEqual(factoryCount, 2, "Factory called again")

    local available, total = addon.Pool:GetStats("TestPool")
    addon.Tests.AssertEqual(available, 0, "Pool available count")
    addon.Tests.AssertEqual(total, 2, "Pool total created count")
end

function addon.Tests.TestStreamRuleMatcherCacheLifecycle()
    local RM = addon.StreamRuleMatcher
    addon.Tests.Assert(type(RM) == "table", "StreamRuleMatcher missing")
    addon.Tests.Assert(type(RM.GetRuleCache) == "function", "StreamRuleMatcher.GetRuleCache missing")
    addon.Tests.Assert(type(RM.ClearCache) == "function", "StreamRuleMatcher.ClearCache missing")
    addon.Tests.Assert(type(RM.ClearAllCaches) == "function", "StreamRuleMatcher.ClearAllCaches missing")
    addon.Tests.Assert(type(RM.GetCacheStats) == "function", "StreamRuleMatcher.GetCacheStats missing")

    local version = (addon.FilterVersion or 0) + 123
    local config = {
        names = { "FooPlayer" },
        keywords = { "Buy gold" },
    }

    local cache = RM.GetRuleCache("blacklist", config, version)
    addon.Tests.Assert(type(cache) == "table", "Rule cache not created")

    local stats = RM.GetCacheStats()
    addon.Tests.AssertEqual(stats.blacklist.version, version, "Blacklist cache version mismatch")
    addon.Tests.Assert(stats.blacklist.namesCount > 0, "Blacklist names cache should be populated")

    addon.Tests.AssertEqual(RM.ClearCache("blacklist"), true, "ClearCache should return true for known mode")
    stats = RM.GetCacheStats()
    addon.Tests.AssertEqual(stats.blacklist.namesCount, 0, "Blacklist names cache should be cleared")
    addon.Tests.AssertEqual(stats.blacklist.keywordsCount, 0, "Blacklist keywords cache should be cleared")

    local cleared = RM.ClearAllCaches()
    addon.Tests.Assert(cleared >= 2, "ClearAllCaches should clear all modes")
end

function addon.Tests.TestRegisterEventIdempotency()
    addon.Tests.Assert(type(addon.InitEvents) == "function", "InitEvents missing")
    addon.Tests.Assert(type(addon.RegisterEvent) == "function", "RegisterEvent missing")

    addon:InitEvents()
    addon.Tests.Assert(type(addon.eventFrame) == "table", "eventFrame missing after InitEvents")

    local eventName = "PLAYER_ENTERING_WORLD"
    local hitCount = 0
    local sameFn = function()
        hitCount = hitCount + 1
    end

    addon:RegisterEvent(eventName, sameFn)
    addon:RegisterEvent(eventName, sameFn)

    local handlers = addon.eventHandlers[eventName] or {}
    addon.Tests.AssertEqual(#handlers, 1, "Duplicate handler should not be inserted")

    local onEvent = addon.eventFrame:GetScript("OnEvent")
    addon.Tests.Assert(type(onEvent) == "function", "OnEvent script missing")
    onEvent(addon.eventFrame, eventName)
    addon.Tests.AssertEqual(hitCount, 1, "Idempotent handler should fire once")

    local secondHitCount = 0
    local otherFn = function()
        secondHitCount = secondHitCount + 1
    end
    addon:RegisterEvent(eventName, otherFn)
    handlers = addon.eventHandlers[eventName] or {}
    addon.Tests.AssertEqual(#handlers, 2, "Distinct handlers should coexist")

    onEvent(addon.eventFrame, eventName)
    addon.Tests.AssertEqual(hitCount, 2, "Primary handler should still run")
    addon.Tests.AssertEqual(secondHitCount, 1, "Secondary handler should run")

    local beforeInvalid = #handlers
    addon:RegisterEvent("", sameFn)
    addon:RegisterEvent(eventName, "not_a_function")
    addon:RegisterEvent(nil, sameFn)
    addon:RegisterEvent(eventName, nil)
    local afterInvalid = #(addon.eventHandlers[eventName] or {})
    addon.Tests.AssertEqual(afterInvalid, beforeInvalid, "Invalid inputs should not mutate handlers")
end

function addon.Tests.TestDIResolveSemantics()
    local containerType = addon.DIContainer and addon.DIContainer.Container
    addon.Tests.Assert(type(containerType) == "table", "DI container type missing")

    local c = containerType:New()
    c:RegisterValue("Ready", 1)
    c:RegisterSingleton("Broken", function()
        error("boom")
    end)

    addon.Tests.AssertEqual(c:Has("Ready"), true, "Has should detect registered service")
    addon.Tests.AssertEqual(c:Has("Missing"), false, "Has should return false for missing service")
    addon.Tests.AssertEqual(c:Resolve("Ready"), 1, "Resolve should return registered value")

    local value, err = c:TryResolve("Broken")
    addon.Tests.Assert(value == nil, "TryResolve should return nil on factory failure")
    addon.Tests.Assert(type(err) == "string" and err ~= "", "TryResolve should return error message")
end

function addon.Tests.TestResolveTemplatePath()
    local Resolve = addon.Utils and addon.Utils.ResolveTemplatePath
    local Validate = addon.Utils and addon.Utils.ValidatePath
    addon.Tests.Assert(type(Resolve) == "function", "ResolveTemplatePath missing")
    addon.Tests.Assert(type(Validate) == "function", "ValidatePath missing")

    addon.Tests.AssertEqual(Resolve("profile.chat.font.size"), "profile.chat.font.size", "Static path should be unchanged")
    addon.Tests.AssertEqual(Resolve("profile.shelf.themes.{theme}.fontSize", { theme = "Modern" }),
        "profile.shelf.themes.Modern.fontSize", "Token path resolution failed")

    local ok = Validate("profile.shelf.themes.Modern.fontSize")
    addon.Tests.Assert(ok == true, "Valid path should pass")

    local invalid
    invalid = Validate("profile..broken.path")
    addon.Tests.Assert(invalid == false, "Path with empty segment should fail")
    invalid = Validate("profile.{bad-token}.font")
    addon.Tests.Assert(invalid == false, "Path with invalid token should fail")
end

function addon.Tests.TestPathAccessorDynamicContext()
    local internals = addon.SettingsRegistryInternals or {}
    addon.Tests.Assert(type(internals.BuildPathAccessor) == "function", "BuildPathAccessor missing")

    addon.db = addon.db or {}
    addon.db.profile = addon.db.profile or {}
    addon.db.profile.shelf = addon.db.profile.shelf or {}
    addon.db.profile.shelf.themes = addon.db.profile.shelf.themes or {}
    addon.db.profile.shelf.themes.Modern = addon.db.profile.shelf.themes.Modern or {}
    addon.db.profile.shelf.themes.Soft = addon.db.profile.shelf.themes.Soft or {}

    local oldTheme = addon.db.profile.shelf.theme
    addon.db.profile.shelf.theme = "Modern"

    local reg = {
        path = "profile.shelf.themes.{theme}.fontSize",
        pathContext = function()
            return { theme = addon.db.profile.shelf.theme }
        end
    }
    local accessor = internals.BuildPathAccessor(reg)
    accessor.set(11)
    addon.Tests.AssertEqual(addon.db.profile.shelf.themes.Modern.fontSize, 11, "Modern theme write failed")

    addon.db.profile.shelf.theme = "Soft"
    accessor.set(22)
    addon.Tests.AssertEqual(addon.db.profile.shelf.themes.Soft.fontSize, 22, "Soft theme write failed")
    addon.Tests.AssertEqual(addon.db.profile.shelf.themes.Modern.fontSize, 11, "Modern theme value should remain unchanged")
    addon.Tests.AssertEqual(accessor.get(), 22, "Dynamic context getter should track current theme")

    addon.db.profile.shelf.theme = oldTheme
end

function addon.Tests.TestRegistryOnChangeHook()
    local internals = addon.SettingsRegistryInternals or {}
    addon.Tests.Assert(type(internals.BuildRegistrySetter) == "function", "BuildRegistrySetter missing")

    local written
    local changed
    local changedCount = 0

    local oldApply = addon.ApplyAllSettings
    local applyCount = 0
    addon.ApplyAllSettings = function()
        applyCount = applyCount + 1
    end

    local reg = {
        normalizeSet = function(v) return v * 2 end,
        onChange = function(v)
            changed = v
            changedCount = changedCount + 1
        end,
        applyAllSettings = false,
    }

    local setter = internals.BuildRegistrySetter(reg, function(v) written = v end)
    setter(3)

    addon.Tests.AssertEqual(written, 6, "normalizeSet should transform value before write")
    addon.Tests.AssertEqual(changed, 6, "onChange should receive normalized value")
    addon.Tests.AssertEqual(changedCount, 1, "onChange should fire once")
    addon.Tests.AssertEqual(applyCount, 0, "applyAllSettings=false should skip ApplyAllSettings")

    local setter2 = internals.BuildRegistrySetter({}, function() end)
    setter2(1)
    addon.Tests.AssertEqual(applyCount, 1, "Default setter should call ApplyAllSettings")

    addon.ApplyAllSettings = oldApply
end

function addon.Tests.TestRegistryDefaultIsRuntimeResolved()
    local internals = addon.SettingsRegistryInternals or {}
    addon.Tests.Assert(type(internals.ResolveRegistryValue) == "function", "ResolveRegistryValue missing")

    addon.__testRuntimeDefault = 10
    local reg = {
        default = function()
            return addon.__testRuntimeDefault
        end
    }

    local first = internals.ResolveRegistryValue(reg, function() return nil end, {}, -1)
    addon.Tests.AssertEqual(first, 10, "First runtime default mismatch")

    addon.__testRuntimeDefault = 42
    local second = internals.ResolveRegistryValue(reg, function() return nil end, {}, -1)
    addon.Tests.AssertEqual(second, 42, "Runtime default should reflect latest value")

    addon.__testRuntimeDefault = nil
end

function addon.Tests.TestRegistryNoGetterUsesRuntimeDefault()
    addon.SETTING_REGISTRY = addon.SETTING_REGISTRY or {}
    local key = "__test_runtime_default_no_getter"
    local oldReg = addon.SETTING_REGISTRY[key]

    local oldAddProxySlider = addon.AddProxySlider
    local capturedGetter
    addon.AddProxySlider = function(_, _, _, _, _, _, _, getter)
        capturedGetter = getter
        return {}
    end

    addon.__testNoGetterDefault = 5
    addon.SETTING_REGISTRY[key] = {
        default = function() return addon.__testNoGetterDefault end,
        ui = { type = "slider", label = "LABEL_FONT_SIZE", min = 1, max = 100, step = 1 },
    }

    addon.AddRegistrySetting(nil, key)
    addon.Tests.Assert(type(capturedGetter) == "function", "Captured getter missing")
    addon.Tests.AssertEqual(capturedGetter(), 5, "Runtime default getter initial value mismatch")

    addon.__testNoGetterDefault = 9
    addon.Tests.AssertEqual(capturedGetter(), 9, "Runtime default getter should track latest value")

    addon.AddProxySlider = oldAddProxySlider
    addon.SETTING_REGISTRY[key] = oldReg
    addon.__testNoGetterDefault = nil
end

function addon.Tests.TestAppearanceResetRefreshesControls()
    local internals = addon.SettingsRegistryInternals or {}
    addon.Tests.Assert(type(internals.ResolveRegistryValue) == "function", "ResolveRegistryValue missing")

    local reg = addon.SETTING_REGISTRY and addon.SETTING_REGISTRY.themeFontSize
    addon.Tests.Assert(type(reg) == "table", "themeFontSize setting missing")

    addon.db = addon.db or {}
    addon.db.profile = addon.db.profile or {}
    addon.db.profile.shelf = addon.db.profile.shelf or {}
    addon.db.profile.shelf.theme = "Modern"
    addon.db.profile.shelf.themes = {}

    local value = internals.ResolveRegistryValue(reg, function() return nil end, {}, nil)
    addon.Tests.AssertEqual(value, 14, "Appearance default font size should resolve to Modern preset after reset")
end

function addon.Tests.TestPathFallbackPrecedence()
    addon.SETTING_REGISTRY = addon.SETTING_REGISTRY or {}
    local key = "__test_path_precedence"
    local reg = {
        default = false,
        path = "profile.__test.fallback",
        ui = { type = "checkbox", label = "LABEL_ENABLED" },
        get = function() return true end,
        set = function(v) addon.__testPrecedenceValue = v end,
    }

    local oldReg = addon.SETTING_REGISTRY[key]
    addon.SETTING_REGISTRY[key] = reg

    local oldAddProxyCheckbox = addon.AddProxyCheckbox
    local capturedGetter
    local capturedSetter
    addon.AddProxyCheckbox = function(_, _, _, _, getter, setter)
        capturedGetter = getter
        capturedSetter = setter
        return {}
    end

    addon.db = addon.db or {}
    addon.db.profile = addon.db.profile or {}
    addon.db.profile.__test = nil
    addon.__testPrecedenceValue = nil

    addon.AddRegistrySetting(nil, key)
    addon.Tests.Assert(type(capturedGetter) == "function", "Getter should be captured")
    addon.Tests.Assert(type(capturedSetter) == "function", "Setter should be captured")
    addon.Tests.AssertEqual(capturedGetter(), true, "Explicit getter should be preferred over path getter")

    capturedSetter(false)
    addon.Tests.AssertEqual(addon.__testPrecedenceValue, false, "Explicit setter should be preferred over path setter")
    addon.Tests.Assert(addon.db.profile.__test == nil, "Path setter should not run when explicit setter exists")

    addon.AddProxyCheckbox = oldAddProxyCheckbox
    addon.SETTING_REGISTRY[key] = oldReg
    addon.__testPrecedenceValue = nil
end

function addon.Tests.TestCompiledStreamLookupParity()
    local stream = addon:GetStreamByKey("say")
    addon.Tests.Assert(type(stream) == "table", "GetStreamByKey should return stream table")
    addon.Tests.AssertEqual(stream.key, "say", "GetStreamByKey key mismatch")
    addon.Tests.AssertEqual(addon:GetStreamKind("say"), "channel", "GetStreamKind mismatch")
    addon.Tests.AssertEqual(addon:GetStreamGroup("say"), "system", "GetStreamGroup mismatch")
    addon.Tests.Assert(addon:IsChannelStream("say") == true, "IsChannelStream should be true for say")
    addon.Tests.Assert(addon:IsNoticeStream("say") == false, "IsNoticeStream should be false for say")
end

function addon.Tests.TestCompiledAccessorsReturnCopies()
    local stream = addon:GetStreamByKey("say")
    addon.Tests.Assert(type(stream) == "table", "GetStreamByKey should return table")
    stream.kind = "notice"

    local streamAgain = addon:GetStreamByKey("say")
    addon.Tests.AssertEqual(streamAgain.kind, "channel", "GetStreamByKey should return immutable snapshot copy")

    local events = addon:GetChatEvents()
    addon.Tests.Assert(type(events) == "table", "GetChatEvents should return table")
    local originalSize = #events
    events[#events + 1] = "CHAT_MSG_FAKE_MUTATION"

    local eventsAgain = addon:GetChatEvents()
    addon.Tests.AssertEqual(#eventsAgain, originalSize, "GetChatEvents should return copy that cannot mutate source")
end

function addon.Tests.TestDefaultChannelPinsArePinnedBySchema()
    addon.Tests.Assert(type(addon.DEFAULTS) == "table", "DEFAULTS should exist")
    local buttons = addon.DEFAULTS.profile and addon.DEFAULTS.profile.buttons
    addon.Tests.Assert(type(buttons) == "table", "DEFAULTS.profile.buttons should exist")
    local channelPins = buttons.channelPins
    addon.Tests.Assert(type(channelPins) == "table", "DEFAULTS channelPins should be table")

    addon.Tests.AssertEqual(channelPins.say, true, "System channel 'say' should be pinned by default")

    local hasPinnedDynamic = false
    for _, key in ipairs({ "general", "trade", "services", "lfg", "world", "localdefense" }) do
        if channelPins[key] == true then
            hasPinnedDynamic = true
            break
        end
    end
    addon.Tests.Assert(hasPinnedDynamic, "At least one dynamic channel should be pinned by default")

    addon.Tests.AssertEqual(addon:GetStreamGroup("say"), "system", "compiled group for 'say' mismatch")
end

function addon.Tests.TestDefaultAutoJoinDynamicChannelsEnabled()
    addon.Tests.Assert(type(addon.DEFAULTS) == "table", "DEFAULTS should exist")
    local automation = addon.DEFAULTS.profile and addon.DEFAULTS.profile.automation
    addon.Tests.Assert(type(automation) == "table", "DEFAULTS.profile.automation should exist")
    local selections = automation.autoJoinDynamicChannels
    addon.Tests.Assert(type(selections) == "table", "autoJoinDynamicChannels should be table")

    for _, key in ipairs({ "general", "trade", "services", "lfg", "world", "localdefense" }) do
        addon.Tests.AssertEqual(selections[key], true, "Dynamic channel '" .. key .. "' should default to auto-join enabled")
    end
end

function addon.Tests.TestDefaultSnapshotChannelsFromRegistry()
    addon.Tests.Assert(type(addon.DEFAULTS) == "table", "DEFAULTS should exist")
    local content = addon.DEFAULTS.profile and addon.DEFAULTS.profile.chat and addon.DEFAULTS.profile.chat.content
    addon.Tests.Assert(type(content) == "table", "DEFAULTS.profile.chat.content should exist")
    local channels = content.snapshotStreams
    addon.Tests.Assert(type(channels) == "table", "snapshotStreams should be table")

    addon.Tests.AssertEqual(channels.say, true, "System channel 'say' should be snapshotted by default")
    addon.Tests.AssertEqual(channels.whisper, true, "Private channel 'whisper' should be snapshotted by default")
    addon.Tests.AssertEqual(channels.general, true, "Dynamic channel 'general' should be snapshotted by default")
    addon.Tests.AssertEqual(channels.monster_say, false, "Notice alert 'monster_say' should be disabled by default")
end

function addon.Tests.TestNoticeEventToStreamKeyMapping()
    addon.Tests.Assert(type(addon.GetStreamKeyByEvent) == "function", "GetStreamKeyByEvent missing")
    addon.Tests.AssertEqual(addon:GetStreamKeyByEvent("CHAT_MSG_MONSTER_SAY"), "monster_say", "monster say event mapping mismatch")
    addon.Tests.AssertEqual(addon:GetStreamKeyByEvent("CHAT_MSG_RAID_BOSS_EMOTE"), "raid_boss_emote", "raid boss emote event mapping mismatch")
end

function addon.Tests.TestWowChatTypeEventMapping()
    addon.Tests.Assert(type(addon.GetWowChatTypeByEvent) == "function", "GetWowChatTypeByEvent missing")
    addon.Tests.AssertEqual(addon:GetWowChatTypeByEvent("CHAT_MSG_SAY"), "SAY", "SAY wowChatType mapping mismatch")
    addon.Tests.AssertEqual(addon:GetWowChatTypeByEvent("CHAT_MSG_MONSTER_SAY"), "SYSTEM", "SYSTEM wowChatType mapping mismatch")
end

function addon.Tests.TestSnapshotRecordContractUsesWowChatType()
    addon.Tests.Assert(type(addon.StreamContracts) == "table", "StreamContracts missing")
    addon.Tests.Assert(type(addon.StreamContracts.SnapshotRecord) == "table", "SnapshotRecord contract missing")
    addon.Tests.AssertEqual(addon.StreamContracts.SnapshotRecord.wowChatType, "string",
        "SnapshotRecord contract should require wowChatType")
end

function addon.Tests.TestValidateChatEventDerivationRequiresNonChannelStreamMapping()
    addon.Tests.Assert(type(addon.ValidateChatEventDerivation) == "function", "ValidateChatEventDerivation missing")
    local ok = pcall(function()
        addon:ValidateChatEventDerivation()
    end)
    addon.Tests.Assert(ok == true, "ValidateChatEventDerivation should pass for compiled mapping")
end

function addon.Tests.TestResolveStreamToggleDefaults()
    addon.Tests.Assert(type(addon.ResolveStreamToggle) == "function", "ResolveStreamToggle missing")
    addon.Tests.AssertEqual(addon:ResolveStreamToggle("say", nil, "snapshotDefault", false), true, "say snapshot default mismatch")
    addon.Tests.AssertEqual(addon:ResolveStreamToggle("monster_say", nil, "snapshotDefault", true), false, "monster_say snapshot default mismatch")
    addon.Tests.AssertEqual(addon:ResolveStreamToggle("monster_say", nil, "copyDefault", true), false, "monster_say copy default mismatch")
end

function addon.Tests.TestStreamGroupPartition()
    local systemItems = addon:GetSnapshotStreamsItems("system")
    local noticeItems = addon:GetSnapshotStreamsItems("notice")

    local systemSet = {}
    for _, item in ipairs(systemItems or {}) do
        systemSet[item.key] = true
        addon.Tests.AssertEqual(addon:GetStreamKind(item.key), "channel", "system filter should only contain channel streams")
    end
    for _, item in ipairs(noticeItems or {}) do
        addon.Tests.AssertEqual(addon:GetStreamKind(item.key), "notice", "notice filter should only contain notice streams")
        addon.Tests.Assert(systemSet[item.key] ~= true, "system filter should not include notice streams")
    end
end

function addon.Tests.TestResolveStreamKeyUnmappedEventFails()
    local ok = pcall(function()
        addon:ResolveStreamKey("CHAT_MSG_FAKE_EVENT_FOR_TEST")
    end)
    addon.Tests.Assert(ok == false, "unmapped non-channel event should fail")
end

function addon.Tests.TestActionRegistrySendActionDeduplicated()
    addon.Tests.Assert(type(addon.BuildActionRegistryFromDefinitions) == "function", "BuildActionRegistryFromDefinitions missing")
    local registry = addon:BuildActionRegistryFromDefinitions()
    addon.Tests.Assert(type(registry) == "table", "ACTION registry build failed")
    addon.Tests.Assert(registry.send_whisper ~= nil, "send_whisper should exist")
    addon.Tests.Assert(registry.send_emote ~= nil, "send_emote should exist")
    addon.Tests.Assert(registry.whisper_send_whisper == nil, "legacy whisper_send action should be removed")
    addon.Tests.Assert(registry.emote_send_emote == nil, "legacy emote_send action should be removed")
end

function addon.Tests.TestShelfDefaultOrderUsesCompiledStreams()
    addon.Tests.Assert(type(addon.Shelf) == "table", "Shelf missing")
    addon.Tests.Assert(type(addon.Shelf.GetOrder) == "function", "Shelf.GetOrder missing")
    addon.Tests.Assert(addon.db and addon.db.profile and addon.db.profile.buttons, "Buttons DB missing")

    local oldOrder = addon.db.profile.buttons.buttonOrder
    addon.db.profile.buttons.buttonOrder = nil

    local order = addon.Shelf:GetOrder()
    addon.Tests.Assert(type(order) == "table", "Shelf order should be table")
    addon.Tests.Assert(#order > 0, "Shelf order should not be empty")

    local hasSay = false
    local hasAnyKit = false
    local kitKeys = {}
    for _, spec in ipairs(addon.KIT_REGISTRY or {}) do
        kitKeys[spec.key] = true
    end
    for _, key in ipairs(order) do
        if key == "say" then
            hasSay = true
        end
        if kitKeys[key] then
            hasAnyKit = true
        end
    end
    addon.Tests.Assert(hasSay, "Shelf order should include system channel 'say'")
    addon.Tests.Assert(hasAnyKit, "Shelf order should include at least one kit item")

    addon.db.profile.buttons.buttonOrder = oldOrder
end

function addon.Tests.TestMessageFormatterStreamTagLinkPolicy()
    addon.Tests.Assert(type(addon.MessageFormatter) == "table", "MessageFormatter missing")
    addon.Tests.Assert(type(addon.MessageFormatter.GetStreamTag) == "function", "MessageFormatter.GetStreamTag missing")

    local dynamic = addon.MessageFormatter.GetStreamTag({
        wowChatType = "CHANNEL",
        streamKey = "world",
        streamMeta = {
            channelId = 6,
            channelBaseName = "World",
            channelBaseNameNormalized = "world",
        },
    })
    addon.Tests.Assert(type(dynamic) == "string", "Dynamic stream tag should be string")
    addon.Tests.Assert(dynamic:find("|Htinychat:send:world|h", 1, true) ~= nil, "Dynamic outbound stream should link tinychat send action")

    local say = addon.MessageFormatter.GetStreamTag({
        wowChatType = "SAY",
        streamKey = "say",
        kind = "channel",
    })
    addon.Tests.Assert(type(say) == "string", "SAY stream tag should be string")
    addon.Tests.Assert(say:find("|Htinychat:send:say|h", 1, true) ~= nil, "SAY should link tinychat send action")

    local notice = addon.MessageFormatter.GetStreamTag({
        wowChatType = "SYSTEM",
        streamKey = "system",
        kind = "notice",
    })
    addon.Tests.AssertEqual(notice, "", "Notice stream tag should be empty")
end

function addon.Tests.TestMessageFormatterKindFormatterRouting()
    addon.Tests.Assert(type(addon.MessageFormatter) == "table", "MessageFormatter missing")
    addon.Tests.Assert(type(addon.MessageFormatter.RegisterKindFormatter) == "function", "RegisterKindFormatter missing")
    addon.Tests.Assert(type(addon.MessageFormatter.BuildDisplayLine) == "function", "BuildDisplayLine missing")

    local channelText = "hello channel"
    local channelLine, _, _, _ = addon.MessageFormatter.BuildDisplayLine({
        text = channelText,
        author = "Tester",
        wowChatType = "SAY",
        streamKey = "say",
        kind = "channel",
        streamMeta = {},
        time = time(),
    }, { preferTimestampConfig = false })
    addon.Tests.Assert(type(channelLine) == "string", "Channel formatted line should be string")
    addon.Tests.Assert(channelLine:find(channelText, 1, true) ~= nil, "Channel formatted line should include message text")

    local noticeText = "boss warning"
    local noticeLine, _, _, _ = addon.MessageFormatter.BuildDisplayLine({
        text = noticeText,
        wowChatType = "SYSTEM",
        streamKey = "system",
        kind = "notice",
        time = time(),
    }, { preferTimestampConfig = false })
    addon.Tests.AssertEqual(noticeLine, noticeText, "Notice formatted line should passthrough raw text")
end

function addon.Tests.TestMessageFormatterRealtimeLineCarriesWowChatType()
    addon.Tests.Assert(type(addon.MessageFormatter) == "table", "MessageFormatter missing")
    addon.Tests.Assert(type(addon.MessageFormatter.BuildRealtimeLineFromContext) == "function",
        "BuildRealtimeLineFromContext missing")

    local line, err = addon.MessageFormatter.BuildRealtimeLineFromContext({
        event = "CHAT_MSG_SAY",
        text = "hello",
        author = "tester",
        args = {},
        streamKey = "say",
        channelName = nil,
        channelString = nil,
        channelNumber = nil,
    })
    addon.Tests.Assert(err == nil, "BuildRealtimeLineFromContext should not return error for CHAT_MSG_SAY")
    addon.Tests.Assert(type(line) == "table", "BuildRealtimeLineFromContext should return table line")
    addon.Tests.AssertEqual(line.wowChatType, "SAY", "Realtime line should include wowChatType")
end

function addon.Tests.TestMessageFormatterKindFormatterExtensionPoint()
    addon.Tests.Assert(type(addon.MessageFormatter) == "table", "MessageFormatter missing")
    addon.Tests.Assert(type(addon.MessageFormatter.RegisterKindFormatter) == "function", "RegisterKindFormatter missing")
    addon.Tests.Assert(type(addon.MessageFormatter.BuildDisplayLine) == "function", "BuildDisplayLine missing")

    local marker = "__TEST_FMT_KIND__"
    local ok = addon.MessageFormatter.RegisterKindFormatter(marker, function(line)
        return "[test]" .. tostring(line.text), 1, 1, 1
    end)
    addon.Tests.AssertEqual(ok, true, "RegisterKindFormatter should return true for valid formatter")

    local display = addon.MessageFormatter.BuildDisplayLine({
        text = "hello",
        kind = marker,
    })
    addon.Tests.AssertEqual(display, "[test]hello", "Custom kind formatter should be used by BuildDisplayLine")
end

function addon.Tests.TestActionRegistryMuteToggleIncludesSystemStreams()
    addon.Tests.Assert(type(addon.BuildActionRegistryFromDefinitions) == "function", "BuildActionRegistryFromDefinitions missing")
    local registry = addon:BuildActionRegistryFromDefinitions()
    addon.Tests.Assert(type(registry) == "table", "ACTION registry build failed")
    addon.Tests.Assert(registry.mute_toggle_general ~= nil, "mute_toggle_general should exist for dynamic stream")
    addon.Tests.Assert(registry.mute_toggle_say ~= nil, "mute_toggle_say should exist for system stream")
end

function addon.Tests.TestActionRegistrySupportsScopeOnlyRegistration()
    addon.Tests.Assert(type(addon.BuildActionRegistryFromDefinitions) == "function", "BuildActionRegistryFromDefinitions missing")

    local oldDefs = addon.ACTION_DEFINITIONS
    addon.ACTION_DEFINITIONS = {
        {
            key = "scope_only_test",
            label = "scope_only_test",
            category = "channel",
            appliesTo = {
                streamKind = "notice",
                streamGroup = "system",
            },
            execute = function() end,
        },
    }

    local registry = addon:BuildActionRegistryFromDefinitions()
    addon.Tests.Assert(type(registry) == "table", "scope-only ACTION registry build failed")
    addon.Tests.Assert(registry.scope_only_test_system ~= nil,
        "scope-only action should register without streamCapabilities/streamKeys")

    addon.ACTION_DEFINITIONS = oldDefs
end

function addon.Tests.TestStreamEventContextNewSetsStreamKey()
    addon.Tests.Assert(type(addon.StreamEventContext) == "table", "StreamEventContext missing")
    addon.Tests.Assert(type(addon.StreamEventContext.New) == "function", "StreamEventContext.New missing")

    local streamContext = addon.StreamEventContext:New(nil, "CHAT_MSG_SAY", "hello", "Tester")
    addon.Tests.Assert(type(streamContext) == "table", "StreamEventContext.New should return table")
    addon.Tests.AssertEqual(streamContext.streamKey, "say", "StreamEventContext.streamKey should resolve from event mapping")
    addon.StreamEventContext:Release(streamContext)
end

function addon.Tests.TestStreamRuleEngineBlacklistWhitelistApplyToChannelOnly()
    addon.Tests.Assert(type(addon.StreamRuleEngine) == "table", "StreamRuleEngine missing")
    addon.Tests.Assert(type(addon.StreamRuleEngine.EvaluateRealtime) == "function", "StreamRuleEngine.EvaluateRealtime missing")

    local db = addon.db
    addon.Tests.Assert(type(db) == "table" and type(db.profile) == "table", "DB profile missing")
    local oldEnabled = db.enabled
    local oldFilter = addon.Utils.DeepCopy(db.profile.filter)
    db.enabled = true
    db.profile.filter = db.profile.filter or {}
    db.profile.filter.blacklist = { names = {}, keywords = { "danger" } }
    db.profile.filter.whitelist = { names = {}, keywords = { "allow" } }

    db.profile.filter.mode = "blacklist"
    local blackNotice = addon.StreamRuleEngine:EvaluateRealtime({
        text = "danger",
        textLower = "danger",
        author = "npc",
        authorLower = "npc",
        name = "npc",
        streamKey = "system",
        streamKind = "notice",
        metadata = {},
    })
    local blackChannel = addon.StreamRuleEngine:EvaluateRealtime({
        text = "danger",
        textLower = "danger",
        author = "player",
        authorLower = "player",
        name = "player",
        streamKey = "say",
        streamKind = "channel",
        metadata = {},
    })
    addon.Tests.AssertEqual(blackNotice.blocked, false, "Blacklist should ignore notice stream")
    addon.Tests.AssertEqual(blackChannel.blocked, true, "Blacklist should still apply to channel stream")

    db.profile.filter.mode = "whitelist"
    local whiteNotice = addon.StreamRuleEngine:EvaluateRealtime({
        text = "blocked text",
        textLower = "blocked text",
        author = "npc",
        authorLower = "npc",
        name = "npc",
        streamKey = "system",
        streamKind = "notice",
        metadata = {},
    })
    local whiteChannel = addon.StreamRuleEngine:EvaluateRealtime({
        text = "blocked text",
        textLower = "blocked text",
        author = "player",
        authorLower = "player",
        name = "player",
        streamKey = "say",
        streamKind = "channel",
        metadata = {},
    })
    addon.Tests.AssertEqual(whiteNotice.blocked, false, "Whitelist should ignore notice stream")
    addon.Tests.AssertEqual(whiteChannel.blocked, true, "Whitelist should still apply to channel stream")

    db.enabled = oldEnabled
    db.profile.filter = oldFilter
end

function addon.Tests.TestStreamRuleEngineDuplicateAppliesToChannelOnly()
    addon.Tests.Assert(type(addon.StreamRuleEngine) == "table", "StreamRuleEngine missing")
    addon.Tests.Assert(type(addon.StreamRuleEngine.EvaluateRealtime) == "function", "StreamRuleEngine.EvaluateRealtime missing")
    addon.Tests.Assert(type(addon.db) == "table" and type(addon.db.profile) == "table", "DB profile missing")

    local oldEnabled = addon.db.enabled
    local oldContent = addon.Utils.DeepCopy(addon.db.profile.chat and addon.db.profile.chat.content or {})

    addon.db.enabled = true
    addon.db.profile.chat = addon.db.profile.chat or {}
    addon.db.profile.chat.content = addon.db.profile.chat.content or {}
    addon.db.profile.chat.content.repeatFilter = true

    local noticeFirst = addon.StreamRuleEngine:EvaluateRealtime({
        author = "__dup_notice_author",
        text = "__dup_notice_text",
        textLower = "__dup_notice_text",
        streamKey = "system",
        streamKind = "notice",
        metadata = {},
    })
    local noticeSecond = addon.StreamRuleEngine:EvaluateRealtime({
        author = "__dup_notice_author",
        text = "__dup_notice_text",
        textLower = "__dup_notice_text",
        streamKey = "system",
        streamKind = "notice",
        metadata = {},
    })
    addon.Tests.AssertEqual(noticeFirst.blocked, false, "Duplicate should ignore first notice message")
    addon.Tests.AssertEqual(noticeSecond.blocked, false, "Duplicate should ignore notice stream")

    local channelFirst = addon.StreamRuleEngine:EvaluateRealtime({
        author = "__dup_channel_author",
        text = "__dup_channel_text",
        textLower = "__dup_channel_text",
        streamKey = "say",
        streamKind = "channel",
        metadata = {},
    })
    local channelSecond = addon.StreamRuleEngine:EvaluateRealtime({
        author = "__dup_channel_author",
        text = "__dup_channel_text",
        textLower = "__dup_channel_text",
        streamKey = "say",
        streamKind = "channel",
        metadata = {},
    })
    addon.Tests.AssertEqual(channelFirst.blocked, false, "First channel message should pass duplicate filter")
    addon.Tests.AssertEqual(channelSecond.blocked, true, "Second identical channel message should be blocked by duplicate filter")

    addon.db.enabled = oldEnabled
    addon.db.profile.chat.content = oldContent
end

function addon.Tests.TestStreamRuleEngineKindStrategyExtensionPoint()
    addon.Tests.Assert(type(addon.StreamRuleEngine) == "table", "StreamRuleEngine missing")
    addon.Tests.Assert(type(addon.StreamRuleEngine.RegisterKindStrategy) == "function", "RegisterKindStrategy missing")
    addon.Tests.Assert(type(addon.StreamRuleEngine.EvaluateRealtime) == "function", "EvaluateRealtime missing")

    local marker = "__test_notice_strategy__"
    local strategy = {
        EvaluateRealtime = function()
            return {
                blocked = true,
                reasons = { "test.block" },
                metadataPatch = { fromTest = true },
            }
        end,
    }

    local registered = addon.StreamRuleEngine:RegisterKindStrategy(marker, strategy)
    addon.Tests.AssertEqual(registered, true, "RegisterKindStrategy should return true for valid strategy")

    local decision = addon.StreamRuleEngine:EvaluateRealtime({
        streamKind = marker,
        metadata = {},
    })
    addon.Tests.AssertEqual(decision.blocked, true, "Custom kind strategy should affect evaluation")
    addon.Tests.Assert(type(decision.reasons) == "table" and decision.reasons[1] == "test.block",
        "Custom kind strategy reasons should propagate")
end

function addon.Tests.TestHighlightAppliesToChannelOnly()
    addon.Tests.Assert(type(addon.StreamHighlighter) == "table", "StreamHighlighter missing")
    addon.Tests.Assert(type(addon.StreamHighlighter.Apply) == "function", "StreamHighlighter.Apply missing")
    addon.Tests.Assert(type(addon.db) == "table" and type(addon.db.profile) == "table", "DB profile missing")

    addon.db.enabled = true
    local oldFilter = addon.Utils.DeepCopy(addon.db.profile.filter)
    addon.db.profile.filter = addon.db.profile.filter or {}
    addon.db.profile.filter.highlight = {
        enabled = true,
        names = {},
        keywords = { "danger" },
        color = "FF00FF00",
    }

    local noticeContext = {
        text = "|Hplayer:npc|h[npc]|h: danger notice",
        name = "npc",
        authorLower = "npc",
        streamKey = "system",
        streamKind = "notice",
    }
    local noticeResult = addon.StreamHighlighter:Apply(noticeContext)
    addon.Tests.AssertEqual(noticeResult.text, "|Hplayer:npc|h[npc]|h: danger notice", "Highlight should not apply to notice stream")

    local channelContext = {
        text = "|Hplayer:player|h[player]|h: danger channel",
        name = "player",
        authorLower = "player",
        streamKey = "say",
        streamKind = "channel",
    }
    local channelResult = addon.StreamHighlighter:Apply(channelContext)
    addon.Tests.Assert(channelResult.text:find("|cFF00FF00", 1, true) ~= nil, "Channel text should include highlight color tag")

    addon.db.profile.filter = oldFilter
end

function addon.Tests.TestStreamHighlighterKindPluginExtensionPoint()
    addon.Tests.Assert(type(addon.StreamHighlighter) == "table", "StreamHighlighter missing")
    addon.Tests.Assert(type(addon.StreamHighlighter.RegisterKindHighlighter) == "function", "RegisterKindHighlighter missing")
    addon.Tests.Assert(type(addon.StreamHighlighter.Apply) == "function", "Apply missing")

    local marker = "__test_notice_highlighter__"
    local registered = addon.StreamHighlighter:RegisterKindHighlighter(marker, function(context)
        context.text = "[hi]" .. tostring(context.text)
        return context
    end)
    addon.Tests.AssertEqual(registered, true, "RegisterKindHighlighter should return true for valid plugin")

    local out = addon.StreamHighlighter:Apply({
        text = "abc",
        streamKind = marker,
    })
    addon.Tests.AssertEqual(out.text, "[hi]abc", "Custom kind highlighter should be routed by kind")
end

function addon.Tests.TestStreamVisibilityServiceUsesStreamBlocked()
    addon.Tests.Assert(type(addon.StreamVisibilityService) == "table", "StreamVisibilityService missing")
    addon.Tests.Assert(type(addon.StreamVisibilityService.SetStreamBlocked) == "function", "SetStreamBlocked missing")
    addon.Tests.Assert(type(addon.StreamVisibilityService.IsVisibleRealtime) == "function", "IsVisibleRealtime missing")

    local policy = addon.StreamVisibilityService
    local oldFilter = addon.Utils.DeepCopy(addon.db.profile.filter)
    addon.db.profile.filter = addon.db.profile.filter or {}
    addon.db.profile.filter.streamBlocked = {}

    local visibleBefore = policy:IsVisibleRealtime({
        event = "CHAT_MSG_SYSTEM",
        text = "boss warns",
        textLower = "boss warns",
        author = "npc",
        authorLower = "npc",
        streamKey = "system",
        metadata = {},
    })
    addon.Tests.AssertEqual(visibleBefore, true, "Notice should be visible by default")

    policy:SetStreamBlocked("system", true)
    local visibleAfter = policy:IsVisibleRealtime({
        event = "CHAT_MSG_SYSTEM",
        text = "boss warns",
        textLower = "boss warns",
        author = "npc",
        authorLower = "npc",
        streamKey = "system",
        metadata = {},
    })
    addon.Tests.AssertEqual(visibleAfter, false, "Blocked notice stream should be hidden")

    local channelVisibleBefore = policy:IsVisibleRealtime({
        event = "CHAT_MSG_SAY",
        text = "hello",
        textLower = "hello",
        author = "tester",
        authorLower = "tester",
        name = "tester",
        streamKey = "say",
        metadata = {},
    })
    addon.Tests.AssertEqual(channelVisibleBefore, true, "Channel should be visible by default")

    policy:SetStreamBlocked("say", true)
    local channelVisibleAfter = policy:IsVisibleRealtime({
        event = "CHAT_MSG_SAY",
        text = "hello",
        textLower = "hello",
        author = "tester",
        authorLower = "tester",
        name = "tester",
        streamKey = "say",
        metadata = {},
    })
    addon.Tests.AssertEqual(channelVisibleAfter, false, "Blocked channel stream should be hidden")

    addon.db.profile.filter = oldFilter
end

function addon.Tests.TestDynamicMuteWrapperUsesUnifiedStreamBlocked()
    addon.Tests.Assert(type(addon.StreamVisibilityService) == "table", "StreamVisibilityService missing")
    addon.Tests.Assert(type(addon.StreamVisibilityService.ToggleDynamicChannelMute) == "function", "ToggleDynamicChannelMute missing")
    addon.Tests.Assert(type(addon.StreamVisibilityService.IsDynamicChannelMuted) == "function", "IsDynamicChannelMuted missing")

    local policy = addon.StreamVisibilityService
    local oldFilter = addon.Utils.DeepCopy(addon.db.profile.filter)
    addon.db.profile.filter = addon.db.profile.filter or {}
    addon.db.profile.filter.streamBlocked = {}

    local mutedOn = policy:ToggleDynamicChannelMute("general")
    addon.Tests.AssertEqual(mutedOn, true, "Dynamic mute toggle should enable")
    addon.Tests.AssertEqual(policy:IsDynamicChannelMuted("general"), true, "Dynamic mute read should be true")
    addon.Tests.AssertEqual(addon.db.profile.filter.streamBlocked.general, true, "Unified streamBlocked should store dynamic mute")

    local mutedOff = policy:ToggleDynamicChannelMute("general")
    addon.Tests.AssertEqual(mutedOff, false, "Dynamic mute toggle should disable")
    addon.Tests.AssertEqual(policy:IsDynamicChannelMuted("general"), false, "Dynamic mute read should be false")
    addon.Tests.Assert(addon.db.profile.filter.streamBlocked.general == nil, "Unified streamBlocked should clear after unmute")

    addon.db.profile.filter = oldFilter
end

function addon.Tests.TestStreamEventDispatcherStageOrder()
    addon.Tests.Assert(type(addon.StreamEventDispatcher) == "table", "StreamEventDispatcher missing")

    local pipeline = addon.StreamEventDispatcher
    local original = pipeline.middlewares
    local oldCan = addon.Can

    local order = {}
    pipeline.middlewares = {
        VALIDATE = { { name = "v", priority = 10, fn = function() table.insert(order, "VALIDATE") end } },
        BLOCK = { { name = "b", priority = 10, fn = function() table.insert(order, "BLOCK") end } },
        TRANSFORM = { { name = "t", priority = 10, fn = function() table.insert(order, "TRANSFORM") end } },
        PERSIST = { { name = "p", priority = 10, fn = function() table.insert(order, "PERSIST") end } },
    }
    addon.Can = nil

    local streamContext = { metadata = {} }
    pipeline:RunMiddlewares("VALIDATE", streamContext)
    pipeline:RunMiddlewares("BLOCK", streamContext)
    pipeline:RunMiddlewares("TRANSFORM", streamContext)
    pipeline:RunMiddlewares("PERSIST", streamContext)

    addon.Tests.AssertEqual(table.concat(order, ","), "VALIDATE,BLOCK,TRANSFORM,PERSIST", "StreamEventDispatcher stage order mismatch")

    addon.Can = oldCan
    pipeline.middlewares = original
end

function addon.Tests.TestStreamEventFiltersFeatureRegistered()
    addon.Tests.Assert(type(addon.FeatureRegistry) == "table", "FeatureRegistry missing")
    addon.Tests.Assert(type(addon.FeatureRegistry.entries) == "table", "FeatureRegistry.entries missing")
    local entry = addon.FeatureRegistry.entries["StreamEventFilters"]
    addon.Tests.Assert(type(entry) == "table", "StreamEventFilters feature should be registered")
end

function addon.Tests.TestThemeColorOrthogonalResolution()
    addon.Tests.Assert(type(addon.ShelfVisualSpecResolver) == "table", "ShelfVisualSpecResolver missing")

    local spec = addon.ShelfVisualSpecResolver:ResolveButtonVisualSpec({
        key = "say",
        type = "channel",
    }, {})

    addon.Tests.Assert(type(spec) == "table", "Visual spec should be table")
    addon.Tests.Assert(type(spec.themeProps) == "table", "themeProps should be table")
    addon.Tests.Assert(type(spec.textColor) == "table", "textColor should be table")
    addon.Tests.Assert(type(spec.alpha) == "number", "alpha should be number")
    addon.Tests.Assert(type(spec.scale) == "number", "scale should be number")
end

function addon.Tests.TestPerformanceBudgetWarningThrottle()
    addon.Tests.Assert(type(addon.Profiler) == "table", "Profiler missing")

    local profiler = addon.Profiler
    local label = "__test.budget.throttle"
    local oldEnabled = profiler.enabled
    local oldWarn = addon.Warn
    local oldBudget = addon.PERFORMANCE_BUDGET and addon.PERFORMANCE_BUDGET[label] or nil

    addon.PERFORMANCE_BUDGET = addon.PERFORMANCE_BUDGET or {}
    addon.PERFORMANCE_BUDGET[label] = -1
    profiler.lastBudgetWarnAt = profiler.lastBudgetWarnAt or {}
    profiler.lastBudgetWarnAt[label] = 0
    profiler:SetEnabled(true)

    local warnCount = 0
    addon.Warn = function(_, ...)
        warnCount = warnCount + 1
    end

    profiler:Start(label)
    profiler:Stop(label)

    profiler.lastBudgetWarnAt[label] = GetTime()
    profiler:Start(label)
    profiler:Stop(label)

    addon.Tests.AssertEqual(warnCount, 1, "Budget warning should be throttled")

    addon.Warn = oldWarn
    profiler:SetEnabled(oldEnabled)
    if oldBudget == nil then
        addon.PERFORMANCE_BUDGET[label] = nil
    else
        addon.PERFORMANCE_BUDGET[label] = oldBudget
    end
end

function addon.Tests.TestPerformanceBudgetUsesStreamDispatcherKeys()
    addon.Tests.Assert(type(addon.PERFORMANCE_BUDGET) == "table", "PERFORMANCE_BUDGET missing")
    addon.Tests.Assert(type(addon.PERFORMANCE_BUDGET["StreamEventDispatcher.Middleware.BLOCK"]) == "number",
        "StreamEventDispatcher block budget missing")
    addon.Tests.Assert(type(addon.PERFORMANCE_BUDGET["StreamEventDispatcher.Middleware.PERSIST"]) == "number",
        "StreamEventDispatcher persist budget missing")
    local legacyBlockKey = "Chat" .. "Pipeline.Middleware.BLOCK"
    local legacyPersistKey = "Chat" .. "Pipeline.Middleware.PERSIST"
    addon.Tests.Assert(addon.PERFORMANCE_BUDGET[legacyBlockKey] == nil,
        "Legacy stream-dispatcher block budget key should be removed")
    addon.Tests.Assert(addon.PERFORMANCE_BUDGET[legacyPersistKey] == nil,
        "Legacy stream-dispatcher persist budget key should be removed")
end

function addon.Tests.TestGlobalResetAppliesAutoJoinDefaultsFromRegistry()
    addon.Tests.Assert(type(addon.SettingsReset) == "table", "SettingsReset missing")
    addon.Tests.Assert(type(addon.SettingsReset.ResetAllProfile) == "function", "ResetAllProfile missing")
    addon.Tests.Assert(type(addon.DEFAULTS) == "table", "DEFAULTS missing")

    if not addon.db or not addon.db.profile then
        return
    end

    local profile = addon.db.profile
    profile.automation = profile.automation or {}
    profile.automation.autoJoinDynamicChannels = {
        general = true,
        trade = true,
    }

    addon.SettingsReset:ResetAllProfile()

    local after = addon.db.profile.automation.autoJoinDynamicChannels
    addon.Tests.Assert(type(after) == "table", "autoJoinDynamicChannels should remain a table after reset")
    for _, key in ipairs({ "general", "trade", "services", "lfg", "world", "localdefense" }) do
        addon.Tests.AssertEqual(after[key], true, "Global reset should restore auto-join default for '" .. key .. "'")
    end
end

function addon.Tests.TestResetPageVsResetAll_AutomationAutoJoinConsistency()
    addon.Tests.Assert(type(addon.SettingsReset) == "table", "SettingsReset missing")
    addon.Tests.Assert(type(addon.SettingsReset.ResetPage) == "function", "ResetPage missing")
    addon.Tests.Assert(type(addon.SettingsReset.ResetAllProfile) == "function", "ResetAllProfile missing")
    addon.Tests.Assert(type(addon.DEFAULTS) == "table", "DEFAULTS missing")

    local oldSpecs = addon.SettingsReset.pageSpecs
    local oldCategoryMap = addon.SettingsReset.pageKeyByCategoryId
    local oldVariableMap = addon.SettingsReset.pageKeyByVariable
    addon.SettingsReset.pageSpecs = {}
    addon.SettingsReset.pageKeyByCategoryId = {}
    addon.SettingsReset.pageKeyByVariable = {}
    addon.SettingsReset:RegisterPageSpec("__test_automation", {
        writeDefaults = { "automation" },
    })

    addon.db.profile.automation.autoJoinDynamicChannels = { general = false, trade = false, world = false }
    addon.SettingsReset:ResetPage("__test_automation")
    local byPage = addon.Utils.DeepCopy(addon.db.profile.automation.autoJoinDynamicChannels)

    addon.db.profile.automation.autoJoinDynamicChannels = { general = false }
    addon.SettingsReset:ResetAllProfile()
    local byAll = addon.db.profile.automation.autoJoinDynamicChannels

    local expected = addon.DEFAULTS.profile.automation.autoJoinDynamicChannels
    for key, enabled in pairs(expected) do
        addon.Tests.AssertEqual(byPage[key], enabled, "Page reset auto-join default mismatch: " .. tostring(key))
        addon.Tests.AssertEqual(byAll[key], enabled, "Global reset auto-join default mismatch: " .. tostring(key))
    end

    addon.SettingsReset.pageSpecs = oldSpecs
    addon.SettingsReset.pageKeyByCategoryId = oldCategoryMap
    addon.SettingsReset.pageKeyByVariable = oldVariableMap
end

function addon.Tests.TestResetPageVsResetAll_ChatSnapshotConsistency()
    addon.Tests.Assert(type(addon.SettingsReset) == "table", "SettingsReset missing")
    addon.Tests.Assert(type(addon.SettingsReset.ResetPage) == "function", "ResetPage missing")
    addon.Tests.Assert(type(addon.SettingsReset.ResetAllProfile) == "function", "ResetAllProfile missing")
    addon.Tests.Assert(type(addon.DEFAULTS) == "table", "DEFAULTS missing")

    local oldSpecs = addon.SettingsReset.pageSpecs
    local oldCategoryMap = addon.SettingsReset.pageKeyByCategoryId
    local oldVariableMap = addon.SettingsReset.pageKeyByVariable
    addon.SettingsReset.pageSpecs = {}
    addon.SettingsReset.pageKeyByCategoryId = {}
    addon.SettingsReset.pageKeyByVariable = {}
    addon.SettingsReset:RegisterPageSpec("__test_chat", {
        writeDefaults = { "chat.content.snapshotStreams" },
    })

    addon.db.profile.chat.content.snapshotStreams = { say = false, whisper = false, general = false }
    addon.SettingsReset:ResetPage("__test_chat")
    local byPage = addon.Utils.DeepCopy(addon.db.profile.chat.content.snapshotStreams)

    addon.db.profile.chat.content.snapshotStreams = { say = false }
    addon.SettingsReset:ResetAllProfile()
    local byAll = addon.db.profile.chat.content.snapshotStreams

    local expected = addon.DEFAULTS.profile.chat.content.snapshotStreams
    for key, enabled in pairs(expected) do
        addon.Tests.AssertEqual(byPage[key], enabled, "Page reset snapshot default mismatch: " .. tostring(key))
        addon.Tests.AssertEqual(byAll[key], enabled, "Global reset snapshot default mismatch: " .. tostring(key))
    end

    addon.SettingsReset.pageSpecs = oldSpecs
    addon.SettingsReset.pageKeyByCategoryId = oldCategoryMap
    addon.SettingsReset.pageKeyByVariable = oldVariableMap
end

function addon.Tests.TestMultiDropdownSilentRefreshDoesNotWriteBack()
    addon.Tests.Assert(type(TinyChaton_MultiDropdownMixin) == "table", "MultiDropdown mixin missing")
    addon.Tests.Assert(type(TinyChaton_MultiDropdownMixin.SyncSetting) == "function", "SyncSetting missing")

    local oldRefreshSettingValue = addon.RefreshSettingValue
    local called = 0
    local silentFlag = false
    addon.RefreshSettingValue = function(_, _, opts)
        called = called + 1
        silentFlag = opts and opts.silent == true
        return true
    end

    local dummy = {
        var = "__test_multidropdown",
        SerializeSelection = function() return "a,b" end,
        GetSelectionMap = function() return { a = true, b = true } end,
    }
    setmetatable(dummy, { __index = TinyChaton_MultiDropdownMixin })

    dummy:SyncSetting({ a = true, b = true })

    addon.Tests.AssertEqual(called, 1, "Silent setting refresh should be invoked exactly once")
    addon.Tests.Assert(silentFlag, "SyncSetting should use silent refresh to avoid writeback")

    addon.RefreshSettingValue = oldRefreshSettingValue
end

function addon.Tests.TestResetEngineSingleApplyInvocation()
    addon.Tests.Assert(type(addon.SettingsReset) == "table", "SettingsReset missing")
    addon.Tests.Assert(type(addon.SettingsReset.RunReset) == "function", "RunReset missing")

    local applyCount = 0
    local oldApply = addon.ApplyAllSettings
    addon.ApplyAllSettings = function()
        applyCount = applyCount + 1
    end

    addon.SettingsReset:RunReset({
        writeDefaults = {},
        refreshControls = {},
        postRefresh = function() end,
    })

    addon.Tests.AssertEqual(applyCount, 1, "RunReset should call ApplyAllSettings once")
    addon.ApplyAllSettings = oldApply
end

function addon.Tests.TestStreamRegistryDefaultSchemaValidation()
    addon.Tests.Assert(type(addon.ValidateRegistryDefinitions) == "function", "ValidateRegistryDefinitions missing")
    local reg = addon.STREAM_REGISTRY
    addon.Tests.Assert(type(reg) == "table", "STREAM_REGISTRY missing")

    local originalKind = reg.CHANNEL.DYNAMIC[1].kind
    reg.CHANNEL.DYNAMIC[1].kind = nil
    local okKind = pcall(function()
        addon:ValidateRegistryDefinitions()
    end)
    addon.Tests.Assert(okKind == false, "Registry validation should reject missing kind")
    reg.CHANNEL.DYNAMIC[1].kind = originalKind

    local originalGroup = reg.CHANNEL.DYNAMIC[1].group
    reg.CHANNEL.DYNAMIC[1].group = nil
    local okGroup = pcall(function()
        addon:ValidateRegistryDefinitions()
    end)
    addon.Tests.Assert(okGroup == false, "Registry validation should reject missing group")
    reg.CHANNEL.DYNAMIC[1].group = originalGroup

    local originalCaps = reg.CHANNEL.DYNAMIC[1].capabilities
    reg.CHANNEL.DYNAMIC[1].capabilities = nil
    local okCaps = pcall(function()
        addon:ValidateRegistryDefinitions()
    end)
    addon.Tests.Assert(okCaps == false, "Registry validation should reject missing capabilities")
    reg.CHANNEL.DYNAMIC[1].capabilities = originalCaps

    local notice = reg.NOTICE.ALERT[1]
    local originalNoticeOutbound = notice.capabilities.outbound
    notice.capabilities.outbound = true
    local okNoticeOutbound = pcall(function()
        addon:ValidateRegistryDefinitions()
    end)
    addon.Tests.Assert(okNoticeOutbound == false, "Registry validation should reject notice outbound=true")
    notice.capabilities.outbound = originalNoticeOutbound

    local okFinal = pcall(function()
        addon:ValidateRegistryDefinitions()
    end)
    addon.Tests.Assert(okFinal == true, "Registry validation should pass after restoring schema")
end

-- Slash Command
SLASH_TINYCHATON_TEST1 = "/tctest"
SlashCmdList["TINYCHATON_TEST"] = function()
    addon.Tests.RunAll()
end

--- Proxy Performance Benchmark
function addon.Tests.RunProxyBenchmark()
    print("|cff00ffff[TinyChaton]|r Starting Proxy Benchmark (1,000,000 iterations)...")
    
    local iterations = 1000000
    local start = debugprofilestop()
    
    -- Test read access
    local val
    for i = 1, iterations do
        val = addon.db.enabled
    end
    
    local duration = debugprofilestop() - start
    print(string.format("  Proxy Read Time: %.2f ms", duration))
    
    -- Baseline comparison (direct table access)
    local rawTable = { enabled = true }
    start = debugprofilestop()
    for i = 1, iterations do
        val = rawTable.enabled
    end
    local baseline = debugprofilestop() - start
    print(string.format("  Direct Table Time: %.2f ms", baseline))
    
    print(string.format("  Overhead: %.2fx", duration / baseline))

    -- Test nested access (plugin.buttons)
    print("Testing Nested Access (addon.db.profile.buttons)...")
    start = debugprofilestop()
    for i = 1, iterations do
        -- This should be fast with caching, slow without
        val = addon.db.profile.buttons
    end
    duration = debugprofilestop() - start
    print(string.format("  Nested Proxy Time: %.2f ms", duration))
end
