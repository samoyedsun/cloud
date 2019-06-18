local skynet = require "skynet"
require "skynet.manager"

local logger = log4.get_logger(SERVICE_NAME)

local REDIS_CONFIG = {}
local REDIS_DB_POOL = {}
local CMD = {}

local function init_redis_pool(name, cf)
    REDIS_CONFIG[name] = cf
    local db_pool = {}
    for i = 1, #cf do
        local dbs = {}
        for j = 1, 3 do
            local db = skynet.newservice("srv_redis", cjson_encode(cf[i]), 10)
            dbs[j] = db
        end
        db_pool[i] = dbs
    end    
    REDIS_DB_POOL[name] = db_pool
end

local function destory_redis_pool(name)
    local db_pool = REDIS_DB_POOL[name]
    if not db_pool then
        return
    end
    for i = 1, #db_pool do
        local dbs = db_pool[i]
        for j = 1, #dbs do
            local db = dbs[j]
            snax.kill(db)
        end
    end
end 


function CMD.exit()
    for k, v in pairs(REDIS_DB_POOL) do 
        destory_redis_pool(k)
    end
    REDIS_DB_POOL = {}
end

function CMD.init(name, cf)
    logger.info("init %s", name)
    if REDIS_CONFIG[name] then
        logger.warn("name %s already init", name)
        return
    end
    init_redis_pool(name, cf)
end

function CMD.acquire(name)
    local cf = REDIS_CONFIG[name]
    if not REDIS_CONFIG[name] then
        logger.warn("sup acquire not %s config", name)
        return 
    end
    local db_pool

    while true do
        db_pool = REDIS_DB_POOL[name]
        if not db_pool or #db_pool < #cf then 
            skynet.sleep(100)
        else
            break
        end
    end
    if #db_pool == 0 then
        logger.error("sup response.acquire db_pool is emtpy")
    end
    return db_pool
end


skynet.start(function ( ... )
    skynet.name(".redis", skynet.self())

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
