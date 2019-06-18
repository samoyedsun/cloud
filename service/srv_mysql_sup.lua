local skynet = require "skynet"
require "skynet.manager"

local MYSQL_DB_POOL = {}
local MYSQL_CONFIG = {}
local logger = log4.get_logger(SERVICE_NAME)

local CMD = {}

local function init_mysql_pool(name, cf)
    local db_pool = {}
    MYSQL_CONFIG[name] = cf
    for i = 1, 2 do 
        local db = skynet.newservice("srv_mysql", cjson_encode(cf), 8)
        db_pool[i] = db
    end
    MYSQL_DB_POOL[name] = db_pool
end

local function destory_mysql_pool(name)
    local db_pool = MYSQL_DB_POOL[name]
    MYSQL_DB_POOL[name] = {}
    for i = 1, #db_pool do
        local db = db_pool[i]
        skynet.kill(db)
    end
end


function CMD.exit()
    for k, v in pairs(MYSQL_DB_POOL) do 
        destory_mysql_pool(k)
    end
    MYSQL_DB_POOL = {}
end

function CMD.acquire(name)
    local cf = MYSQL_CONFIG[name]
    if not cf then
        logger.warn("not %s config mysql ", name)
        return 
    end

    local db_pool = MYSQL_DB_POOL[name]
    while true do
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

function CMD.init(name, cf)
    logger.info("init %s", name)
    if MYSQL_DB_POOL[name] then
        logger.warn("%s cf mysql already init", name)
        return
    end
    init_mysql_pool(name, cf)
end

function CMD.info()
    logger.info("") 
    for _, pool in pairs(MYSQL_DB_POOL) do 
        for _, db in ipairs(pool) do 
            skynet.send(db, "lua", "info")
        end
    end
end

skynet.start(function ( ... )
    skynet.name(".mysql", skynet.self())

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
