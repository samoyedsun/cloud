local skynet = require "skynet"
local proto = require "server.frontend.proto"
local app = require "server.frontend.app"
local websocket = require "websocket"
local logger = log4.get_logger("websocket")

local CMD = {}
local SOCKET_TO_CLIENT = {}

function CMD.close(fd, reason)
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
    app.emit(session, "s2c_request_offline", name, msg)
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


function CMD.exit()
    for k, v in pairs(SOCKET_TO_CLIENT) do 
        v:emit("kick")
    end
end

-- 注册 srv_web_agent CMD.xxx
for cmd, p in pairs(CMD) do 
    add_web_agent_cmd(cmd, p)
end


--- overide 重载 send_package
function proto.send_package(fd, package)
    local client = SOCKET_TO_CLIENT[fd] 
    if not client or not client.session or not client.session.ws then
        return false, "close"
    end

    local ws = client.session.ws
    local ok, reason = ws:send_binary(package)
    if not ok then
        CMD.close(fd, reason)
    end
    return ok, reason
end


-- websocket回调方法
local handler = {}

function handler.on_open(ws)
    skynet.error(string.format("Client connected: %s", ws.addr))
    local fd = ws.fd
    local client = app:new()
    SOCKET_TO_CLIENT[fd] = client
    local ip = ws.addr:match("([^:]+):?(%d*)$")
    local session = {ws = ws, fd = fd, agent = skynet.self(), addr = ws.addr, ip = ip}
    client:emit("start", session)
end

function handler.on_message(ws, msg)
    local fd = ws.fd
    local client =  SOCKET_TO_CLIENT[fd]
    if not client then
        return
    end
    client:emit("c2s", msg, #msg)
end

function handler.on_error(ws, msg)
    local fd = ws.fd
    local client =  SOCKET_TO_CLIENT[fd]
    if not client then
        return
    end
    CMD.close(fd, msg)
 end

function handler.on_close(ws, fd, code, reason)
    fd = fd or ws.fd
    local client =  SOCKET_TO_CLIENT[fd]
    if not client then
        return
    end
    CMD.close(fd, reason)
end 

local root = {}

--- http升级协议成websocket协议
function root.process(req, res)
    local fd = req.fd 
    local ws, err  = websocket.new(req.fd, req.addr, req.headers, handler)
    if not ws then
        res.body = err
        return false
    end
    ws:start()
    return true
end

return root