local addonName, addon = ...

addon.DynamicChannelResolver = addon.DynamicChannelResolver or {}

local Resolver = addon.DynamicChannelResolver
local GetChannelList = GetChannelList
local GetTime = GetTime

local channelListCache = {
    data = nil,
    timestamp = 0,
    TTL = 1,
}

function Resolver:GetCachedChannelList()
    local now = GetTime()
    if not channelListCache.data or (now - channelListCache.timestamp) > channelListCache.TTL then
        channelListCache.data = { GetChannelList() }
        channelListCache.timestamp = now
    end
    return channelListCache.data
end

function Resolver:InvalidateCache()
    channelListCache.data = nil
    channelListCache.timestamp = 0
end
