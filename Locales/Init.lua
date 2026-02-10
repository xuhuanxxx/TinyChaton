local _, addon = ...

addon.L = setmetatable({}, {
    __index = function(t, k)
        local v = tostring(k)
        t[k] = v
        return v
    end
})
