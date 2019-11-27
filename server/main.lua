local skynet = require "skynet"
local hotfix = require "hotfix"
local rpc_mysql = require "rpc_mysql"
local rpc_redis = require "rpc_redis"
local etcd = require "etcd"

skynet.start(function ( ... )
    print("test start")
    skynet.uniqueservice("srv_logger_sup")
    skynet.newservice("debug_console", 8900)
    if not skynet.getenv "daemon" then
        local console = skynet.uniqueservice("console")
    end

    skynet.newservice("node/main")
    skynet.newservice("gate/main")
    skynet.newservice("gate/service/srv_room")      -- TODO:冒烟测试服务
end)