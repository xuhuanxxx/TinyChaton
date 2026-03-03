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
        chatType = "CHANNEL",
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

        local byId = resolver.ResolveDynamicActiveName(stream, { channelId = 77 })
        addon.Tests.AssertEqual(byId.activeName, "Candidate B", "Dynamic active name should prefer channelId resolution")
        addon.Tests.AssertEqual(byId.channelId, 77, "Dynamic active id mismatch")

        local byCandidate = resolver.ResolveDynamicActiveName(stream, {})
        addon.Tests.AssertEqual(byCandidate.activeName, "Candidate B", "Dynamic active name should prefer first joined candidate")
        addon.Tests.AssertEqual(byCandidate.channelId, nil, "Joined candidate should not imply channelId without explicit context")

        _G.GetChannelName = function(arg)
            if arg == 77 then return 77, "Candidate B - Realm" end
            return 0, nil
        end
        local byMessage = resolver.ResolveDynamicActiveName(stream, { channelName = "Incoming Name - Realm" })
        addon.Tests.AssertEqual(byMessage.activeName, "Incoming Name", "Dynamic active name should fall back to incoming channel name")

        local byDefault = resolver.ResolveDynamicActiveName(stream, {})
        addon.Tests.AssertEqual(byDefault.activeName, "Candidate B", "Dynamic active name should fall back to mapped name")

        local full = resolver.FormatDisplayText(stream, "channel", "chat", {
            channelId = 77,
            override = { showNumber = false, nameStyle = "FULL" },
        })
        local shortOne = resolver.FormatDisplayText(stream, "channel", "chat", {
            channelId = 77,
            override = { showNumber = false, nameStyle = "SHORT_ONE" },
        })
        local shortTwo = resolver.FormatDisplayText(stream, "channel", "chat", {
            channelId = 77,
            override = { showNumber = false, nameStyle = "SHORT_TWO" },
        })
        local chatNumberShortOne = resolver.FormatDisplayText(stream, "channel", "chat", {
            channelId = 77,
            override = { showNumber = true, nameStyle = "SHORT_ONE" },
        })
        local chatInvalidStyle = resolver.FormatDisplayText(stream, "channel", "chat", {
            channelId = 77,
            override = { showNumber = false, nameStyle = "INVALID_STYLE" },
        })
        local shelfOverrideFull = resolver.FormatDisplayText(stream, "channel", "shelf", {
            channelId = 77,
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
        local shelfProfileFull = resolver.FormatDisplayText(stream, "channel", "shelf", { channelId = 77 })
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

function addon.Tests.TestRuleMatcherCacheLifecycle()
    local RM = addon.RuleMatcher
    addon.Tests.Assert(type(RM) == "table", "RuleMatcher missing")
    addon.Tests.Assert(type(RM.GetRuleCache) == "function", "RuleMatcher.GetRuleCache missing")
    addon.Tests.Assert(type(RM.ClearCache) == "function", "RuleMatcher.ClearCache missing")
    addon.Tests.Assert(type(RM.ClearAllCaches) == "function", "RuleMatcher.ClearAllCaches missing")
    addon.Tests.Assert(type(RM.GetCacheStats) == "function", "RuleMatcher.GetCacheStats missing")

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

function addon.Tests.TestStreamIndexLookupParity()
    addon.Tests.Assert(type(addon.BuildStreamIndex) == "function", "BuildStreamIndex should exist")
    addon:BuildStreamIndex()
    addon.Tests.Assert(type(addon.STREAM_INDEX) == "table", "STREAM_INDEX should be table")

    local stream = addon:GetStreamByKey("say")
    addon.Tests.Assert(type(stream) == "table", "GetStreamByKey should return stream table")
    addon.Tests.AssertEqual(stream.key, "say", "GetStreamByKey key mismatch")
    addon.Tests.AssertEqual(addon:GetStreamKind("say"), "channel", "GetStreamKind mismatch")
    addon.Tests.AssertEqual(addon:GetStreamGroup("say"), "system", "GetStreamGroup mismatch")
    addon.Tests.Assert(addon:IsChannelStream("say") == true, "IsChannelStream should be true for say")
    addon.Tests.Assert(addon:IsNoticeStream("say") == false, "IsNoticeStream should be false for say")
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

    addon.Tests.Assert(type(addon.STREAM_INDEX) == "table", "STREAM_INDEX should be initialized at load")
    addon.Tests.AssertEqual(addon:GetStreamGroup("say"), "system", "STREAM_INDEX group for 'say' mismatch")
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
    local channels = content.snapshotChannels
    addon.Tests.Assert(type(channels) == "table", "snapshotChannels should be table")

    addon.Tests.AssertEqual(channels.say, true, "System channel 'say' should be snapshotted by default")
    addon.Tests.AssertEqual(channels.whisper, true, "Private channel 'whisper' should be snapshotted by default")
    addon.Tests.AssertEqual(channels.general, true, "Dynamic channel 'general' should be snapshotted by default")
    addon.Tests.AssertEqual(channels.monster_say, false, "Notice alert 'monster_say' should be disabled by default")
end

function addon.Tests.TestNoticeEventToStreamKeyMapping()
    addon.Tests.Assert(type(addon.EVENT_TO_STREAM_KEY) == "table", "EVENT_TO_STREAM_KEY missing")
    addon.Tests.AssertEqual(addon.EVENT_TO_STREAM_KEY.CHAT_MSG_MONSTER_SAY, "monster_say", "monster say event mapping mismatch")
    addon.Tests.AssertEqual(addon.EVENT_TO_STREAM_KEY.CHAT_MSG_RAID_BOSS_EMOTE, "raid_boss_emote", "raid boss emote event mapping mismatch")
end

function addon.Tests.TestValidateChatEventDerivationRequiresNonChannelStreamMapping()
    addon.Tests.Assert(type(addon.ValidateChatEventDerivation) == "function", "ValidateChatEventDerivation missing")
    addon.Tests.Assert(type(addon.EVENT_TO_STREAM_KEY) == "table", "EVENT_TO_STREAM_KEY missing")

    local original = addon.EVENT_TO_STREAM_KEY.CHAT_MSG_MONSTER_SAY
    addon.EVENT_TO_STREAM_KEY.CHAT_MSG_MONSTER_SAY = nil
    local ok = pcall(function()
        addon:ValidateChatEventDerivation()
    end)
    addon.Tests.Assert(ok == false, "ValidateChatEventDerivation should fail when non-channel event stream mapping is missing")
    addon.EVENT_TO_STREAM_KEY.CHAT_MSG_MONSTER_SAY = original
end

function addon.Tests.TestResolveStreamToggleDefaults()
    addon.Tests.Assert(type(addon.ResolveStreamToggle) == "function", "ResolveStreamToggle missing")
    addon.Tests.AssertEqual(addon:ResolveStreamToggle("say", nil, "snapshotDefault", false), true, "say snapshot default mismatch")
    addon.Tests.AssertEqual(addon:ResolveStreamToggle("monster_say", nil, "snapshotDefault", true), false, "monster_say snapshot default mismatch")
    addon.Tests.AssertEqual(addon:ResolveStreamToggle("monster_say", nil, "copyDefault", true), false, "monster_say copy default mismatch")
end

function addon.Tests.TestStreamGroupPartition()
    local systemItems = addon:GetSnapshotChannelsItems("system")
    local noticeItems = addon:GetSnapshotChannelsItems("notice")

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

function addon.Tests.TestChatPipelineStageOrder()
    addon.Tests.Assert(type(addon.ChatPipeline) == "table", "ChatPipeline missing")

    local pipeline = addon.ChatPipeline
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

    local chatData = { metadata = {} }
    pipeline:RunMiddlewares("VALIDATE", chatData)
    pipeline:RunMiddlewares("BLOCK", chatData)
    pipeline:RunMiddlewares("TRANSFORM", chatData)
    pipeline:RunMiddlewares("PERSIST", chatData)

    addon.Tests.AssertEqual(table.concat(order, ","), "VALIDATE,BLOCK,TRANSFORM,PERSIST", "ChatPipeline stage order mismatch")

    addon.Can = oldCan
    pipeline.middlewares = original
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
        writeDefaults = { "chat.content.snapshotChannels" },
    })

    addon.db.profile.chat.content.snapshotChannels = { say = false, whisper = false, general = false }
    addon.SettingsReset:ResetPage("__test_chat")
    local byPage = addon.Utils.DeepCopy(addon.db.profile.chat.content.snapshotChannels)

    addon.db.profile.chat.content.snapshotChannels = { say = false }
    addon.SettingsReset:ResetAllProfile()
    local byAll = addon.db.profile.chat.content.snapshotChannels

    local expected = addon.DEFAULTS.profile.chat.content.snapshotChannels
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
