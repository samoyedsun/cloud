local skynet = require "skynet"
local rpc_redis = require "rpc_redis"

local root = {}

function root.get_redis(redis_name, prefix)
    local redis =  rpc_redis.get_redis(redis_name)
    
    local function redis_hset(key)
        return function(id, value)
            redis:hset(prefix..id, key, value)
        end
    end

    local function redis_hget(key)
        return function (id)
            local r = redis:hget(prefix..id, key)
            return r
        end
    end
    local function redis_hget_str(key)
        return function (id)
            local r = redis:hget(prefix ..id, key)
            return r or ""
        end
    end

    local function redis_hget_json(key)
        return function (id)
            local r = redis:hget(prefix ..id, key)
            if not r then
                return 
            end
            return cjson_decode(r)
        end
    end

    local function redis_hget_int(key)
        return function (id)
            local r = redis:hget(prefix ..id, key)
            return tonumber(r) or 0
        end
    end

    local function redis_hset_json(key)
        return function(id, value)
            if not value then
                value = "[]"
            else
                value = cjson_encode(value)
            end
            redis:hset(prefix ..id, key, value)
        end
    end

    local function redis_hincrby(key)
         return function(id, value)
            value = math.floor(value)
            if value > 0 then
                return redis:hincrby(prefix ..id, key, value)
            end
            
            local r = redis:hget(prefix .. id, key)
            r = tonumber(r) or 0

            if value == 0 or tonumber(r) == 0 then            --增减0，　无需任何操作
                return r
            end

            if r + value <= 0 then                  --值小等于0
                value = math.floor(-1 * r)
            end
            return redis:hincrby(prefix ..id, key, value)
        end   
    end

    local function redis_hdel(key)
        return function (id)
            redis:hdel(prefix .. id, key)
        end
    end

    local function redis_get(key)
        return redis:get(key)
    end

    local function redis_set(key, value)
        return redis:set(key, value)
    end

    function redis_del()
        return function (id)
            redis:del(prefix..id)
        end
    end

    local function redis_incrby(key, value)
        return redis:incrby(key, value)
    end

    local function redis_method(name)
        return function (id, ... )
            local f = redis[name]
            return f(redis, prefix .. id, ...)
        end
    end

    local obj = {
        hset = redis_hset,
        hset_json = redis_hset_json,
        hget = redis_hget,
        hget_str = redis_hget_str,
        hget_json = redis_hget_json,
        hget_int = redis_hget_int,

        hincrby = redis_hincrby,
        hdel = redis_hdel,
        del = redis_del,
        set = redis_set,
        get = redis_get,
        incrby = redis_incrby,

        hgetall = redis_method("hgetall"),
        hmset = redis_method("hmset"),
        hmget = redis_method("hmget"),

        smembers = redis_method("smembers"),
        sismember = redis_method("sismember"),
        srem = redis_method("srem"),
        sadd = redis_method("sadd"),
        scard = redis_method("scard"),
    }
    return obj
end


return root