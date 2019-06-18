local skynet = require "skynet"
require "skynet.manager"
local hotfix = require "hotfix"

skynet.start(function ( )
    skynet.uniqueservice("srv_logger_sup")
    skynet.newservice("debug_console", 8901)
    if not skynet.getenv "daemon" then
        local console = skynet.uniqueservice("console")
    end

    local handle = skynet.newservice("srv_register")
    skynet.name(".register", handle)
    -- 初始化目录：
    skynet.call(handle, "lua", "mkdir", "/mj/")           
    skynet.call(handle, "lua", "mkdir", "/mj/games")
    skynet.call(handle, "lua", "mkdir", "/mj/logins")
    skynet.call(handle, "lua", "mkdir", "/mj/gates")
    skynet.call(handle, "lua", "mkdir", "/mj/nodes")
    skynet.call(handle, "lua", "mkdir", "/mj/agents")

    local env = skynet.getenv("env")
    local config = require('config.' .. env .. ".node")
    local backend_port = config.etcdcf.backend.port
    local frontend_port = config.etcdcf.frontend.port

    hotfix.start_hotfix_service("skynet", "srv_web", backend_port, "node.backend.webapp", 65536)
    hotfix.start_hotfix_service("skynet", "srv_web", frontend_port, "node.frontend.webapp", 65536)
    
    local handle = hotfix.start_hotfix_service("skynetunique", "srv_register_agent")
    skynet.call(handle, "lua", "set", config.etcdfile, config.etcdcf)
    skynet.exit()
end)