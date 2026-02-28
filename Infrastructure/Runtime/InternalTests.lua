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
