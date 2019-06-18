local skynet = require "skynet"
local rpc_mysql = require "rpc_mysql"
local cmd = ...

local mysql_conf =  {
    ["game"] = {  
        host="127.0.0.1",
        port=3306,
        database="test",
        user="test",
        password="123456",
        max_packet_size = 1024 * 1024
    },
    ["log"] = {           -- 日志数据库
        host="192.168.1.123",
        port=3306,
        database="test",
        user="test_log",
        password="123456",
        max_packet_size = 1024 * 1024        
    }
}

local CMD = {}

function CMD.sleep()
    local mysql = rpc_mysql.get_mysql("game")
    print(mysql:query("select sleep(30);"))
end

function CMD.game( ... )
    local mysql = rpc_mysql.get_mysql("game")
    print(mysql:query("select count(*) as num from game_user;"))
end

skynet.start(function ( ... )
    skynet.call(".mysql", "lua", "init", "game", mysql_conf["game"])
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
    local f = CMD[cmd]
    if f then
        f(...)
    end
end)
