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

    -- Test nested access (plugin.shelf)
    print("Testing Nested Access (addon.db.plugin.shelf)...")
    start = debugprofilestop()
    for i = 1, iterations do
        -- This should be fast with caching, slow without
        val = addon.db.plugin.shelf
    end
    duration = debugprofilestop() - start
    print(string.format("  Nested Proxy Time: %.2f ms", duration))
end
