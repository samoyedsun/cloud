local skynet = require "skynet"
local skynet_core = require "skynet.core"

local moudle_name = ...
local channel = require(moudle_name)

local IS_DEBUG = IS_DEBUG
local logger = log4.get_logger(SERVICE_NAME)

local SOCKET_TO_CLIENT = {}             -- MAP, key = socket fd , value = channel object

local CMD = {}


--新建立一个连接
function CMD.start(gate, fd, addr)
    logger.debug("socket start fd %s %s", fd, addr)
    local client = SOCKET_TO_CLIENT[fd]
    if client then
        assert(false, "CMD.start")
    end

    client = channel:new()
    local ip = addr:match("([^:]+):?(%d*)$")
    local session = {fd = fd, agent = skynet.self(), gate = gate, addr = addr, ip=ip}
    SOCKET_TO_CLIENT[fd] = client
    client:emit("start", session)   -- co maybe yeild
end

function CMD.close(fd, reason)
    logger.debug("socket close fd %s", fd)
    local client = SOCKET_TO_CLIENT[fd]
    SOCKET_TO_CLIENT[fd] = nil
    if not client then
        return
    end
    client:emit("close", reason)        -- 清理工作
end

function CMD.emit(fd, ...)
    local client = SOCKET_TO_CLIENT[fd]
    if not client then
        return
    end
    client:emit(...)
end


-- 离线请求
function CMD.s2c_request_offline(session, name, msg)
    session = session or {}
    session.agent = skynet.self()
    session.gate = GATE
    channel.emit(session, "s2c_request_offline", name, msg)
end

-- 系统广播
function CMD.s2c_broadcast(name, msg)
    for _, client in pairs(SOCKET_TO_CLIENT) do
        client:emit("s2c", name, msg)
    end
end

function CMD.info()
    for k, v in pairs(SOCKET_TO_CLIENT) do 
        logger.info("fd %s to client session %s", k, tostring(v.session))
    end
end

function CMD.update()

end

function CMD.exit()
    for k, v in pairs(SOCKET_TO_CLIENT) do 
        v:emit("kick")
    end
end

skynet.register_protocol {
    name = "client",
    id = skynet.PTYPE_CLIENT,
    unpack = function (msg, sz)  
        msg = skynet_core.tostring(msg, sz)
        return msg, #msg
    end,
    dispatch = function (fd, _, msg, sz)
        local client = SOCKET_TO_CLIENT[fd]
        if not client then
            logger.info(" protocol type=client fd %s to client is nil", fd)
            return
        end
        client:emit("c2s", msg, sz)  -- proto data do unpack in emit c2s
    end
}

skynet.start(function()
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