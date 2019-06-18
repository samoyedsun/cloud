local skynet = require "skynet"
local redis_sup_handle

local Redis = {
    pool = nil,
}


local function hash_key(key)
    local value = 0
    for i=1, #key do
        value = value + string.byte(key, i)
    end
    return value
end

local function get_uid(key)
    local pos = string.find(key, "uid:")
    if pos then
        return tonumber(string.sub(key, pos + 4, #key))
    end
    return false
end

function Redis:get_db(key)
    local uid = get_uid(key)
    if not uid then
        uid = hash_key(key)
    end
    local dbs = self.pool[uid % #self.pool + 1]
    return dbs[math.random(1, #dbs)]   
end

function Redis:get_redis_pool()
    if self.pool and #self.pool > 0 then
        return
    end
    local pool = skynet.call(".redis", "lua", "acquire", self.name)
    self.pool = {}
    for k, v in pairs(pool) do
        local dbs = {}
        for c, handle in pairs(v) do
            dbs[c] = handle
        end
        self.pool[k] = dbs
    end
end


function Redis:new(name)
    local o = {}
    setmetatable(o, self)
    self.__index = self

    o.name = name
    o.pool = {}
    return o
end


setmetatable(Redis, { __index = function (t, k)
    local cmd = string.lower(k)

    local function f (self, ... )
        self:get_redis_pool()
        local db = self:get_db(select(1, ...))
        return skynet.call(db, "lua", "query", cmd, ...)
    end
    t[k] = f
    return f
end})

local root = {}

local REDIS = {}

function root.get_redis(name)
    local redis = REDIS[name]
    if redis then
        return redis
    end
    local redis = Redis:new(name)
    REDIS[name] = redis
    return redis
end

function root.init(name, cf)
    skynet.call(redis_sup_handle, "lua", "init", name, cf)
end

skynet.init(function ( ... )
    redis_sup_handle = skynet.uniqueservice("srv_redis_sup")
end)
return root 
