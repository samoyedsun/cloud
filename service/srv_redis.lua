local skynet = require "skynet"
local redis = require "skynet.db.redis"

local redis_cf, connect_num = ...

local DB_POOL = {}
local logger = log4.get_logger(SERVICE_NAME)

local query_num = 0
local WARN_QUERY_NUM = 10000

local function acquire()
    if #DB_POOL < 1 then 
        logger.warn("redis maybe busy!!!")
        local ok, db = pcall(redis.connect,redis_cf)
        if not ok then
            logger.error("redis connect error %s", db or "null")
            return
        end
        return db
    end
    return table.remove(DB_POOL, 1)
end

local function release(db)
    if #DB_POOL > 20 then
        pcall(db.disconnect, db)
        return
    end 
    table.insert(DB_POOL, db)
end


local function query(cmd, ...)
    local db = acquire()
    if not db then
        return nil 
    end
    local f = db[cmd]
    if not f then
        logger.error("redis not this cmd %s", cmd)
        release(db)
        return nil
    end

    local ok, r = pcall(f, db, ...)
    if not ok then
        pcall(db.disconnect, db)
        logger.error("redis query cmd %s %s error %s", cmd, tostring({...}), r or "null")
        return nil
    end
    release(db)                         -- 释放redis db connect
    return r
end

local CMD = {}

function CMD.query(cmd, ... )
    query_num = query_num + 1
    return query(cmd, ...)
end

function CMD.info()
    -- body
end


function CMD.exit( )
    for i, db in ipairs(DB_POOL) do
        pcall(db.disconnect, db)
    end
    skynet.exit()
end

local function init_redis(cf, num)
    num = num or 10
    cf = cjson_decode(cf)
    redis_cf = cf
    skynet.fork(function ( ... )
        for i = 1, num do
            table.insert(DB_POOL, redis.connect(redis_cf))
        end

        local handle = skynet.self()
        local port = redis_cf.port
        while true do
            if query_num > WARN_QUERY_NUM then
                logger.warn("redis %d port %d query number %d", handle, port, query_num)
            elseif query_num > 0 then
                logger.info("redis %d port %d query %d", handle, port, query_num)
            end
            query_num = 0
            skynet.sleep(5 * 60 * 100)
        end
    end)    
end

skynet.start(function ()
    init_redis(redis_cf, connect_num)

    skynet.dispatch("lua", function(session, _, command, ...)
        local f = CMD[command]
        if not f then
            if session ~= 0 then
                skynet.ret(skynet.pack(nil))
            end
            return
        end
        if session == 0 then
            return f(...)
        end
        skynet.ret(skynet.pack(f(...)))
    end)
end)
