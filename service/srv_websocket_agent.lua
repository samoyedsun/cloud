local skynet = require "skynet"
local websocket = require "http.websocket"
local logger = log4.get_logger(SERVICE_NAME)
local SOCKET_NUMBER = 0

local CMD = {}

function add_web_agent_cmd(cmd, process)      -- 这样合适吗？
    CMD[cmd] = process
end

local wsapp_name = ...
local handle = require(wsapp_name)

function CMD.update()
    skynet.fork(function ()
        while true do
            skynet.sleep(60 * 100)           -- 60s
            if SOCKET_NUMBER == 0 then
                break
            end
        end
        logger.info("after update service exit %08x", skynet.self())
        skynet.exit()                        -- 没有连接存在了
    end)
end

function CMD.info()
    logger.info("socket connect number %s", SOCKET_NUMBER)
end

function CMD.socket(fd, protocol, addr)
    SOCKET_NUMBER = SOCKET_NUMBER + 1
    skynet.error("change socket number:", SOCKET_NUMBER, ", fd:", fd)
    local ok, err = websocket.accept(fd, handle, protocol, addr)
    if not ok then
        skynet.error("on websocket accept, error:", err, ", fd:", fd)
    end
    SOCKET_NUMBER = SOCKET_NUMBER - 1
    skynet.error("change socket number:", SOCKET_NUMBER, ", fd:", fd)
end

skynet.start(function ()
    skynet.dispatch("lua", function (session, _, command, ...)
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
