local addonName, addon = ...

local Container = {}
Container.__index = Container

local function BuildError(chain, name, reason)
    local path = table.concat(chain, " -> ")
    if path ~= "" then
        path = path .. " -> "
    end
    return string.format("[DI] failed resolving %s%s: %s", path, tostring(name), tostring(reason))
end

function Container:New()
    local o = {
        _registrations = {},
        _singletons = {},
        _frozen = false,
    }
    return setmetatable(o, self)
end

function Container:_assertMutable(name)
    if self._frozen then
        error(string.format("[DI] container frozen; cannot register '%s'", tostring(name)))
    end
    if type(name) ~= "string" or name == "" then
        error("[DI] registration name must be a non-empty string")
    end
    if self._registrations[name] then
        error(string.format("[DI] duplicate registration '%s'", name))
    end
end

function Container:RegisterValue(name, value)
    self:_assertMutable(name)
    self._registrations[name] = {
        kind = "value",
        value = value,
    }
end

function Container:RegisterSingleton(name, factoryFn, deps)
    self:_assertMutable(name)
    if type(factoryFn) ~= "function" then
        error(string.format("[DI] singleton '%s' requires a factory function", tostring(name)))
    end
    self._registrations[name] = {
        kind = "singleton",
        factory = factoryFn,
        deps = deps or {},
    }
end

function Container:RegisterFactory(name, factoryFn, deps)
    self:_assertMutable(name)
    if type(factoryFn) ~= "function" then
        error(string.format("[DI] factory '%s' requires a factory function", tostring(name)))
    end
    self._registrations[name] = {
        kind = "factory",
        factory = factoryFn,
        deps = deps or {},
    }
end

function Container:Has(name)
    -- Registration-existence check only.
    -- Note: Has(name) does not imply Resolve(name) will succeed.
    -- Factories can still fail at build time due to runtime errors.
    return self._registrations[name] ~= nil
end

function Container:Freeze()
    self._frozen = true
end

function Container:_resolve(name, chain, resolving)
    local reg = self._registrations[name]
    if not reg then
        error(BuildError(chain, name, "service not registered"))
    end

    if reg.kind == "value" then
        return reg.value
    end

    if reg.kind == "singleton" and self._singletons[name] ~= nil then
        return self._singletons[name]
    end

    if resolving[name] then
        error(BuildError(chain, name, "circular dependency"))
    end

    resolving[name] = true
    chain[#chain + 1] = name

    local depValues = {}
    for i, depName in ipairs(reg.deps) do
        depValues[i] = self:_resolve(depName, chain, resolving)
    end

    local ok, valueOrErr = pcall(reg.factory, unpack(depValues))
    resolving[name] = nil
    chain[#chain] = nil

    if not ok then
        error(BuildError(chain, name, valueOrErr))
    end

    if reg.kind == "singleton" then
        self._singletons[name] = valueOrErr
    end

    return valueOrErr
end

function Container:Resolve(name)
    return self:_resolve(name, {}, {})
end

function Container:TryResolve(name)
    local ok, result = pcall(self.Resolve, self, name)
    if not ok then
        return nil, result
    end
    return result, nil
end

addon.DIContainer = addon.DIContainer or {}
addon.DIContainer.Container = Container
