local skynet = require "skynet"
require "skynet.manager"
local etcd = require "etcd"

local cmd = ...

if cmd == "exit" then
    skynet.start(function()
        local handle = skynet.uniqueservice("srv_register_agent")
        skynet.call(handle, "lua", "exit")
        skynet.exit()
    end)
    return
end

local CMD = {}

local FILE_TO_CONFIG = {}

function CMD.exit()
    for file in pairs(FILE_TO_CONFIG) do 
        FILE_TO_CONFIG[file] = nil
        etcd.rm(file)           -- 服务下线
    end
end

function CMD.set(file, cf)
    FILE_TO_CONFIG[file] = cf
    etcd.set(file, cjson_encode(cf))           -- 注册服务配置
    local timeout = 1000
    skynet.fork(function ()
        while true do
            if not FILE_TO_CONFIG[file] then
                return
            end
            etcd.ttl(file, timeout)               -- 设置定时器，key的定时删除
            skynet.sleep(timeout / 2)
        end
    end)
    skynet.fork(function ( ... )
        local content = cjson_encode(cf)
        while true do 
            if not FILE_TO_CONFIG[file] then
                return
            end
            skynet.sleep(timeout)
            etcd.set(file, content)           -- 注册服务配置
        end
    end)
end

skynet.start(function ()
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