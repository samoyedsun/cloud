local skynet = require "skynet"
require "skynet.manager"
require "skynet.queue"
local code = require "server.config.code"
local logger = log4.get_logger(SERVICE_NAME)
local mode = ...


local CS = skynet.queue()
local ROOM_SUP_HANDLE = 0       -- srv_room_sup handle

local CMD = {}

-- 更新srv_room_sup
function CMD.update() 
    local handle = skynet.call(ROOM_SUP_HANDLE, 'lua', 'update')
    local tmp = ROOM_SUP_HANDLE
    ROOM_SUP_HANDLE = handle
    skynet.kill(tmp)
end

-- 代理发送到 srv_room_sup
function CMD.proxy(command, ...)
    return skynet.call(ROOM_SUP_HANDLE, 'lua', command, ...)
end

if mode == "save" then
    skynet.start(function ()
        skynet.call(".seat", "lua", "save_all")
        skynet.exit()
    end)
else
    skynet.start(function()
        ROOM_SUP_HANDLE = skynet.newservice('server/service/srv_room_sup')
        skynet.dispatch("lua", function(session, _, command, ...)
            local f = CMD[command]
            if not f then
                f = CMD.proxy
                if session ~= 0 then
                    skynet.ret(skynet.pack(CS(f, command, ...)))
                end
                return CS(f, command, ...)
            end
            if session == 0 then
                return CS(f, ...)
            end
            skynet.ret(skynet.pack(CS(f, ...)))
        end)
    end)
end