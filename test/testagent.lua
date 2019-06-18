local skynet = require "skynet"
require "skynet.manager"
local rpc_hotfix = require "rpc_hotfix"

local cmd = ...

local CMD  = {}

skynet.start(function ()
    local port = 12125
    local agent_sup = ".agent" 
    local auth_secret = "abcdecfg"
    local max_client = 30000
    local watchdog = skynet.newservice("watchdog")
    rpc_hotfix.start_hotfix_service("skynet","srv_agent_sup", "srv_agent_sup")
    
    skynet.call(watchdog, "lua", "start", {
            port = port,
            maxclient = max_client,
            nodelay = true,
        },
        auth_secret,
        agent_sup,
    )
    local watchdog = skynet.newservice("watchdog")

    skynet.name(".agent", handle)

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