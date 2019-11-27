local skynet = require "skynet"
require "skynet.manager"
local etcd = require "etcd"
local hotfix = require "hotfix"
local rpc_mysql = require "rpc_mysql"
local rpc_redis = require "rpc_redis"

skynet.start(function ()
    skynet.uniqueservice("srv_logger_sup")
    skynet.newservice("debug_console", 8903)
    if not skynet.getenv "daemon" then
        local console = skynet.uniqueservice("console")
    end
    local handle = skynet.uniqueservice("server/service/srv_logon")
    skynet.name(".logon", handle)
    local handle = skynet.uniqueservice("server/service/srv_voice")
    skynet.name(".voice", handle)

    local env = skynet.getenv("env")
    local config = require('etc.' .. env .. ".server")
    local backend_port = config.etcdcf.backend.port
    local frontend_port = config.etcdcf.frontend.port
    skynet.setenv("gate_etcd", config.etcdfile)

    local handle = hotfix.start_hotfix_service("skynet", "server/service/srv_room_sup_proxy")
    skynet.name(".room", handle)    

    hotfix.start_hotfix_service("skynet", "srv_web", backend_port, "server.backend.webapp", 65536)
    hotfix.start_hotfix_service("skynet", "srv_web", frontend_port, "server.frontend.webapp", 65536 * 2)

    local maxclient = 30000
    local socket = config.etcdcf.frontend.socket
    local handle = hotfix.start_hotfix_service("skynet","srv_socket")
    skynet.call(handle, "lua", "start", 
        {
            port = socket,
            maxclient = maxclient,
            nodelay = true,
        },
        "server.frontend.app"
    )

    skynet.exit()
end)