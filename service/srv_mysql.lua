local skynet = require "skynet"
local mysql = require "skynet.db.mysql"

local MYSQL_CONFIG, CONNECT_NUM = ...
local logger = log4.get_logger(SERVICE_NAME)

local DB_POOL = {}
local MYSQL_CONNECT_NUM = 0
local QUERY_NUMBER = 0
local OPEN_CONNECT = 0
local CLOSE_CONNECT = 0
local IS_DEBUG = IS_DEBUG

local function disconnect(db)
    MYSQL_CONNECT_NUM = MYSQL_CONNECT_NUM - 1
    
    local ok, rs = pcall(db.disconnect, db)
    if not ok then
        logger.error("disconnect error %s", rs)
    else
        CLOSE_CONNECT = CLOSE_CONNECT + 1
        logger.debug("disconnect success")
    end
end

local function acquire()
    if #DB_POOL < 1 then
        logger.warn("mysql maybe busy MYSQL_CONNECT_NUM %d !!!", MYSQL_CONNECT_NUM)
        local ok, db = pcall(mysql.connect, MYSQL_CONFIG)
        OPEN_CONNECT = OPEN_CONNECT + 1
        if not ok then
            logger.error("mysql connect error %s", db or "null")
            return
        end
        db:query("set names utf8")
        MYSQL_CONNECT_NUM = MYSQL_CONNECT_NUM + 1
        return db
    end
    return table.remove(DB_POOL, 1)
end

local function release(db)
    if #DB_POOL > 10 then
        disconnect(db)
        return
    end
    table.insert(DB_POOL, db)
end


local function try_query(...)
    local db = acquire()
    if not db then
        return false
    end
    local sql = ...
    local timeout = 200
    local timer = create_timeout(timeout, function ()
            logger.warn("mysql try query timeout %d sql %s", timeout, sql or "")
        end)
    local ok, rs = pcall(db.query, db, ...)
    timer.delete()
    if not ok then
        disconnect(db)
        logger.error("try query sql %s error %s", sql, rs or "null")
        return false
    end
    release(db)
    return rs
end

local function query(...)
    if IS_DEBUG then
        logger.debug(...)
    end
    local db = acquire()
    local sql = ...
    if not db then
        return false
    end
    local timeout = 200
    local timer = create_timeout(timeout, function ()
            logger.warn("mysql query timeout %d sql %s", timeout, sql or "")
        end)
    
    local ok , rs = pcall(db.query, db, ...)
    timer.delete()
    
    if not ok then
        disconnect(db)
        logger.error("query sql %s error %s", sql, rs or "null")
        return try_query(...)
    end
    release(db)
    return rs    
end


local CMD = {}

function CMD.query( ... )
    QUERY_NUMBER = QUERY_NUMBER + 1
    return query(...)
end

function CMD.exit()
    for _, db in ipairs(DB_POOL) do
        disconnect(db)
    end
end

function CMD.info()
    
end

local function init_mysql(cf, num)
    cf = cjson_decode(cf)
    MYSQL_CONFIG = cf
    MYSQL_CONNECT_NUM = tonumber(num) or 5
    skynet.fork(function ( ... )
        for i = 1, MYSQL_CONNECT_NUM do
            local db = mysql.connect(MYSQL_CONFIG)
            db:query("set names utf8")
            table.insert(DB_POOL, db)
        end
    end)
    skynet.fork(function ( ... )
        while true do 
            skynet.sleep(5 * 60 * 100)
            logger.debug("mysql 5 min query %d create %d close %d", QUERY_NUMBER, OPEN_CONNECT, CLOSE_CONNECT)
            QUERY_NUMBER = 0
        end
    end)
end

skynet.start(function ()
    init_mysql(MYSQL_CONFIG, CONNECT_NUM)

    skynet.dispatch("lua", function(session, _, command, ...)
        local f = CMD[command]
        if session == 0 then
            return f(...)
        end
        skynet.ret(skynet.pack(f(...)))
    end)  
end)
